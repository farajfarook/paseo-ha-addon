#!/usr/bin/env bash
# shellcheck shell=bash
# ==============================================================================
# 48-git-snapshot (design D15): optional git repository for /homeassistant so
# agent changes can be reviewed and reverted.
# - Always: when /homeassistant/.git exists, mark it as a git safe.directory
#   (global git config lives under HOME=/data/home).
# - git_snapshot=true and no .git yet: git init -b main, .gitignore (only if
#   absent), local "Paseo Agent" identity, initial commit.
# - SSH keys never enter git: the generated .gitignore excludes .ssh/ and private
#   key files. A .gitignore an earlier add-on version wrote (identified by its
#   header line) gets the SSH block appended once; any other .gitignore is left alone.
# - Any repository with tracked SSH keys gets a warning in the log (no changes).
# - An existing repository is never reinitialised or modified otherwise.
# - Turning the option off never deletes .git.
# ==============================================================================

ha_config_dir="${PASEO_HA_HA_CONFIG_DIR:-/homeassistant}"

ph_git_safe_directory() {
  if ! git config --global --get-all safe.directory 2>/dev/null | grep -Fxq "${ha_config_dir}"; then
    git config --global --add safe.directory "${ha_config_dir}"
  fi
}

PH_GIT_IGNORE_HEADER="# Written by the Paseo add-on (git_snapshot). Secrets and runtime state stay out of git."
PH_GIT_SSH_KEY_NAMES=(id_rsa id_ecdsa id_ed25519 id_ecdsa_sk id_ed25519_sk)

# Ignore rules for SSH keys. Public keys (*.pub) stay trackable.
ph_git_ssh_ignore_block() {
  printf '%s\n' ".ssh/" "${PH_GIT_SSH_KEY_NAMES[@]}" "*.pem" "*.key"
}

ph_git_write_ignore() {
  {
    printf '%s\n' "${PH_GIT_IGNORE_HEADER}"
    cat <<'EOF'
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
    printf '# SSH keys\n'
    ph_git_ssh_ignore_block
  } > "${ha_config_dir}/.gitignore"
}

# Append the SSH block once to a .gitignore that an earlier add-on version wrote.
ph_git_update_ignore() {
  local f="${ha_config_dir}/.gitignore"
  [[ -f "${f}" ]] || return 0
  [[ "$(head -n 1 "${f}")" == "${PH_GIT_IGNORE_HEADER}" ]] || return 0
  grep -Fxq ".ssh/" "${f}" && return 0
  [[ -z "$(tail -c 1 "${f}")" ]] || printf '\n' >> "${f}"
  {
    printf '# Added by the Paseo add-on: SSH keys\n'
    ph_git_ssh_ignore_block
  } >> "${f}"
  ph_log_info "git_snapshot: added SSH key rules to ${f}"
}

# Warn (never fix) when SSH keys are already tracked in the repository.
ph_git_warn_tracked_keys() {
  local -a pathspecs=(":(glob).ssh/**" ":(glob)**/*.pem" ":(glob)**/*.key")
  local n tracked count more=""
  for n in "${PH_GIT_SSH_KEY_NAMES[@]}"; do pathspecs+=(":(glob)**/${n}"); done
  tracked="$(git -C "${ha_config_dir}" ls-files -- "${pathspecs[@]}" 2>/dev/null)" || return 0
  [[ -n "${tracked}" ]] || return 0
  count="$(wc -l <<<"${tracked}")"
  (( count > 5 )) && more=" ..."
  ph_log_warn "git_snapshot: ${count} SSH key file(s) are tracked in ${ha_config_dir}: $(head -n 5 <<<"${tracked}" | paste -sd ' ')${more}. Untrack them with 'git -C ${ha_config_dir} rm -r --cached .ssh' (and any other key file) and commit. Git history still contains them: rotate the keys if the repository was ever pushed."
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
    ph_git_update_ignore
    ph_git_warn_tracked_keys
    [[ "${enabled}" == "true" ]] && ph_log_info "git_snapshot: ${ha_config_dir} is already a git repository; leaving its history unchanged"
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
  ph_git_warn_tracked_keys   # only possible with a user-written .gitignore
}

ph_git_snapshot
