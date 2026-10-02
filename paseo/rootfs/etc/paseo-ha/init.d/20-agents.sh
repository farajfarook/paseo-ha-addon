#!/usr/bin/env bash
# shellcheck shell=bash
# ==============================================================================
# 20-agents: install the optional agent CLIs selected in the `agents` option
# persistently under /data/agents (design D7). Pi is baked into the image.
#
# - Reinstall only when the selected set or the pinned version map changes
#   (stamp file /data/agents/.paseo-ha-agents.stamp).
# - Agents that are no longer selected are uninstalled.
# - Failures are logged per agent and never abort startup.
# ==============================================================================

AGENTS_DIR="${PASEO_HA_DATA}/agents"
STAMP="${AGENTS_DIR}/.paseo-ha-agents.stamp"

# Pinned package map: option value -> npm spec. Bump with add-on releases.
declare -A AGENT_PKG=(
  [claude-code]="@anthropic-ai/claude-code@2.1.287"
  [codex]="@openai/codex@0.160.0"
  [opencode]="opencode-ai@1.18.34"
)
declare -A AGENT_BIN=(
  [claude-code]="claude"
  [codex]="codex"
  [opencode]="opencode"
)

mkdir -p "${AGENTS_DIR}"
[[ -f "${AGENTS_DIR}/package.json" ]] || echo '{"name":"paseo-ha-agents","private":true}' > "${AGENTS_DIR}/package.json"

mapfile -t selected < <(ph_opt_list agents | sort -u)

# Desired state: "name=spec" lines, sorted.
desired=""
for name in "${selected[@]}"; do
  [[ -z "${name}" ]] && continue
  if [[ -z "${AGENT_PKG[${name}]:-}" ]]; then
    ph_log_warn "Unknown agent '${name}' in agents option; ignoring"
    continue
  fi
  desired+="${name}=${AGENT_PKG[${name}]}"$'\n'
done

current=""
[[ -f "${STAMP}" ]] && current="$(cat "${STAMP}")"

npm_pkg_name() { # strip the trailing @version from an npm spec
  local spec="$1"
  printf '%s' "${spec%@*}"
}

# Uninstall agents that are installed (per stamp) but no longer desired, or whose pin changed.
while IFS='=' read -r name spec; do
  [[ -z "${name}" ]] && continue
  if ! grep -qxF "${name}=${spec}" <<<"${desired}"; then
    if ! grep -q "^${name}=" <<<"${desired}"; then
      ph_log_info "Removing agent ${name}"
    fi
    npm uninstall --prefix "${AGENTS_DIR}" --no-audit --no-fund "$(npm_pkg_name "${spec}")" >/dev/null 2>&1 \
      || ph_log_warn "Failed to uninstall agent ${name}"
  fi
done <<<"${current}"

if [[ "${desired}" == "${current}" ]]; then
  [[ -n "${desired}" ]] && ph_log_info "Agents up to date: $(cut -d= -f1 <<<"${desired}" | paste -sd' ' -)"
  exit 0
fi

# Install each desired agent that is not already recorded with the same pin.
new_stamp=""
while IFS='=' read -r name spec; do
  [[ -z "${name}" ]] && continue
  bin="${AGENT_BIN[${name}]}"
  if grep -qxF "${name}=${spec}" <<<"${current}" && [[ -x "${AGENTS_DIR}/node_modules/.bin/${bin}" ]]; then
    new_stamp+="${name}=${spec}"$'\n'
    continue
  fi
  ph_log_info "Installing agent ${name} (${spec}) into ${AGENTS_DIR}..."
  log="$(mktemp)"
  if npm install --prefix "${AGENTS_DIR}" --no-audit --no-fund --omit=dev --fetch-retries=1 --fetch-timeout=60000 "${spec}" >"${log}" 2>&1 \
     && "${AGENTS_DIR}/node_modules/.bin/${bin}" --version >/dev/null 2>&1; then
    ph_log_info "Installed agent ${name}: $("${AGENTS_DIR}/node_modules/.bin/${bin}" --version 2>/dev/null | head -n1)"
    new_stamp+="${name}=${spec}"$'\n'
  else
    ph_log_error "Agent ${name} could not be installed or does not run on $(uname -m) (it will not be offered). Last output:"
    tail -n 5 "${log}" | while IFS= read -r line; do ph_log_error "  ${line}"; done
    npm uninstall --prefix "${AGENTS_DIR}" --no-audit --no-fund "$(npm_pkg_name "${spec}")" >/dev/null 2>&1 || true
  fi
  rm -f "${log}"
done <<<"${desired}"

# Failed agents are left out of the stamp so the next start retries them.
printf '%s' "${new_stamp}" > "${STAMP}"
exit 0
