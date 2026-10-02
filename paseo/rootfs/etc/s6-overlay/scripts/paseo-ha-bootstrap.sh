#!/command/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# paseo-ha-bootstrap (design D14a): once the daemon is healthy, make sure a Paseo
# project exists for the Home Assistant config (named "Home Assistant" when we
# create it) and for the workspace option when it is a different directory.
# Existing projects are never renamed. Always exits 0 (a failing oneshot would
# stop the container).
# ==============================================================================
# shellcheck source=/usr/local/lib/paseo-ha/common.sh
source /usr/local/lib/paseo-ha/common.sh
ph_load_env

ha_config_dir="${PASEO_HA_HA_CONFIG_DIR:-/homeassistant}"
ha_project_name="Home Assistant"

ph_paseo() {
  timeout 60 paseo "$@" --home "${PASEO_HOME}" --json
}

# ph_project_id_for PATH -> prints the projectId of the project rooted at PATH.
ph_project_id_for() {
  local path="${1%/}"
  ph_paseo project ls 2>/dev/null \
    | jq -r --arg p "${path}" '[.[]? | select((.path // "" | rtrimstr("/")) == $p)][0].projectId // empty'
}

# ph_ensure_project PATH [NAME] -> register PATH unless a project for it exists;
# rename to NAME only when this call created the project.
ph_ensure_project() {
  local path="$1" name="${2-}" out id
  if [[ ! -d "${path}" ]]; then
    ph_log_warn "Bootstrap: ${path} does not exist; not registering a project for it"
    return 0
  fi
  if ! ph_paseo project ls >/dev/null 2>&1; then
    ph_log_warn "Bootstrap: cannot list Paseo projects; skipping"
    return 1
  fi
  id="$(ph_project_id_for "${path}")"
  if [[ -n "${id}" ]]; then
    ph_log_debug "Bootstrap: project for ${path} already exists (${id})"
    return 0
  fi
  if ! out="$(ph_paseo project create "${path}" 2>&1)"; then
    ph_log_warn "Bootstrap: failed to create a project for ${path}: ${out}"
    return 1
  fi
  id="$(jq -r '.projectId // (.[0]?.projectId) // empty' <<<"${out}" 2>/dev/null)"
  [[ -n "${id}" ]] || id="$(ph_project_id_for "${path}")"
  ph_log_info "Bootstrap: registered Paseo project for ${path}"
  if [[ -n "${name}" && -n "${id}" ]]; then
    if ph_paseo project rename "${id}" "${name}" >/dev/null 2>&1; then
      ph_log_info "Bootstrap: named it \"${name}\""
    else
      ph_log_warn "Bootstrap: could not rename project ${id} to \"${name}\""
    fi
  fi
}

ph_ensure_project "${ha_config_dir}" "${ha_project_name}" || true
workspace="${PASEO_HA_WORKSPACE:-${ha_config_dir}}"
if [[ "${workspace%/}" != "${ha_config_dir%/}" ]]; then
  ph_ensure_project "${workspace}" || true
fi
exit 0
