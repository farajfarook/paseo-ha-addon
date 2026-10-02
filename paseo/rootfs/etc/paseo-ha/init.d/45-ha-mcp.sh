#!/usr/bin/env bash
# shellcheck shell=bash disable=SC2016  # jq programs are intentionally single-quoted
# ==============================================================================
# 45-ha-mcp (design D13a): wire Home Assistant's MCP Server integration into the
# MCP-capable agents (Claude Code, Codex, OpenCode, and Pi, which has built-in
# MCP since 1.0).
#
# Probe (short timeouts, non-fatal), first answer wins:
#   1. http://supervisor/core/api/mcp   (Supervisor Core proxy)
#   2. http://homeassistant:8123/api/mcp (internal network)
# with "Authorization: Bearer $HA_MCP_TOKEN" when the user set HA_MCP_TOKEN via
# env_vars, else $SUPERVISOR_TOKEN.
#
# Configs are merged, never replaced. Entries reference the token by environment
# variable name, so no token is written to disk. A "homeassistant" entry whose URL
# is not one of ours is treated as user-owned and left alone.
# ==============================================================================

ha_mcp_name="homeassistant"
ha_mcp_urls=("http://supervisor/core/api/mcp" "http://homeassistant:8123/api/mcp")
ha_mcp_enable_hint="Home Assistant MCP tools are not wired into agents: enable the 'Model Context Protocol Server' integration (Settings > Devices & services > Add integration) and restart the add-on."

if [[ -n "${HA_MCP_TOKEN:-}" ]]; then
  ha_mcp_token_var="HA_MCP_TOKEN"
else
  ha_mcp_token_var="SUPERVISOR_TOKEN"
fi
ha_mcp_token="${!ha_mcp_token_var:-}"

claude_json="${CLAUDE_CONFIG_DIR:-${HOME}}/.claude.json"
codex_toml="${CODEX_HOME:-${HOME}/.codex}/config.toml"
opencode_json="${XDG_CONFIG_HOME:-${HOME}/.config}/opencode/opencode.json"
pi_mcp_json="${PI_CODING_AGENT_DIR:-${HOME}/.pi/agent}/mcp.json"

# ph_mcp_probe URL -> prints the HTTP status of an MCP initialize request (000 = unreachable).
ph_mcp_probe() {
  curl -s -o /dev/null -w '%{http_code}' \
    --connect-timeout 3 --max-time 8 \
    -X POST "$1" \
    -H "Authorization: Bearer ${ha_mcp_token}" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    --data '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"paseo-ha-probe","version":"1"}}}' \
    2>/dev/null || true
}

# ph_mcp_is_ours URL -> true when URL is one of the endpoints this hook writes.
ph_mcp_is_ours() {
  local u
  for u in "${ha_mcp_urls[@]}"; do [[ "$1" == "${u}" ]] && return 0; done
  return 1
}

ph_have() { command -v "$1" >/dev/null 2>&1; }

# ph_json_edit FILE JQ_FILTER [jq args...] -> apply a jq filter in place (atomic).
ph_json_edit() {
  local file="$1" filter="$2" tmp
  shift 2
  tmp="${file}.paseo-ha.tmp"
  if jq "$@" "${filter}" "${file}" > "${tmp}"; then
    mv -f "${tmp}" "${file}"
  else
    rm -f "${tmp}"
    return 1
  fi
}

# --- Claude Code: $CLAUDE_CONFIG_DIR/.claude.json mcpServers (user scope) -------
ph_mcp_claude() {
  local url="$1" current
  if [[ -f "${claude_json}" ]] && ! jq -e 'type == "object"' "${claude_json}" >/dev/null 2>&1; then
    ph_log_warn "Claude config ${claude_json} is not valid JSON; not changing its MCP servers"
    return 0
  fi
  current="$(jq -r --arg n "${ha_mcp_name}" '.mcpServers[$n].url // empty' "${claude_json}" 2>/dev/null)"
  if [[ -n "${current}" ]] && ! ph_mcp_is_ours "${current}"; then
    ph_log_info "Claude already has a user-defined '${ha_mcp_name}' MCP server; leaving it unchanged"
    return 0
  fi
  if [[ -z "${url}" ]]; then
    [[ -n "${current}" ]] && ph_json_edit "${claude_json}" 'del(.mcpServers[$n])' --arg n "${ha_mcp_name}"
    return 0
  fi
  ph_have claude || return 0
  mkdir -p "$(dirname "${claude_json}")"
  [[ -f "${claude_json}" ]] || echo '{}' > "${claude_json}"
  ph_json_edit "${claude_json}" \
    '.mcpServers = ((.mcpServers // {}) + {($n): {type: "http", url: $u, headers: {Authorization: ("Bearer ${" + $v + "}")}}})' \
    --arg n "${ha_mcp_name}" --arg u "${url}" --arg v "${ha_mcp_token_var}"
}

# --- Codex: [mcp_servers.homeassistant] in $CODEX_HOME/config.toml -------------
# Prints config.toml without the [mcp_servers.homeassistant] table (and its subtables).
ph_toml_without_table() {
  awk -v t="mcp_servers.${ha_mcp_name}" '
    /^[[:space:]]*\[/ {
      h = $0
      sub(/^[[:space:]]*\[+[[:space:]]*/, "", h)
      sub(/[[:space:]]*\]+.*$/, "", h)
      gsub(/"/, "", h)
      skip = (h == t || index(h, t ".") == 1)
    }
    !skip { print }
  ' "$1"
}

# Prints the url of the [mcp_servers.homeassistant] table, or nothing.
ph_toml_table_url() {
  awk -v t="mcp_servers.${ha_mcp_name}" '
    /^[[:space:]]*\[/ { h = $0; gsub(/[][" \t]/, "", h); inside = (h == t); next }
    inside && /^[[:space:]]*url[[:space:]]*=/ {
      v = $0; sub(/^[^=]*=[[:space:]]*/, "", v); sub(/[[:space:]]*(#.*)?$/, "", v); gsub(/["\047]/, "", v)
      print v; exit
    }
  ' "$1"
}

ph_mcp_codex() {
  local url="$1" present="" tmp
  if [[ -f "${codex_toml}" ]] && ! ph_toml_without_table "${codex_toml}" | cmp -s - "${codex_toml}"; then
    present=1
    if ! ph_mcp_is_ours "$(ph_toml_table_url "${codex_toml}")"; then
      ph_log_info "Codex already has a user-defined '${ha_mcp_name}' MCP server; leaving it unchanged"
      return 0
    fi
  fi
  if [[ -z "${url}" ]]; then
    [[ -n "${present}" ]] || return 0
  else
    ph_have codex || return 0
  fi
  mkdir -p "$(dirname "${codex_toml}")"
  tmp="${codex_toml}.paseo-ha.tmp"
  local rest=""
  if [[ -f "${codex_toml}" ]]; then
    # Other content, with trailing blank lines dropped so reruns do not grow the file.
    rest="$(ph_toml_without_table "${codex_toml}")"
  fi
  {
    [[ -n "${rest}" ]] && printf '%s\n' "${rest}"
    if [[ -n "${url}" ]]; then
      [[ -n "${rest}" ]] && echo
      printf '[mcp_servers.%s]\nurl = "%s"\nbearer_token_env_var = "%s"\n' \
        "${ha_mcp_name}" "${url}" "${ha_mcp_token_var}"
    fi
  } > "${tmp}" && mv -f "${tmp}" "${codex_toml}"
}

# --- OpenCode: mcp.homeassistant in $XDG_CONFIG_HOME/opencode/opencode.json ----
ph_mcp_opencode() {
  local url="$1" current
  if [[ -f "${opencode_json}" ]] && ! jq -e 'type == "object"' "${opencode_json}" >/dev/null 2>&1; then
    ph_log_warn "OpenCode config ${opencode_json} is not plain JSON; not changing its MCP servers"
    return 0
  fi
  current="$(jq -r --arg n "${ha_mcp_name}" '.mcp[$n].url // empty' "${opencode_json}" 2>/dev/null)"
  if [[ -n "${current}" ]] && ! ph_mcp_is_ours "${current}"; then
    ph_log_info "OpenCode already has a user-defined '${ha_mcp_name}' MCP server; leaving it unchanged"
    return 0
  fi
  if [[ -z "${url}" ]]; then
    [[ -n "${current}" ]] && ph_json_edit "${opencode_json}" 'del(.mcp[$n])' --arg n "${ha_mcp_name}"
    return 0
  fi
  ph_have opencode || return 0
  mkdir -p "$(dirname "${opencode_json}")"
  [[ -f "${opencode_json}" ]] || echo '{"$schema": "https://opencode.ai/config.json"}' > "${opencode_json}"
  ph_json_edit "${opencode_json}" \
    '.mcp = ((.mcp // {}) + {($n): {type: "remote", url: $u, enabled: true, headers: {Authorization: ("Bearer {env:" + $v + "}")}}})' \
    --arg n "${ha_mcp_name}" --arg u "${url}" --arg v "${ha_mcp_token_var}"
}

# --- Pi: mcpServers.homeassistant in $PI_CODING_AGENT_DIR/mcp.json --------------
ph_mcp_pi() {
  local url="$1" current
  if [[ -f "${pi_mcp_json}" ]] && ! jq -e 'type == "object"' "${pi_mcp_json}" >/dev/null 2>&1; then
    ph_log_warn "Pi MCP config ${pi_mcp_json} is not valid JSON; not changing it"
    return 0
  fi
  current="$(jq -r --arg n "${ha_mcp_name}" '.mcpServers[$n].url // empty' "${pi_mcp_json}" 2>/dev/null)"
  if [[ -n "${current}" ]] && ! ph_mcp_is_ours "${current}"; then
    ph_log_info "Pi already has a user-defined '${ha_mcp_name}' MCP server; leaving it unchanged"
    return 0
  fi
  if [[ -z "${url}" ]]; then
    [[ -n "${current}" ]] && ph_json_edit "${pi_mcp_json}" 'del(.mcpServers[$n])' --arg n "${ha_mcp_name}"
    return 0
  fi
  ph_have pi || return 0
  mkdir -p "$(dirname "${pi_mcp_json}")"
  [[ -f "${pi_mcp_json}" ]] || echo '{}' > "${pi_mcp_json}"
  ph_json_edit "${pi_mcp_json}" \
    '.mcpServers = ((.mcpServers // {}) + {($n): {url: $u, headers: {Authorization: ("Bearer ${" + $v + "}")}, description: "Home Assistant (Assist API): control and query entities exposed to Assist"}})' \
    --arg n "${ha_mcp_name}" --arg u "${url}" --arg v "${ha_mcp_token_var}"
}

ph_wire_ha_mcp() {
  local url="" status u statuses=()
  if [[ -z "${ha_mcp_token}" ]]; then
    ph_log_info "No SUPERVISOR_TOKEN/HA_MCP_TOKEN; skipping Home Assistant MCP wiring"
  else
    for u in "${ha_mcp_urls[@]}"; do
      status="$(ph_mcp_probe "${u}")"
      statuses+=("${u}=${status:-000}")
      if [[ "${status}" =~ ^2[0-9][0-9]$ ]]; then
        url="${u}"
        break
      fi
    done
    if [[ -n "${url}" ]]; then
      ph_log_info "Home Assistant MCP server found at ${url}; adding it to the Pi/Claude Code/Codex/OpenCode configs (token via \$${ha_mcp_token_var})"
    elif [[ "${statuses[*]}" == *"=401"* || "${statuses[*]}" == *"=403"* ]] && [[ "${statuses[*]}" != *"=404"* ]]; then
      ph_log_info "Home Assistant MCP endpoint rejected the token (${statuses[*]}); add a long-lived access token as env_vars HA_MCP_TOKEN to use HA's MCP Server integration."
    else
      ph_log_info "${ha_mcp_enable_hint}"
      ph_log_debug "MCP probe results: ${statuses[*]}"
    fi
  fi
  # With no endpoint, stale entries we wrote earlier are removed.
  ph_mcp_claude "${url}" || ph_log_warn "Failed to update Claude MCP config"
  ph_mcp_codex "${url}" || ph_log_warn "Failed to update Codex MCP config"
  ph_mcp_opencode "${url}" || ph_log_warn "Failed to update OpenCode MCP config"
  ph_mcp_pi "${url}" || ph_log_warn "Failed to update Pi MCP config"
}

ph_wire_ha_mcp
