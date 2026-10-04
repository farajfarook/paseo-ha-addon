#!/usr/bin/env bash
# shellcheck shell=bash
# ==============================================================================
# 10-server-id (change heal-stale-host-after-reinstall, design D1/D2): keep the
# daemon's server ID stable across reinstalls.
#
# Paseo reads its ID from $PASEO_HOME/server-id and creates a random one when the
# file is missing. Uninstalling the add-on wipes /data, so a reinstall used to get
# a new ID, and browsers that knew the old one stayed on "Reconnecting to host".
#
# - An existing, non-empty server-id file is never changed.
# - Otherwise write srv_<12 base64url chars of sha256(salt:uuid:hostname)>, using
#   the Home Assistant instance UUID and this add-on's hostname, so the same
#   add-on on the same HA gets the same ID again.
# - Without a usable UUID, write a random ID of the same shape.
# PASEO_SERVER_ID (env_vars) still overrides everything inside the daemon.
# Test seams: PASEO_HA_HA_CONFIG_DIR, PASEO_HA_HOSTNAME.
# Failures are logged and never block startup: the daemon then creates an ID itself.
# ==============================================================================
set -euo pipefail

id_file="${PASEO_HOME:?PASEO_HOME is not set}/server-id"
uuid_file="${PASEO_HA_HA_CONFIG_DIR:-/homeassistant}/.storage/core.uuid"
host_name="${PASEO_HA_HOSTNAME:-$(hostname 2>/dev/null || true)}"

if [[ -s "${id_file}" ]] && [[ -n "$(tr -d '[:space:]' < "${id_file}" 2>/dev/null)" ]]; then
  ph_log_debug "Server ID kept from ${id_file}"
  exit 0
fi

uuid=""
if [[ -r "${uuid_file}" ]]; then
  uuid="$(jq -r '.data.uuid // empty' "${uuid_file}" 2>/dev/null || true)"
fi
# HA writes a 32-char hex UUID; accept common UUID shapes and nothing else.
if [[ ! "${uuid}" =~ ^[0-9A-Fa-f-]{32,36}$ ]]; then
  uuid=""
fi

if [[ -n "${uuid}" && -n "${host_name}" ]]; then
  server_id="$(PH_SEED="paseo-ha:server-id:v1:${uuid,,}:${host_name}" node -e '
    const h = require("crypto").createHash("sha256").update(process.env.PH_SEED).digest("base64url");
    process.stdout.write("srv_" + h.slice(0, 12));
  ' 2>/dev/null || true)"
  source_desc="derived from the Home Assistant instance"
else
  server_id="$(node -e 'process.stdout.write("srv_" + require("crypto").randomBytes(9).toString("base64url"))' 2>/dev/null || true)"
  source_desc="random (Home Assistant instance UUID unavailable)"
fi

if [[ ! "${server_id}" =~ ^srv_[A-Za-z0-9_-]{12}$ ]]; then
  ph_log_warn "Could not create a server ID; Paseo will create one itself"
  exit 0
fi

tmp=""
if mkdir -p "$(dirname "${id_file}")" \
  && tmp="$(mktemp "${id_file}.XXXXXX")" \
  && printf '%s\n' "${server_id}" > "${tmp}" \
  && chmod 600 "${tmp}" \
  && mv -f "${tmp}" "${id_file}"; then
  ph_log_info "Server ID ${server_id} created (${source_desc})"
else
  if [[ -n "${tmp}" ]]; then rm -f "${tmp}"; fi
  ph_log_warn "Could not write ${id_file}; Paseo will create a random server ID itself"
fi
