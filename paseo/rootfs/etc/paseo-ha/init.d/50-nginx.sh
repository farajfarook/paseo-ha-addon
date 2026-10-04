#!/usr/bin/env bash
# shellcheck shell=bash
# ==============================================================================
# 50-nginx: render the nginx ingress config (group 5, design D3). Runs from
# init-paseo before the daemon starts. When the daemon is exposed on the direct
# port with a password (group 6, design D4: PASEO_PASSWORD is set in the daemon
# env), nginx authenticates upstream so the ingress UI stays password-free.
# ==============================================================================
# shellcheck source=/usr/local/lib/paseo-ha/common.sh
source /usr/local/lib/paseo-ha/common.sh
ph_load_env

TPL="${PASEO_HA_OPT_DIR}/nginx/paseo.conf.tpl"
CONF="/etc/nginx/http.d/paseo.conf"

if [[ ! -f "${TPL}" ]]; then
  ph_log_error "nginx template missing: ${TPL}"
  exit 1
fi

mkdir -p /etc/nginx/http.d /run/nginx

# The daemon's server ID goes into the shim tag so the panel can drop a stale
# host the browser remembers under an older ID (heal-stale-host-after-reinstall,
# design D3). PASEO_SERVER_ID wins inside the daemon, so it wins here too.
SERVER_ID="${PASEO_SERVER_ID:-}"
if [[ -z "${SERVER_ID}" && -r "${PASEO_HOME:-}/server-id" ]]; then
  SERVER_ID="$(head -n 1 "${PASEO_HOME}/server-id" | tr -d '[:space:]')"
fi
if [[ -z "${SERVER_ID}" ]]; then
  ph_log_warn "Server ID unknown; the panel cannot heal a stale host after a reinstall"
fi

if [[ -n "${PASEO_PASSWORD:-}" ]]; then
  ph_log_info "Direct-port password configured; nginx authenticates to the daemon upstream"
  PASEO_HA_SERVER_ID="${SERVER_ID}" PASEO_HA_NGINX_PASSWORD="${PASEO_PASSWORD}" node "${PASEO_HA_OPT_DIR}/nginx/render.js" "${TPL}" "${CONF}"
else
  PASEO_HA_SERVER_ID="${SERVER_ID}" PASEO_HA_NGINX_PASSWORD="" node "${PASEO_HA_OPT_DIR}/nginx/render.js" "${TPL}" "${CONF}"
fi

if nginx -t >/dev/null 2>&1; then
  ph_log_info "nginx config rendered to ${CONF}"
else
  ph_log_error "nginx config test failed:"
  nginx -t 2>&1 | tail -n 5 >&2 || true
  exit 1
fi