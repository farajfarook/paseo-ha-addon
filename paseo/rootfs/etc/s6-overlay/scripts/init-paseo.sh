#!/command/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# init-paseo: read add-on options, prepare persistent dirs and the daemon env,
# then run drop-in hooks from /etc/paseo-ha/init.d (sorted, non-fatal).
# ==============================================================================
set -o pipefail
# shellcheck source=/usr/local/lib/paseo-ha/common.sh
source /usr/local/lib/paseo-ha/common.sh

mkdir -p "${PASEO_HA_RUN_DIR}"
: > "${PASEO_HA_ENV_FILE}"
chmod 600 "${PASEO_HA_ENV_FILE}"

# --- Persistent home layout (D6) ---------------------------------------------
HOME_DIR="${PASEO_HA_DATA}/home"
ph_env_set HOME "${HOME_DIR}"
ph_env_set PASEO_HOME "${HOME_DIR}/.paseo"
ph_env_set CLAUDE_CONFIG_DIR "${HOME_DIR}/.claude"
ph_env_set CODEX_HOME "${HOME_DIR}/.codex"
ph_env_set PI_CODING_AGENT_DIR "${HOME_DIR}/.pi/agent"
ph_env_set XDG_CONFIG_HOME "${HOME_DIR}/.config"
ph_env_set XDG_DATA_HOME "${HOME_DIR}/.local/share"
ph_env_set XDG_STATE_HOME "${HOME_DIR}/.local/state"
ph_env_set XDG_CACHE_HOME "${HOME_DIR}/.cache"
ph_env_set SHELL /bin/bash
ph_env_set TERM xterm-256color
for d in "${HOME}" "${PASEO_HOME}" "${CLAUDE_CONFIG_DIR}" "${CODEX_HOME}" \
         "${PI_CODING_AGENT_DIR}" "${XDG_CONFIG_HOME}" "${XDG_DATA_HOME}" \
         "${XDG_STATE_HOME}" "${XDG_CACHE_HOME}"; do
  mkdir -p "${d}"
done
chmod 700 "${HOME}"

# No daemon can be running yet in this fresh container. A pid lock left in /data by
# the previous container may name a PID that is reused here, which would make
# `paseo daemon run` think another daemon is running and exit at once.
rm -f "${PASEO_HOME}/paseo.pid"

# Persistently installed agent CLIs (group 4) come first on PATH.
mkdir -p "${PASEO_HA_DATA}/agents"
ph_env_prepend_path "${PASEO_HA_DATA}/agents/node_modules/.bin"

# --- Workspace -----------------------------------------------------------------
WORKSPACE="$(ph_opt .workspace /homeassistant)"
if ! mkdir -p "${WORKSPACE}" 2>/dev/null; then
  ph_log_warn "Cannot create workspace ${WORKSPACE}; falling back to ${HOME}"
  WORKSPACE="${HOME}"
fi
ph_env_set PASEO_HA_WORKSPACE "${WORKSPACE}"

# --- Direct port (group 6, design D4) ------------------------------------------
# The daemon stays loopback-only unless the user mapped port 6767 AND set a
# password. With both, the daemon listens on 0.0.0.0 for the Paseo apps/CLI and
# nginx authenticates upstream (see 50-nginx.sh) so ingress stays password-free.
PASSWORD="$(ph_opt .password)"
DIRECT_PORT=""
if bashio::addon.available 2>/dev/null; then
  DIRECT_PORT="$(bashio::addon.port '6767' 2>/dev/null || true)"
else
  DIRECT_PORT="${PASEO_HA_DIRECT_PORT:-}"   # test seam for non-Supervisor environments
fi

# --- Fixed Paseo settings (D7a: add-on owned) ----------------------------------
ph_env_set PASEO_WEB_UI_ENABLED true
ph_env_set PASEO_LISTEN "127.0.0.1:${PASEO_HA_DAEMON_PORT}"
ph_env_set PASEO_TRUSTED_PROXIES loopback
ph_env_set PASEO_LOG_CONSOLE_FORMAT pretty

if [[ -n "${PASSWORD}" ]]; then
  if [[ -n "${DIRECT_PORT}" ]]; then
    ph_env_set PASEO_LISTEN "0.0.0.0:${PASEO_HA_DAEMON_PORT}"
    ph_env_set PASEO_PASSWORD "${PASSWORD}"
    ph_log_info "Direct port ${PASEO_HA_DAEMON_PORT} enabled with password (host port ${DIRECT_PORT})"
  else
    ph_log_warn "A password is set but port ${PASEO_HA_DAEMON_PORT} is not mapped; the daemon stays loopback-only and the direct port stays disabled"
  fi
elif [[ -n "${DIRECT_PORT}" ]]; then
  ph_log_warn "Port ${PASEO_HA_DAEMON_PORT} is mapped but no password is set; the daemon stays loopback-only, so the direct port refuses outside connections"
fi

LOG_LEVEL="$(ph_opt .log_level info)"
ph_env_set PASEO_LOG_CONSOLE_LEVEL "${LOG_LEVEL}"

# --- Speech (defaults off) -----------------------------------------------------
DICTATION="$(ph_opt_bool dictation)"; DICTATION="${DICTATION:-false}"
VOICE="$(ph_opt_bool voice_mode)"; VOICE="${VOICE:-false}"
SPEECH_PROVIDER="$(ph_opt .speech_provider local)"
ph_env_set PASEO_DICTATION_ENABLED "${DICTATION}"
ph_env_set PASEO_VOICE_MODE_ENABLED "${VOICE}"
ph_env_set PASEO_DICTATION_STT_PROVIDER "${SPEECH_PROVIDER}"
ph_env_set PASEO_VOICE_STT_PROVIDER "${SPEECH_PROVIDER}"
ph_env_set PASEO_VOICE_TTS_PROVIDER "${SPEECH_PROVIDER}"
if [[ "${SPEECH_PROVIDER}" == "local" ]] && { [[ "${DICTATION}" == "true" ]] || [[ "${VOICE}" == "true" ]]; }; then
  if ! paseo-ha-speech-check >/dev/null 2>&1; then
    # Turn both features off: otherwise the daemon would still download ~0.6-1 GB of
    # models that the engine cannot load. Later ph_env_set calls override the ones above.
    ph_env_set PASEO_DICTATION_ENABLED false
    ph_env_set PASEO_VOICE_MODE_ENABLED false
    ph_log_warn "Local speech engine (sherpa-onnx-node) cannot load on this platform ($(uname -m)). Dictation and voice mode are turned off and no speech models are downloaded; set speech_provider to 'openai' and add OPENAI_API_KEY to env_vars instead."
  else
    ph_log_info "Local speech enabled: models (~0.6-1 GB) are downloaded once into ${PASEO_HOME}/models/local-speech"
  fi
fi

# --- Hostnames -----------------------------------------------------------------
HOSTNAMES="$(ph_opt_list hostnames | paste -sd, -)"
if [[ -n "${HOSTNAMES}" ]]; then
  ph_env_set PASEO_HOSTNAMES "${HOSTNAMES}"
fi

# --- Relay: unset -> Paseo UI owns it; set -> forced -----------------------------
RELAY="$(ph_opt_bool relay)"
if [[ -n "${RELAY}" ]]; then
  ph_env_set PASEO_RELAY_ENABLED "${RELAY}"
  ph_log_info "Relay forced ${RELAY} by add-on option"
fi

# --- Worktrees root (persisted Paseo config; no env var exists) ----------------
WORKTREES_ROOT="$(ph_opt .worktrees_root)"
if [[ -n "${WORKTREES_ROOT}" ]]; then
  mkdir -p "${WORKTREES_ROOT}" || ph_log_warn "Cannot create worktrees root ${WORKTREES_ROOT}"
  paseo daemon config set worktrees.root "${WORKTREES_ROOT}" --home "${PASEO_HOME}" >/dev/null 2>&1 \
    || ph_log_warn "Failed to set worktrees.root"
else
  paseo daemon config unset worktrees.root --home "${PASEO_HOME}" >/dev/null 2>&1 || true
fi

# --- User environment variables (names only are logged) ------------------------
while IFS= read -r entry; do
  [[ -z "${entry}" ]] && continue
  name="$(jq -r '.name // empty' <<<"${entry}")"
  value="$(jq -r '.value // ""' <<<"${entry}")"
  if [[ ! "${name}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    ph_log_warn "Skipping env_vars entry with an invalid name"
    continue
  fi
  ph_env_set "${name}" "${value}"
  ph_log_info "Exported environment variable ${name}"
done < <(jq -c '(.env_vars // [])[]' "${PASEO_HA_OPTIONS_FILE}" 2>/dev/null)

# --- Drop-in hooks ---------------------------------------------------------------
# Each hook runs in its own bash process with common.sh sourced and the daemon env
# so far loaded. Hooks call ph_env_set to add daemon variables. Failures are
# logged and never abort startup.
shopt -s nullglob
for hook in "${PASEO_HA_HOOK_DIR}"/*.sh; do
  ph_log_debug "Running init hook $(basename "${hook}")"
  if ! bash -c 'source /usr/local/lib/paseo-ha/common.sh; ph_load_env; source "$1"' _ "${hook}"; then
    ph_log_warn "Init hook $(basename "${hook}") failed (continuing)"
  fi
done

ph_log_info "Paseo ${PASEO_HA_PASEO_VERSION:-?}; workspace ${WORKSPACE}"
exit 0
