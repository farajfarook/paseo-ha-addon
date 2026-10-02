#!/usr/bin/env bash
# shellcheck shell=bash
# ==============================================================================
# 40-ha-env (design D13): give agents live Home Assistant API access.
# The Supervisor injects SUPERVISOR_TOKEN into the container environment
# (homeassistant_api/hassio_api in config.yaml). Make sure it, plus the
# conventional HASS_SERVER/HASS_TOKEN names, end up in the daemon environment.
# Token values are never logged.
# ==============================================================================

if [[ -z "${SUPERVISOR_TOKEN:-}" && -r /run/s6/container_environment/SUPERVISOR_TOKEN ]]; then
  SUPERVISOR_TOKEN="$(cat /run/s6/container_environment/SUPERVISOR_TOKEN)"
fi

ph_env_set HASS_SERVER "http://supervisor/core"
if [[ -n "${SUPERVISOR_TOKEN:-}" ]]; then
  ph_env_set SUPERVISOR_TOKEN "${SUPERVISOR_TOKEN}"
  ph_env_set HASS_TOKEN "${SUPERVISOR_TOKEN}"
  ph_log_info "Home Assistant API access: SUPERVISOR_TOKEN, HASS_SERVER and HASS_TOKEN exported to agents"
else
  ph_log_warn "SUPERVISOR_TOKEN is not set (not running under the Supervisor?); agents have no Home Assistant API access"
fi
