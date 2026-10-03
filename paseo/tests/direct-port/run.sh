#!/usr/bin/env bash
# ==============================================================================
# Direct-port test (tasks 6.1 / 6.2). Runs the image twice with a fake
# /data/options.json and PASEO_HA_DIRECT_PORT=6767 (the test seam standing in for
# bashio::addon.port):
#
#   Case A: password set
#     - add-on log reports the direct port enabled; no password in the log
#     - from another container: /api/health on :6767 without a bearer -> 401
#     - ... with the right bearer -> 200, with a wrong bearer -> 401
#     - ingress (:8099, from 172.30.32.2) still works with no prompt -> 200
#     - the WebSocket through ingress reaches the daemon (101)
#   Case B: no password
#     - add-on log has the "no password" warning
#     - :6767 from another container refuses the connection
#
# Usage: run.sh <image>
# Env:   DP_TIMEOUT  seconds to wait for health (default 180)
# ==============================================================================
set -euo pipefail
export MSYS_NO_PATHCONV=1

IMAGE="${1:-}"
[[ -n "${IMAGE}" ]] || { echo "usage: $0 <image>" >&2; exit 2; }

TIMEOUT="${DP_TIMEOUT:-180}"
NET=paseo-dp-net
ADDON=paseo-dp-addon
INGRESS=paseo-dp-ingress   # 172.30.32.2 = HA ingress proxy
OTHER=paseo-dp-other       # a LAN client
SUBNET=172.30.32.0/23
ADDON_IP=172.30.33.10
INGRESS_PATH=/api/hassio_ingress/dptest
PASSWORD='s3cret-pw'
FAILED=0
WORK="$(mktemp -d)"

log()  { echo "[direct-port] $*"; }
pass() { echo "[direct-port] PASS: $*"; }
fail() { echo "[direct-port] FAIL: $*" >&2; FAILED=1; }

cleanup() {
  docker rm -f "${ADDON}" "${INGRESS}" "${OTHER}" >/dev/null 2>&1 || true
  docker network rm "${NET}" >/dev/null 2>&1 || true
  rm -rf "${WORK}"
}
trap '[[ "${FAILED}" -ne 0 ]] && docker logs "${ADDON}" 2>&1 | tail -40 >&2; cleanup' EXIT

ccurl() { local c="$1"; shift; docker exec "${c}" curl -sS --max-time 10 "$@"; }

start_addon() { # $1 = password ("" for none)
  docker rm -f "${ADDON}" >/dev/null 2>&1 || true
  if [[ -n "$1" ]]; then pw=',"password":"'"$1"'"'; else pw=""; fi
  printf '{"workspace":"/homeassistant","git_snapshot":false,"agents":[],"env_vars":[],"hostnames":[],"log_level":"info","dictation":false,"voice_mode":false,"speech_provider":"local"%s}' "${pw}" > "${WORK}/options.json"
  docker create --name "${ADDON}" --network "${NET}" --ip "${ADDON_IP}" \
    -e PASEO_HA_DIRECT_PORT=6767 "${IMAGE}" >/dev/null
  local d="${WORK}/data"; rm -rf "${d}"; mkdir -p "${d}"; cp "${WORK}/options.json" "${d}/options.json"
  local hp="${d}"; command -v cygpath >/dev/null 2>&1 && hp="$(cygpath -m "${d}")"
  docker cp "${hp}" "${ADDON}:/data"
  docker start "${ADDON}" >/dev/null
  local deadline=$(( $(date +%s) + TIMEOUT ))
  until docker exec "${ADDON}" curl -s -o /dev/null --max-time 3 http://127.0.0.1:6767/api/health 2>/dev/null; do
    [[ "$(docker inspect -f '{{.State.Running}}' "${ADDON}")" == true ]] || { fail "add-on exited"; docker logs "${ADDON}" 2>&1 | tail -50 >&2; exit 1; }
    (( $(date +%s) < deadline )) || { fail "timeout waiting for daemon"; docker logs "${ADDON}" 2>&1 | tail -50 >&2; exit 1; }
    sleep 3
  done
  # nginx starts after the daemon; wait for the ingress listener too.
  until ccurl "${INGRESS}" -o /dev/null -H "X-Ingress-Path: ${INGRESS_PATH}" "http://${ADDON}:8099/api/health" 2>/dev/null; do
    (( $(date +%s) < deadline )) || { fail "timeout waiting for nginx"; exit 1; }
    sleep 2
  done
}

docker rm -f "${ADDON}" "${INGRESS}" "${OTHER}" >/dev/null 2>&1 || true
docker network rm "${NET}" >/dev/null 2>&1 || true
docker network create --subnet "${SUBNET}" "${NET}" >/dev/null
docker run -d --name "${INGRESS}" --network "${NET}" --ip 172.30.32.2 --entrypoint sleep "${IMAGE}" infinity >/dev/null
docker run -d --name "${OTHER}" --network "${NET}" --ip 172.30.32.99 --entrypoint sleep "${IMAGE}" infinity >/dev/null

# --- Case A: password set ----------------------------------------------------------
log "Case A: password set, port 6767 mapped"
start_addon "${PASSWORD}"
LOGS="$(docker logs "${ADDON}" 2>&1)"
grep -q "Direct port 6767 enabled with password" <<<"${LOGS}" && pass "A) log says the direct port is enabled" \
  || fail "A) no 'Direct port ... enabled' log line"
if grep -qF "${PASSWORD}" <<<"${LOGS}"; then fail "A) password leaked into the add-on log"; else pass "A) password not in the log"; fi

code="$(ccurl "${OTHER}" -o /dev/null -w '%{http_code}' "http://${ADDON_IP}:6767/api/status" || true)"
[[ "${code}" == 401 ]] && pass "A) :6767/api/status without bearer -> 401" || fail "A) without bearer -> ${code} (want 401)"
code="$(ccurl "${OTHER}" -o /dev/null -w '%{http_code}' -H "Authorization: Bearer ${PASSWORD}" "http://${ADDON_IP}:6767/api/status" || true)"
[[ "${code}" == 200 ]] && pass "A) :6767/api/status with bearer -> 200" || fail "A) with bearer -> ${code} (want 200)"
code="$(ccurl "${OTHER}" -o /dev/null -w '%{http_code}' -H "Authorization: Bearer wrong" "http://${ADDON_IP}:6767/api/status" || true)"
[[ "${code}" == 401 ]] && pass "A) wrong bearer -> 401" || fail "A) wrong bearer -> ${code} (want 401)"

code="$(ccurl "${INGRESS}" -o /dev/null -w '%{http_code}' -H "X-Ingress-Path: ${INGRESS_PATH}" "http://${ADDON}:8099/api/health" || true)"
[[ "${code}" == 200 ]] && pass "A) ingress /api/health without credentials -> 200" || fail "A) ingress -> ${code} (want 200)"
code="$(docker exec "${INGRESS}" curl -s --http1.1 --max-time 5 -o /dev/null -w '%{http_code}' \
  -H "X-Ingress-Path: ${INGRESS_PATH}" -H "Connection: Upgrade" -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Version: 13" -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
  "http://${ADDON}:8099/ws" || true)"
[[ "${code}" == 101 ]] && pass "A) ingress WebSocket upgrade -> 101 (bearer subprotocol injected)" || fail "A) ingress WS -> ${code} (want 101)"
# The daemon authenticates WebSockets after the upgrade: a wrong bearer subprotocol
# is closed with 4401 and logged, a right one is not. So: through ingress (nginx
# injects the bearer) nothing may be rejected; a direct wrong bearer must be.
if docker logs "${ADDON}" 2>&1 | grep -q "Rejected WebSocket connection with invalid daemon password"; then
  fail "A) the ingress WebSocket was rejected for an invalid password (bearer subprotocol not injected correctly)"
else pass "A) ingress WebSocket accepted by the daemon (no password rejection)"; fi
docker exec "${OTHER}" curl -s --http1.1 --max-time 3 -o /dev/null   -H "Connection: Upgrade" -H "Upgrade: websocket" -H "Sec-WebSocket-Protocol: paseo.bearer.wrong"   -H "Sec-WebSocket-Version: 13" -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ=="   "http://${ADDON_IP}:6767/ws" || true
sleep 1
if docker logs "${ADDON}" 2>&1 | grep -q "Rejected WebSocket connection with invalid daemon password"; then
  pass "A) direct WebSocket with a wrong bearer is rejected by the daemon"
else fail "A) direct WebSocket with a wrong bearer was not rejected"; fi

# --- Case B: no password -----------------------------------------------------------
log "Case B: no password, port 6767 mapped"
start_addon ""
LOGS="$(docker logs "${ADDON}" 2>&1)"
grep -q "mapped but no password is set" <<<"${LOGS}" && pass "B) warning logged" || fail "B) no 'mapped but no password' warning"
if docker exec "${OTHER}" curl -s --max-time 5 -o /dev/null "http://${ADDON_IP}:6767/api/health"; then
  fail "B) :6767 reachable from another host without a password"
else pass "B) :6767 refuses connections from another host"; fi
code="$(ccurl "${INGRESS}" -o /dev/null -w '%{http_code}' -H "X-Ingress-Path: ${INGRESS_PATH}" "http://${ADDON}:8099/api/health" || true)"
[[ "${code}" == 200 ]] && pass "B) ingress still works -> 200" || fail "B) ingress -> ${code}"

[[ "${FAILED}" -eq 0 ]] || { log "Direct-port test FAILED"; exit 1; }
log "Direct-port test passed"
