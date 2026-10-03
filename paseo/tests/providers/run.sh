#!/usr/bin/env bash
# shellcheck disable=SC2016  # commands are expanded inside the container
# ==============================================================================
# Integration test for the providers hook (20-providers.sh): installs, uninstalls,
# retries and the provider enable flags in Paseo's persisted config. It runs the
# hook from this checkout inside the add-on image, with real npm installs, so it
# needs network access. No daemon is started.
#
#   paseo/tests/providers/run.sh [image]     (default: paseo-ha-test)
# ==============================================================================
set -uo pipefail
export MSYS_NO_PATHCONV=1

IMAGE="${1:-paseo-ha-test}"
HERE="$(cd "$(dirname "$0")" && pwd)"
HOOK="${HERE}/../../rootfs/etc/paseo-ha/init.d/20-providers.sh"
C="providers-test"
fails=0
hostpath() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else echo "$1"; fi; }
pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*"; fails=$((fails + 1)); }
cleanup() { docker rm -f "${C}" >/dev/null 2>&1; }
trap cleanup EXIT
cleanup

docker run -d --name "${C}" --entrypoint sleep \
  -v "$(hostpath "${HOOK}"):/h/20-providers.sh:ro" "${IMAGE}" infinity >/dev/null || { echo "cannot start ${IMAGE}"; exit 1; }

# run_hook <providers-json> [fail-ids] -> runs the hook; its log goes to /tmp/hook.log in the container.
run_hook() {
  docker exec -e PROV="$1" -e FAILIDS="${2:-}" "${C}" bash -c '
    mkdir -p /data /run/paseo-ha /data/home/.paseo
    echo "{\"providers\":${PROV}}" > /data/options.json
    export PASEO_HOME=/data/home/.paseo PASEO_HA_TEST_FAIL_INSTALL="${FAILIDS}"
    bash -c "source /usr/local/lib/paseo-ha/common.sh; source /h/20-providers.sh" > /tmp/hook.log 2>&1
    echo "rc=$?" >> /tmp/hook.log'
}
hook_rc_ok() { docker exec "${C}" grep -q '^rc=0$' /tmp/hook.log; }
log_has() { docker exec "${C}" grep -qE "$1" /tmp/hook.log; }
# enabled <id> -> true|false|unset from the persisted config
enabled() {
  docker exec "${C}" bash -c "jq -r '(.agents.providers.\"$1\".enabled | tostring)' /data/home/.paseo/config.json"
}
installed() { docker exec "${C}" test -x "/data/agents/node_modules/.bin/$1"; }
expect_enabled() { # <id>=<true|false> ...
  local pair
  for pair in "$@"; do
    [[ "$(enabled "${pair%%=*}")" == "${pair#*=}" ]] && pass "  ${pair%%=*} enabled=${pair#*=}" || fail "  ${pair%%=*} expected enabled=${pair#*=}, got $(enabled "${pair%%=*}")"
  done
}

echo "== default [pi]: only Pi is enabled, nothing installed"
run_hook '["pi"]'
hook_rc_ok && pass "hook exits 0" || fail "hook exit"
expect_enabled pi=true claude=false codex=false copilot=false opencode=false omp=false

echo "== [codex]: installed and enabled; Pi disabled but still runnable"
run_hook '["codex"]'
installed codex && pass "codex installed" || fail "codex not installed"
expect_enabled codex=true pi=false
docker exec "${C}" pi --version >/dev/null 2>&1 && pass "pi still in the image" || fail "pi missing"

echo "== same selection again: no npm install"
run_hook '["codex"]'
if log_has 'Installing provider'; then fail "second run reinstalled"; else pass "no reinstall"; fi
log_has 'Providers up to date: codex' && pass "reported up to date" || fail "no up-to-date line"

echo "== [] : uninstalled, all six disabled, home dir kept"
docker exec "${C}" mkdir -p /data/home/.codex
docker exec "${C}" sh -c 'echo keep > /data/home/.codex/auth.json'
run_hook '[]'
installed codex && fail "codex still installed" || pass "codex uninstalled"
expect_enabled pi=false claude=false codex=false copilot=false opencode=false omp=false
docker exec "${C}" test -f /data/home/.codex/auth.json && pass "credentials kept" || fail "credentials removed"
hook_rc_ok && pass "hook exits 0 with no providers" || fail "hook exit"

echo "== forced install failure: disabled, logged, retried next start"
run_hook '["pi","claude"]' claude
hook_rc_ok && pass "hook exits 0 despite failure" || fail "hook exit"
log_has 'ERROR.*claude' && pass "failure logged" || fail "failure not logged"
expect_enabled claude=false pi=true
run_hook '["pi","claude"]'
installed claude && pass "claude installed on retry" || fail "claude not retried"
expect_enabled claude=true pi=true

echo "== hand-enabled provider is reset; other overrides kept"
docker exec "${C}" bash -c 'PASEO_HOME=/data/home/.paseo; paseo daemon config set agents.providers "{\"codex\":{\"enabled\":true,\"label\":\"Mine\"},\"pi\":{\"enabled\":true}}" --home $PASEO_HOME >/dev/null'
run_hook '["pi","claude"]'
expect_enabled codex=false pi=true claude=true
[[ "$(docker exec "${C}" jq -r '.agents.providers.codex.label' /data/home/.paseo/config.json)" == "Mine" ]] && pass "codex label override kept" || fail "label override lost"

echo "== unknown provider ignored"
run_hook '["pi","nope"]'
log_has "Unknown provider 'nope'" && pass "unknown value warned" || fail "no warning"
hook_rc_ok && pass "hook exits 0" || fail "hook exit"

echo
if [[ "${fails}" -ne 0 ]]; then echo "providers test: ${fails} failure(s)"; docker exec "${C}" cat /tmp/hook.log 2>/dev/null | tail -20; exit 1; fi
echo "providers test passed"
