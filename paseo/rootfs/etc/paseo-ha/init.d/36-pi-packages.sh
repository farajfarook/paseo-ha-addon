#!/usr/bin/env bash
# shellcheck shell=bash
# ==============================================================================
# 36-pi-packages: install the default Pi packages (/opt/paseo-ha/pi-packages.default)
# once per installation. Pi's own settings.json (global `packages`) stays the only
# record of what is installed, so `pi install` / `pi remove` from a Paseo terminal
# persist across restarts and add-on updates (everything lives under /data).
#
# - A default is "offered" once: its identity (npm name or git host/path, version
#   and ref ignored) is recorded in /data/paseo-ha/pi-packages.offered. A default the
#   user removes is therefore never reinstalled.
# - A default that is already configured (the user installed it) is recorded without
#   running an install.
# - A failed install is logged and NOT recorded, so the next start retries it.
# - All installs share one time budget (PASEO_HA_PI_BUDGET, default 600 s) so a stalled
#   registry cannot hold up the daemon; unfinished defaults are retried on the next start.
# - Never aborts startup.
# ==============================================================================

DEFAULTS_FILE="${PASEO_HA_PI_DEFAULTS:-${PASEO_HA_OPT_DIR}/pi-packages.default}"   # override is a test seam
LEDGER="${PASEO_HA_DATA}/paseo-ha/pi-packages.offered"
PI_SETTINGS="${PI_CODING_AGENT_DIR:-${HOME}/.pi/agent}/settings.json"
INSTALL_TIMEOUT="${PASEO_HA_PI_INSTALL_TIMEOUT:-300}"   # per install
INSTALL_BUDGET="${PASEO_HA_PI_BUDGET:-600}"             # all installs together

# ph_pi_identity SOURCE -> package identity, matching Pi's own (version/ref ignored).
ph_pi_identity() {
  local src="$1" spec name rest
  case "${src}" in
    npm:*)
      spec="${src#npm:}"
      if [[ "${spec}" == @* ]]; then
        rest="${spec:1}"
        name="@${rest%%@*}"
      else
        name="${spec%%@*}"
      fi
      printf 'npm:%s' "${name}"
      ;;
    ./* | ../* | /* | ~*)
      printf 'local:%s' "${src}"
      ;;
    *)
      rest="${src#git:}"
      if [[ "${rest}" =~ ^git@([^:]+):(.+)$ ]]; then          # scp-like: git@host:path[@ref]
        rest="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
      elif [[ "${rest}" == *://* ]]; then                     # https:// ssh:// git://
        rest="${rest#*://}"
        [[ "${rest%%/*}" == *@* ]] && rest="${rest#*@}"      # drop user@ before the host
      fi
      rest="${rest%%@*}"                                      # drop @ref
      rest="${rest%.git}"
      printf 'git:%s' "${rest%/}"
      ;;
  esac
}

ph_pi_offline() {
  case "${PI_OFFLINE:-}" in 1 | true | TRUE | True | yes | YES | Yes) return 0 ;; esac
  return 1
}

# Sources currently configured in Pi's global settings, one per line.
ph_pi_configured_sources() {
  [[ -f "${PI_SETTINGS}" ]] || return 0
  jq -r '(.packages // [])[] | if type == "string" then . else .source // empty end' "${PI_SETTINGS}" 2>/dev/null || true
}

ph_pi_log_installed() {
  local list
  list="$(ph_pi_configured_sources | paste -sd' ' -)"
  ph_log_info "Pi packages: ${list:-none}"
}

ph_pi_offer_defaults() {
  local src id log remaining
  local deadline=$((SECONDS + INSTALL_BUDGET))
  local -A configured=()
  local -A offered=()

  mkdir -p "$(dirname "${LEDGER}")"
  touch "${LEDGER}"
  while IFS= read -r id; do
    [[ -n "${id}" ]] && offered["${id}"]=1
  done < "${LEDGER}"
  while IFS= read -r src; do
    [[ -n "${src}" ]] && configured["$(ph_pi_identity "${src}")"]=1
  done < <(ph_pi_configured_sources)

  [[ -f "${DEFAULTS_FILE}" ]] || return 0
  while IFS= read -r src || [[ -n "${src}" ]]; do
    src="${src%%#*}"
    src="${src#"${src%%[![:space:]]*}"}"
    src="${src%"${src##*[![:space:]]}"}"
    [[ -z "${src}" ]] && continue
    id="$(ph_pi_identity "${src}")"

    if [[ -n "${offered[${id}]:-}" ]]; then
      continue
    fi
    if [[ -n "${configured[${id}]:-}" ]]; then
      ph_log_debug "Pi package ${id} is already installed; recording it as offered"
      echo "${id}" >> "${LEDGER}"
      offered["${id}"]=1
      continue
    fi
    if ph_pi_offline; then
      ph_log_info "PI_OFFLINE is set; not installing default Pi package ${src}"
      continue
    fi

    remaining=$((deadline - SECONDS))
    if (( remaining <= 0 )); then
      ph_log_warn "Default Pi package install time budget (${INSTALL_BUDGET}s) used up; the remaining defaults, starting with ${src}, will be installed on the next start"
      break
    fi
    (( remaining > INSTALL_TIMEOUT )) && remaining="${INSTALL_TIMEOUT}"

    ph_log_info "Installing default Pi package ${src}..."
    log="$(mktemp)"
    if (cd "${HOME}" && PI_TELEMETRY=0 PI_SKIP_VERSION_CHECK=1 timeout "${remaining}" pi install "${src}") >"${log}" 2>&1; then
      echo "${id}" >> "${LEDGER}"
      offered["${id}"]=1
      ph_log_info "Installed Pi package ${src}"
    else
      ph_log_warn "Could not install default Pi package ${src}; it will be retried on the next start. Last output:"
      tail -n 5 "${log}" | while IFS= read -r line; do ph_log_warn "  ${line}"; done
    fi
    rm -f "${log}"
  done < "${DEFAULTS_FILE}"
}

ph_pi_offer_defaults || ph_log_warn "Default Pi package setup hit an error (continuing)"
ph_pi_log_installed
exit 0
