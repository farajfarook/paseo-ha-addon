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

if [[ -n "${PASEO_PASSWORD:-}" ]]; then
  ph_log_info "Direct-port password configured; nginx authenticates to the daemon upstream"
  PASEO_HA_NGINX_PASSWORD="${PASEO_PASSWORD}" node "${PASEO_HA_OPT_DIR}/nginx/render.js" "${TPL}" "${CONF}"
else
  PASEO_HA_NGINX_PASSWORD="" node "${PASEO_HA_OPT_DIR}/nginx/render.js" "${TPL}" "${CONF}"
fi

if nginx -t >/dev/null 2>&1; then
  ph_log_info "nginx config rendered to ${CONF}"
else
  ph_log_error "nginx config test failed:"
  nginx -t 2>&1 | tail -n 5 >&2 || true
  exit 1
fi