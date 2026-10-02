#!/usr/bin/env bash
# Shared helpers for paseo-ha init scripts and hooks.
# Source this file; it does not change shell options.

PASEO_HA_RUN_DIR="${PASEO_HA_RUN_DIR:-/run/paseo-ha}"
PASEO_HA_ENV_FILE="${PASEO_HA_ENV_FILE:-${PASEO_HA_RUN_DIR}/daemon.env}"
PASEO_HA_OPTIONS_FILE="${PASEO_HA_OPTIONS_FILE:-/data/options.json}"
PASEO_HA_DATA="${PASEO_HA_DATA:-/data}"
PASEO_HA_OPT_DIR="${PASEO_HA_OPT_DIR:-/opt/paseo-ha}"
PASEO_HA_HOOK_DIR="${PASEO_HA_HOOK_DIR:-/etc/paseo-ha/init.d}"
PASEO_HA_DAEMON_PORT="${PASEO_HA_DAEMON_PORT:-6767}"

# Logging: use bashio when available, plain stderr otherwise (tests).
if declare -F bashio::log.info >/dev/null 2>&1; then
  ph_log_info()  { bashio::log.info "$*"; }
  ph_log_warn()  { bashio::log.warning "$*"; }
  ph_log_error() { bashio::log.error "$*"; }
  ph_log_debug() { bashio::log.debug "$*"; }
else
  ph_log_info()  { echo "[paseo-ha] INFO: $*" >&2; }
  ph_log_warn()  { echo "[paseo-ha] WARNING: $*" >&2; }
  ph_log_error() { echo "[paseo-ha] ERROR: $*" >&2; }
  ph_log_debug() { [[ "${PASEO_HA_DEBUG:-}" == "1" ]] && echo "[paseo-ha] DEBUG: $*" >&2 || true; }
fi

# ph_opt <jq-path> [default]  -> prints the option value (raw), or default when null/missing.
ph_opt() {
  local path="$1" default="${2-}"
  local value
  value="$(jq -r "(${path}) // empty | if type == \"boolean\" then tostring else . end" "${PASEO_HA_OPTIONS_FILE}" 2>/dev/null || true)"
  if [[ -z "${value}" ]]; then
    printf '%s' "${default}"
  else
    printf '%s' "${value}"
  fi
}

# ph_opt_bool <key> -> prints true|false|"" (unset). Distinguishes false from unset.
ph_opt_bool() {
  jq -r --arg k "$1" 'if has($k) and (.[$k] != null) then (.[$k] | tostring) else "" end' \
    "${PASEO_HA_OPTIONS_FILE}" 2>/dev/null || true
}

# ph_opt_list <key> -> one entry per line.
ph_opt_list() {
  jq -r --arg k "$1" '(.[$k] // [])[] | tostring' "${PASEO_HA_OPTIONS_FILE}" 2>/dev/null || true
}

# ph_env_set NAME VALUE  -> record a variable for the daemon environment (and export it
# into the current shell). Later calls override earlier ones. Values are never logged.
ph_env_set() {
  local name="$1" value="$2"
  mkdir -p "$(dirname "${PASEO_HA_ENV_FILE}")"
  printf 'export %s=%q\n' "${name}" "${value}" >> "${PASEO_HA_ENV_FILE}"
  export "${name}=${value}"
}

# ph_env_unset NAME -> make sure NAME is not set in the daemon environment.
ph_env_unset() {
  mkdir -p "$(dirname "${PASEO_HA_ENV_FILE}")"
  printf 'unset %s\n' "$1" >> "${PASEO_HA_ENV_FILE}"
  unset "$1"
}

# ph_env_prepend_path DIR -> prepend DIR to the daemon PATH.
ph_env_prepend_path() {
  case ":${PATH}:" in
    *":$1:"*) ;;
    *) ph_env_set PATH "$1:${PATH}" ;;
  esac
}

# ph_load_env -> source the daemon env file into the current shell.
ph_load_env() {
  # shellcheck disable=SC1090
  [[ -f "${PASEO_HA_ENV_FILE}" ]] && source "${PASEO_HA_ENV_FILE}"
  return 0
}

# ph_daemon_url -> base URL of the local daemon (loopback).
ph_daemon_url() {
  printf 'http://127.0.0.1:%s' "${PASEO_HA_DAEMON_PORT}"
}
