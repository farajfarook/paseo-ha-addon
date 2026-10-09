#!/usr/bin/env bash
# ==============================================================================
# Smoke test for the Paseo add-on image (amd64). Works in CI and locally
# (Git Bash + Docker Desktop).
#
# Starts the image with a fake /data/options.json on a Docker network that uses
# the HA Supervisor subnet (172.30.32.0/23). It then talks to the ingress adapter
# (port 8099) from a client container at 172.30.32.2 (the HA ingress proxy
# address, the only one nginx allows) and from one other IP, and asserts:
#   a) GET /api/health with X-Ingress-Path            -> 200
#   b) GET / with X-Ingress-Path -> index.html has prefixed /_expo/ URLs, the
#      shim <script> tag and no bare "/_expo/ references
#   c) WebSocket upgrade on /ws with X-Ingress-Path    -> 101 (HA strips the
#      ingress prefix before forwarding, so the add-on sees /ws)
#   d) the same request from a different IP            -> 403
#   e) the daemon's server ID equals $PASEO_HOME/server-id and is rendered into
#      the shim tag; the 10-server-id hook derives the same ID for the same
#      HA UUID + hostname, another for another UUID, a random one without a
#      UUID, and never changes an existing file
#
# Usage: run.sh <image>
# Env:   SMOKE_PREFIX   name prefix for containers/network (default paseo-smoke)
#        SMOKE_TIMEOUT  seconds to wait for health (default 180)
#        SMOKE_KEEP=1   keep containers/network after the run (for debugging)
# ==============================================================================
set -euo pipefail
export MSYS_NO_PATHCONV=1 # Git Bash: don't rewrite container paths like /data

IMAGE="${1:-${SMOKE_IMAGE:-}}"
if [[ -z "${IMAGE}" ]]; then
  echo "usage: $0 <image>" >&2
  exit 2
fi

PREFIX="${SMOKE_PREFIX:-paseo-smoke}"
TIMEOUT="${SMOKE_TIMEOUT:-180}"
NET="${PREFIX}-net"
ADDON="${PREFIX}-addon"
CLIENT="${PREFIX}-ingress"   # 172.30.32.2 = HA ingress proxy
OTHER="${PREFIX}-other"      # any other address must be denied
SUBNET=172.30.32.0/23
INGRESS_IP=172.30.32.2
OTHER_IP=172.30.32.99
ADDON_IP=172.30.33.10
INGRESS_PATH=/api/hassio_ingress/smoketest
PORT=8099
BASE="http://${ADDON}:${PORT}"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Docker Desktop on Windows needs a native host path (MSYS_NO_PATHCONV is set).
HOST_DATA="${HERE}/data"
command -v cygpath >/dev/null 2>&1 && HOST_DATA="$(cygpath -m "${HOST_DATA}")"
FAILED=0
WORK="$(mktemp -d)"

log()  { echo "[smoke] $*"; }
pass() { echo "[smoke] PASS: $*"; }
fail() { echo "[smoke] FAIL: $*" >&2; FAILED=1; }

cleanup() {
  local rc=$?
  if [[ "${rc}" -ne 0 || "${FAILED}" -ne 0 ]]; then
    echo "[smoke] ----- add-on container logs (${ADDON}) -----" >&2
    docker logs "${ADDON}" 2>&1 | tail -n 300 >&2 || true
    echo "[smoke] ----- end of logs -----" >&2
  fi
  if [[ "${SMOKE_KEEP:-}" != "1" ]]; then
    docker rm -f "${ADDON}" "${CLIENT}" "${OTHER}" >/dev/null 2>&1 || true
    docker network rm "${NET}" >/dev/null 2>&1 || true
  fi
  rm -rf "${WORK}"
}
trap cleanup EXIT

# curl from a client container: ccurl <container> <curl args...>
ccurl() {
  local c="$1"; shift
  docker exec "${c}" curl -sS --max-time 10 "$@"
}

addon_running() {
  [[ "$(docker inspect -f '{{.State.Running}}' "${ADDON}" 2>/dev/null)" == "true" ]]
}

# --- Setup ----------------------------------------------------------------------
docker rm -f "${ADDON}" "${CLIENT}" "${OTHER}" >/dev/null 2>&1 || true
docker network rm "${NET}" >/dev/null 2>&1 || true

log "Creating network ${NET} (${SUBNET})"
if ! docker network create --subnet "${SUBNET}" "${NET}" >/dev/null; then
  echo "[smoke] cannot create ${NET}: is another network already using ${SUBNET}? (docker network ls)" >&2
  exit 1
fi

log "Starting add-on ${ADDON} from ${IMAGE}"
docker create --name "${ADDON}" --network "${NET}" --ip "${ADDON_IP}" "${IMAGE}" >/dev/null
# /data does not exist in the image: copying the directory creates it with options.json.
docker cp "${HOST_DATA}" "${ADDON}:/data"
docker start "${ADDON}" >/dev/null

# Clients reuse the add-on image (it ships curl), so nothing extra is pulled.
for spec in "${CLIENT}:${INGRESS_IP}" "${OTHER}:${OTHER_IP}"; do
  docker run -d --name "${spec%%:*}" --network "${NET}" --ip "${spec#*:}" \
    --entrypoint sleep "${IMAGE}" infinity >/dev/null
done

# --- Wait for daemon health, then for nginx --------------------------------------
log "Waiting up to ${TIMEOUT}s for the daemon and the ingress adapter"
deadline=$(( $(date +%s) + TIMEOUT ))
stage=daemon
while :; do
  if ! addon_running; then
    fail "add-on container exited ($(docker inspect -f '{{.State.ExitCode}}' "${ADDON}" 2>/dev/null))"
    exit 1
  fi
  if [[ "${stage}" == daemon ]]; then
    if docker exec "${ADDON}" curl -fs -o /dev/null --max-time 3 http://127.0.0.1:6767/api/health; then
      log "Daemon healthy on 127.0.0.1:6767"
      stage=nginx
      continue
    fi
  else
    code="$(ccurl "${CLIENT}" -o /dev/null -w '%{http_code}' --max-time 3 \
      -H "X-Ingress-Path: ${INGRESS_PATH}" "${BASE}/api/health" 2>/dev/null || true)"
    if [[ "${code}" == "200" ]]; then
      log "Ingress adapter answering on :${PORT}"
      break
    fi
  fi
  if (( $(date +%s) >= deadline )); then
    fail "timed out after ${TIMEOUT}s waiting for ${stage}"
    exit 1
  fi
  sleep 3
done

# --- a) health through nginx ------------------------------------------------------
code="$(ccurl "${CLIENT}" -o /dev/null -w '%{http_code}' -H "X-Ingress-Path: ${INGRESS_PATH}" \
  "${BASE}/api/health" || true)"
if [[ "${code}" == "200" ]]; then pass "a) /api/health via ingress -> 200"
else fail "a) /api/health via ingress -> ${code:-no response} (want 200)"; fi

# --- b) index.html rewritten ------------------------------------------------------
ccurl "${CLIENT}" -H "X-Ingress-Path: ${INGRESS_PATH}" -H "Accept: text/html" "${BASE}/" \
  > "${WORK}/index.html" || true
if grep -qF "${INGRESS_PATH}/_expo/" "${WORK}/index.html"; then
  pass "b) index.html references ${INGRESS_PATH}/_expo/"
else fail "b) index.html has no ${INGRESS_PATH}/_expo/ reference"; fi
if grep -qF "<script src=\"${INGRESS_PATH}/paseo-ha/shim.js\" data-paseo-server-id=\"" "${WORK}/index.html"; then
  pass "b) index.html injects the shim <script>"
else fail "b) index.html lacks <script src=\"${INGRESS_PATH}/paseo-ha/shim.js\""; fi
if grep -qF '"/_expo/' "${WORK}/index.html"; then
  fail "b) index.html still has bare \"/_expo/ references: $(grep -oF '"/_expo/' "${WORK}/index.html" | wc -l)"
else pass "b) no bare \"/_expo/ references"; fi
if [[ "${FAILED}" -ne 0 ]]; then
  echo "[smoke] ----- index.html (first 40 lines) -----" >&2
  head -n 40 "${WORK}/index.html" >&2 || true
fi

# --- b2) the shim tag is injected into HTML only, never into the JS bundle ---------
# The bundle embeds an HTML page in a string literal; a tag injected there is a
# syntax error that blanks the UI.
bundle="$(grep -oE "${INGRESS_PATH}/_expo/static/js/web/index-[^\"]+\.js" "${WORK}/index.html" | head -n1 || true)"
if [[ -z "${bundle}" ]]; then
  fail "b2) no main bundle URL found in index.html"
elif ccurl "${CLIENT}" -H "X-Ingress-Path: ${INGRESS_PATH}" "${BASE}${bundle#"${INGRESS_PATH}"}" > "${WORK}/bundle.js" \
  && ! grep -q 'paseo-ha/shim.js' "${WORK}/bundle.js"; then
  pass "b2) JS bundle has no injected shim tag"
else
  fail "b2) the JS bundle contains the shim tag"
fi

# --- c) WebSocket upgrade on /ws -------------------------------------------------
# curl gets 101 and then idles on the open socket until --max-time; -w still
# reports the status code.
# Retried briefly: a just-started 0.11.x daemon answers /api/health before its
# WebSocket listener binds, so the first upgrade after a start can get a 503.
# Paseo's own client retries, so the check is that the panel can connect, not
# that it can on the first packet.
tries=0
while :; do
  code="$(docker exec "${CLIENT}" curl -s --http1.1 --max-time 5 -o /dev/null -w '%{http_code}' \
    -H "X-Ingress-Path: ${INGRESS_PATH}" \
    -H "Connection: Upgrade" -H "Upgrade: websocket" \
    -H "Sec-WebSocket-Version: 13" -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
    "${BASE}/ws" || true)"
  if [[ "${code}" == "101" ]]; then break; fi
  tries=$((tries + 1))
  if (( tries >= 10 )); then break; fi
  sleep 1
done
if [[ "${code}" == "101" ]]; then pass "c) WebSocket upgrade on /ws -> 101"
else fail "c) WebSocket upgrade on /ws -> ${code:-no response} (want 101)"; fi

# --- d) other source IP denied ---------------------------------------------------
code="$(ccurl "${OTHER}" -o /dev/null -w '%{http_code}' -H "X-Ingress-Path: ${INGRESS_PATH}" \
  "${BASE}/api/health" || true)"
if [[ "${code}" == "403" ]]; then pass "d) request from ${OTHER_IP} -> 403"
else fail "d) request from ${OTHER_IP} -> ${code:-no response} (want 403)"; fi

# --- e) stable server ID ----------------------------------------------------------
live_id="$(ccurl "${CLIENT}" -H "X-Ingress-Path: ${INGRESS_PATH}" "${BASE}/api/status" | grep -oE '"serverId":"[^"]+"' | cut -d'"' -f4 || true)"
file_id="$(docker exec "${ADDON}" bash -c 'source /run/paseo-ha/daemon.env; head -n1 "${PASEO_HOME}/server-id"' 2>/dev/null | tr -d '[:space:]' || true)"
if [[ -n "${live_id}" && "${live_id}" == "${file_id}" ]]; then
  pass "e) daemon server ID ${live_id} comes from \$PASEO_HOME/server-id"
else fail "e) daemon server ID '${live_id}' != server-id file '${file_id}'"; fi
if [[ -n "${live_id}" ]] && grep -qF "data-paseo-server-id=\"${live_id}\"" "${WORK}/index.html"; then
  pass "e) shim tag carries the live server ID"
else fail "e) shim tag lacks data-paseo-server-id=\"${live_id}\""; fi

# Run the hook against scratch dirs: same UUID+host -> same ID, other UUID ->
# other ID, no UUID -> random srv_ ID, existing file -> unchanged.
# shellcheck disable=SC2016  # expanded inside the container
hook_out="$(docker exec "${ADDON}" bash -c '
  set -u
  run() { # run <home> <ha-config-dir>
    PASEO_HOME="$1" PASEO_HA_HA_CONFIG_DIR="$2" PASEO_HA_HOSTNAME=abcd1234-paseo \
      bash -c "source /usr/local/lib/paseo-ha/common.sh; source /etc/paseo-ha/init.d/10-server-id.sh" >/dev/null 2>&1
    head -n1 "$1/server-id" 2>/dev/null | tr -d "[:space:]"
  }
  t=$(mktemp -d)
  mkdir -p $t/ha1/.storage $t/ha2/.storage $t/ha0 $t/h1 $t/h2 $t/h3 $t/h4 $t/h5
  echo "{\"data\":{\"uuid\":\"0123456789abcdef0123456789abcdef\"}}" > $t/ha1/.storage/core.uuid
  echo "{\"data\":{\"uuid\":\"fedcba9876543210fedcba9876543210\"}}" > $t/ha2/.storage/core.uuid
  a=$(run $t/h1 $t/ha1); b=$(run $t/h2 $t/ha1); c=$(run $t/h3 $t/ha2); d=$(run $t/h4 $t/ha0)
  echo srv_existing_1 > $t/h5/server-id; e=$(run $t/h5 $t/ha1)
  echo "$a $b $c $d $e $(stat -c %a $t/h1/server-id)"
  rm -rf $t
' 2>&1 || true)"
read -r id_a id_b id_c id_d id_e id_mode <<<"${hook_out}"
re='^srv_[A-Za-z0-9_-]{12}$'
if [[ "${id_a:-}" =~ ${re} && "${id_a}" == "${id_b:-}" ]]; then pass "e) hook derives the same ID for the same HA UUID and hostname (${id_a})"
else fail "e) hook IDs differ or are malformed for one UUID: '${id_a:-}' '${id_b:-}' (${hook_out})"; fi
if [[ "${id_c:-}" =~ ${re} && "${id_c}" != "${id_a:-}" ]]; then pass "e) another HA UUID gives another ID"
else fail "e) another UUID gave '${id_c:-}'"; fi
if [[ "${id_d:-}" =~ ${re} ]]; then pass "e) no HA UUID gives a random srv_ ID"
else fail "e) no UUID gave '${id_d:-}'"; fi
if [[ "${id_e:-}" == "srv_existing_1" ]]; then pass "e) an existing server-id file is kept"
else fail "e) existing server-id became '${id_e:-}'"; fi
if [[ "${id_mode:-}" == "600" ]]; then pass "e) server-id is written with mode 600"
else fail "e) server-id mode is '${id_mode:-}'"; fi

if [[ "${FAILED}" -ne 0 ]]; then
  log "Smoke test FAILED"
  exit 1
fi
log "Smoke test passed"
