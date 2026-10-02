#!/usr/bin/env bash
# shellcheck shell=bash
# ==============================================================================
# 30-agent-config (design D12): seed the editable agent-config folder (/config =
# this add-on's addon_config folder) without overwriting anything, then point each
# tool's per-user folders at it with directory symlinks.
# Sourced by init-paseo with common.sh loaded and the daemon env exported.
# ==============================================================================

PASEO_HA_CONFIG_DIR="${PASEO_HA_CONFIG_DIR:-/config}"
seed_dir="${PASEO_HA_OPT_DIR}/config-seed"

# Folders seeded in /config. Each line: "<folder under /config>".
config_subdirs=(
  skills
  claude/agents
  claude/commands
  opencode/agents
  opencode/plugins
  pi/extensions
  pi/prompts
  codex/prompts
)

ph_seed_agent_config() {
  if ! mkdir -p "${PASEO_HA_CONFIG_DIR}" 2>/dev/null || [[ ! -w "${PASEO_HA_CONFIG_DIR}" ]]; then
    ph_log_warn "Agent config folder ${PASEO_HA_CONFIG_DIR} is not writable; skipping seeding"
    return 1
  fi
  local sub file
  for sub in "${config_subdirs[@]}"; do
    mkdir -p "${PASEO_HA_CONFIG_DIR}/${sub}"
  done
  for file in AGENTS.md README.md; do
    if [[ ! -e "${PASEO_HA_CONFIG_DIR}/${file}" && -f "${seed_dir}/${file}" ]]; then
      cp "${seed_dir}/${file}" "${PASEO_HA_CONFIG_DIR}/${file}"
      ph_log_info "Seeded ${PASEO_HA_CONFIG_DIR}/${file}"
    fi
  done
}

# ph_link_dir LINK TARGET -> make LINK a symlink to the directory TARGET.
# An existing real directory at LINK is moved aside (never deleted) so nothing is lost.
ph_link_dir() {
  local link="$1" target="$2"
  mkdir -p "$(dirname "${link}")"
  if [[ -L "${link}" ]]; then
    [[ "$(readlink "${link}")" == "${target}" ]] && return 0
    rm -f "${link}"
  elif [[ -d "${link}" ]]; then
    if rmdir "${link}" 2>/dev/null; then
      :
    else
      local backup
      backup="${link}.paseo-ha-backup-$(date +%Y%m%d%H%M%S)"
      mv "${link}" "${backup}"
      ph_log_warn "Moved existing ${link} to ${backup}; move its files into ${target} to keep using them"
    fi
  elif [[ -e "${link}" ]]; then
    mv "${link}" "${link}.paseo-ha-backup-$(date +%Y%m%d%H%M%S)"
  fi
  ln -s "${target}" "${link}"
}

ph_link_agent_config_dirs() {
  # Claude Code reads user agents/commands/skills/CLAUDE.md from $CLAUDE_CONFIG_DIR
  # (init-paseo sets it to $HOME/.claude, so both lookups agree).
  local claude_dir="${CLAUDE_CONFIG_DIR:-${HOME}/.claude}"
  local opencode_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/opencode"
  local pi_dir="${PI_CODING_AGENT_DIR:-${HOME}/.pi/agent}"
  local codex_dir="${CODEX_HOME:-${HOME}/.codex}"
  local pair link target
  # "<tool folder>|<folder under /config>"
  local pairs=(
    "${claude_dir}/agents|claude/agents"
    "${claude_dir}/commands|claude/commands"
    "${opencode_dir}/agents|opencode/agents"
    "${opencode_dir}/plugins|opencode/plugins"
    "${pi_dir}/extensions|pi/extensions"
    "${pi_dir}/prompts|pi/prompts"
    "${codex_dir}/prompts|codex/prompts"
  )
  for pair in "${pairs[@]}"; do
    link="${pair%%|*}"
    target="${PASEO_HA_CONFIG_DIR}/${pair#*|}"
    ph_link_dir "${link}" "${target}" || ph_log_warn "Could not link ${link} -> ${target}"
  done
}

if ph_seed_agent_config; then
  ph_link_agent_config_dirs
fi
