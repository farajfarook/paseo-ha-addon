#!/usr/bin/env bash
# shellcheck shell=bash
# ==============================================================================
# 48-git-snapshot (design D15): optional git repository for /homeassistant so
# agent changes can be reviewed and reverted.
# - Always: when /homeassistant/.git exists, mark it as a git safe.directory
#   (global git config lives under HOME=/data/home).
# - git_snapshot=true and no .git yet: git init -b main, .gitignore (only if
#   absent), local "Paseo Agent" identity, initial commit.
# - An existing repository is never reinitialised or modified otherwise.
# - Turning the option off never deletes .git.
# ==============================================================================

ha_config_dir="${PASEO_HA_HA_CONFIG_DIR:-/homeassistant}"

ph_git_safe_directory() {
  if ! git config --global --get-all safe.directory 2>/dev/null | grep -Fxq "${ha_config_dir}"; then
    git config --global --add safe.directory "${ha_config_dir}"
  fi
}

ph_git_write_ignore() {
  cat > "${ha_config_dir}/.gitignore" <<'EOF'
# Written by the Paseo add-on (git_snapshot). Secrets and runtime state stay out of git.
secrets.yaml
.storage/
*.db
*.db-*
*.db.*
*.log
*.log.*
home-assistant.log*
.cloud/
deps/
tts/
__pycache__/
.HA_VERSION
.ha_run.lock
EOF
}

ph_git_snapshot() {
  local enabled
  enabled="$(ph_opt_bool git_snapshot)"

  if [[ ! -d "${ha_config_dir}" ]]; then
    [[ "${enabled}" == "true" ]] && ph_log_warn "git_snapshot: ${ha_config_dir} does not exist; skipping"
    return 0
  fi

  if [[ -e "${ha_config_dir}/.git" ]]; then
    ph_git_safe_directory
    [[ "${enabled}" == "true" ]] && ph_log_info "git_snapshot: ${ha_config_dir} is already a git repository; leaving it unchanged"
    return 0
  fi

  [[ "${enabled}" == "true" ]] || return 0

  ph_log_info "git_snapshot: initialising a git repository in ${ha_config_dir}"
  git -C "${ha_config_dir}" init -q -b main || return 1
  ph_git_safe_directory
  [[ -e "${ha_config_dir}/.gitignore" ]] || ph_git_write_ignore
  git -C "${ha_config_dir}" config user.name "Paseo Agent"
  git -C "${ha_config_dir}" config user.email "paseo-agent@homeassistant.local"
  git -C "${ha_config_dir}" add -A || return 1
  git -C "${ha_config_dir}" commit -q --allow-empty -m "Initial snapshot of Home Assistant configuration (Paseo add-on)" || return 1
  ph_log_info "git_snapshot: initial commit created"
}

ph_git_snapshot
