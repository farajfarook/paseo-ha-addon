#!/usr/bin/env bash
# shellcheck disable=SC2016  # commands are expanded inside the container
# ==============================================================================
# Integration test for the providers hook (20-providers.sh): installs at the
# latest stable version, upgrades, rollbacks, offline starts, uninstalls, retries
# and the provider enable flags in Paseo's persisted config. It runs the hook from
# this checkout inside the add-on image, with real npm installs, so it needs
# network access. No daemon is started.
#
# The two providers that are not npm packages (Muse Code, Antigravity) are tested
# through PASEO_HA_TEST_SCRIPT_URL with a stub vendor installer written into the
# container, so the test never downloads them (~336 MB for Muse Code alone).
#
#   paseo/tests/providers/run.sh [image]     (default: paseo-ha-test)
# ==============================================================================
set -uo pipefail
export MSYS_NO_PATHCONV=1

IMAGE="${1:-paseo-ha-test}"
HERE="$(cd "$(dirname "$0")" && pwd)"
HOOK="${HERE}/../../rootfs/etc/paseo-ha/init.d/20-providers.sh"
C="providers-test"
OLD_CODEX="0.159.0"     # an older published Codex used as a stand-in "other" release
OTHER_CODEX="0.159.3"
STAMP=/data/agents/.paseo-ha-providers.stamp
FAILED=/data/agents/.paseo-ha-providers.failed
fails=0
hostpath() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else echo "$1"; fi; }
pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*"; fails=$((fails + 1)); }
cleanup() { docker rm -f "${C}" >/dev/null 2>&1; }
trap cleanup EXIT
cleanup

docker run -d --name "${C}" --entrypoint sleep \
  -v "$(hostpath "${HOOK}"):/h/20-providers.sh:ro" "${IMAGE}" infinity >/dev/null || { echo "cannot start ${IMAGE}"; exit 1; }

# run_hook <providers-json> [VAR=value ...] -> runs the hook with those test seams set;
# its log goes to /tmp/hook.log in the container.
run_hook() {
  local prov="$1" envs=() kv
  shift
  for kv in "$@"; do envs+=(-e "${kv}"); done
  docker exec -e PROV="${prov}" "${envs[@]}" "${C}" bash -c '
    mkdir -p /data /run/paseo-ha /data/home/.paseo
    echo "{\"providers\":${PROV}}" > /data/options.json
    export PASEO_HOME=/data/home/.paseo
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
script_installed() { docker exec "${C}" test -x "/data/agents/bin/$1/$2"; }
stamp_has() { docker exec "${C}" grep -qxF "$1" "${STAMP}"; }
cli_version() { docker exec "${C}" sh -c "/data/agents/node_modules/.bin/$1 --version 2>/dev/null | head -n1"; }
expect_enabled() { # <id>=<true|false> ...
  local pair
  for pair in "$@"; do
    [[ "$(enabled "${pair%%=*}")" == "${pair#*=}" ]] && pass "  ${pair%%=*} enabled=${pair#*=}" || fail "  ${pair%%=*} expected enabled=${pair#*=}, got $(enabled "${pair%%=*}")"
  done
}

LATEST_CODEX="$(docker exec "${C}" npm view @openai/codex@latest version 2>/dev/null | tail -n1)"
LATEST_PI="$(docker exec "${C}" npm view @earendil-works/pi-coding-agent@latest version 2>/dev/null | tail -n1)"
[[ -n "${LATEST_CODEX}" && -n "${LATEST_PI}" ]] || { echo "cannot reach the npm registry"; exit 1; }
echo "latest: codex ${LATEST_CODEX}, pi ${LATEST_PI}"

echo "== the image has no provider CLI"
docker exec "${C}" sh -c 'command -v pi' >/dev/null && fail "pi is in the image" || pass "no pi in the image"

echo "== default [pi]: Pi installed at its latest version and enabled"
run_hook '["pi"]'
hook_rc_ok && pass "hook exits 0" || fail "hook exit"
installed pi && pass "pi installed into /data/agents" || fail "pi not installed"
stamp_has "pi=@earendil-works/pi-coding-agent@${LATEST_PI}" && pass "pi stamped at ${LATEST_PI}" || fail "pi not stamped at latest"
expect_enabled pi=true claude=false codex=false copilot=false opencode=false omp=false muse=false antigravity=false
log_has "Providers: pi ${LATEST_PI}" && pass "summary line names pi ${LATEST_PI}" || fail "no summary line"
docker exec "${C}" test -e /data/agents/bin && fail "a provider directory exists without a vendor provider selected" || pass "no vendor provider directory without a selection"
log_has 'Installing provider (muse|antigravity)' && fail "a vendor installer ran without a selection" || pass "no vendor installer without a selection"

echo "== [codex]: codex installed; Pi uninstalled like any other provider"
run_hook '["codex"]'
installed codex && pass "codex installed" || fail "codex not installed"
installed pi && fail "pi still installed" || pass "pi uninstalled"
expect_enabled codex=true pi=false

echo "== same selection and same latest: no npm install"
run_hook '["codex"]'
if log_has 'Installing provider'; then fail "second run reinstalled"; else pass "no reinstall"; fi
log_has "Providers: codex ${LATEST_CODEX}" && pass "summary names codex ${LATEST_CODEX}" || fail "no summary line"

echo "== a different release on the latest tag is installed"
run_hook '["codex"]' "PASEO_HA_TEST_LATEST=@openai/codex=${OLD_CODEX}"
stamp_has "codex=@openai/codex@${OLD_CODEX}" && pass "codex moved to ${OLD_CODEX}" || fail "codex not moved to ${OLD_CODEX}"
run_hook '["codex"]'
stamp_has "codex=@openai/codex@${LATEST_CODEX}" && pass "codex upgraded to ${LATEST_CODEX}" || fail "codex not upgraded"
[[ "$(cli_version codex)" == *"${LATEST_CODEX}"* ]] && pass "codex --version reports ${LATEST_CODEX}" || fail "codex reports $(cli_version codex)"

echo "== a stamp written by the previous release (no trailing newline) is reused"
docker exec "${C}" sh -c "printf 'codex=@openai/codex@${LATEST_CODEX}' > ${STAMP}"
run_hook '["codex"]'
if log_has 'Installing provider codex'; then fail "old stamp not reused"; else pass "old stamp reused"; fi

echo "== prerelease on the latest tag is ignored"
run_hook '["codex"]' "PASEO_HA_TEST_LATEST=@openai/codex=9.9.9-alpha.1"
log_has 'not a stable release' && pass "prerelease warned" || fail "no prerelease warning"
stamp_has "codex=@openai/codex@${LATEST_CODEX}" && pass "installed codex kept" || fail "installed codex changed"
expect_enabled codex=true

echo "== registry unreachable: installed provider kept, missing one disabled"
run_hook '["codex","claude"]' PASEO_HA_TEST_OFFLINE=1
hook_rc_ok && pass "hook exits 0 offline" || fail "hook exit"
expect_enabled codex=true claude=false
installed claude && fail "claude installed offline" || pass "claude not installed"
log_has 'Could not check for a newer codex' && pass "skipped check logged" || fail "no skipped-check line"
log_has 'npm registry could not be reached' && pass "missing claude explained" || fail "no claude error"
log_has 'update check skipped for claude codex' && pass "summary notes skipped checks" || fail "summary does not note skipped checks"

echo "== broken upgrade rolls back and is not retried"
run_hook '["codex"]' "PASEO_HA_TEST_LATEST=@openai/codex=${OLD_CODEX}" "PASEO_HA_TEST_FAIL_SPEC=@openai/codex@${OLD_CODEX}"
log_has 'rolling back' && pass "rollback logged" || fail "no rollback"
stamp_has "codex=@openai/codex@${LATEST_CODEX}" && pass "previous codex restored" || fail "previous codex not restored"
docker exec "${C}" grep -qxF "codex=@openai/codex@${OLD_CODEX}" "${FAILED}" && pass "failed version recorded" || fail "failed version not recorded"
expect_enabled codex=true
run_hook '["codex"]' "PASEO_HA_TEST_LATEST=@openai/codex=${OLD_CODEX}"
log_has "Skipping codex @openai/codex@${OLD_CODEX}" && pass "failed version skipped" || fail "failed version retried"
if log_has 'Installing provider codex'; then fail "failed version downloaded again"; else pass "no download"; fi
run_hook '["codex"]' PASEO_HA_TEST_OFFLINE=1
docker exec "${C}" grep -qxF "codex=@openai/codex@${OLD_CODEX}" "${FAILED}" && pass "failed record survives an offline start" || fail "failed record lost offline"
run_hook '["codex"]' "PASEO_HA_TEST_LATEST=@openai/codex=${OTHER_CODEX}"
stamp_has "codex=@openai/codex@${OTHER_CODEX}" && pass "a later release is installed" || fail "later release not installed"
docker exec "${C}" grep -q '^codex=' "${FAILED}" && fail "failed record not cleared" || pass "failed record cleared"
run_hook '["codex"]'

echo "== [] : uninstalled, all eight disabled, home dir kept"
docker exec "${C}" mkdir -p /data/home/.codex
docker exec "${C}" sh -c 'echo keep > /data/home/.codex/auth.json'
run_hook '[]'
installed codex && fail "codex still installed" || pass "codex uninstalled"
expect_enabled pi=false claude=false codex=false copilot=false opencode=false omp=false muse=false antigravity=false
docker exec "${C}" test -f /data/home/.codex/auth.json && pass "credentials kept" || fail "credentials removed"
hook_rc_ok && pass "hook exits 0 with no providers" || fail "hook exit"

echo "== forced install failure: disabled, logged, retried next start"
run_hook '["pi","claude"]' PASEO_HA_TEST_FAIL_INSTALL=claude
hook_rc_ok && pass "hook exits 0 despite failure" || fail "hook exit"
log_has 'ERROR.*claude' && pass "failure logged" || fail "failure not logged"
expect_enabled claude=false pi=true
run_hook '["pi","claude"]'
installed claude && pass "claude installed on retry" || fail "claude not retried"
expect_enabled claude=true pi=true

echo "== an install that runs past its time cap counts as a failure"
run_hook '["pi","opencode"]' PASEO_HA_PROVIDER_INSTALL_TIMEOUT=1
hook_rc_ok && pass "hook exits 0 after a timed-out install" || fail "hook exit"
log_has 'ERROR.*opencode' && pass "timed-out install logged" || fail "timed-out install not logged"
expect_enabled opencode=false pi=true
run_hook '["pi","claude"]'

echo "== hand-enabled provider is reset; other overrides kept"
docker exec "${C}" bash -c 'PASEO_HOME=/data/home/.paseo; paseo daemon config set agents.providers "{\"codex\":{\"enabled\":true,\"label\":\"Mine\"},\"pi\":{\"enabled\":true}}" --home $PASEO_HOME >/dev/null'
run_hook '["pi","claude"]'
expect_enabled codex=false pi=true claude=true
[[ "$(docker exec "${C}" jq -r '.agents.providers.codex.label' /data/home/.paseo/config.json)" == "Mine" ]] && pass "codex label override kept" || fail "label override lost"

echo "== a stamped CLI that stopped working is reinstalled"
docker exec "${C}" sh -c 'rm -f /data/agents/node_modules/.bin/claude; ln -s /nonexistent /data/agents/node_modules/.bin/claude'
run_hook '["pi","claude"]'
log_has 'Installing provider claude' && pass "broken claude reinstalled" || fail "broken claude not reinstalled"
expect_enabled claude=true

echo "== failed uninstall stays in the stamp and is retried"
# make `npm uninstall` fail by shadowing npm on PATH for one run
docker exec -e PROV='["pi"]' "${C}" bash -c '
  mkdir -p /tmp/fakebin; real="$(command -v npm)"
  printf "#!/bin/sh
[ \"$1\" = uninstall ] && exit 1
exec %s \"$@\"
" "$real" > /tmp/fakebin/npm; chmod +x /tmp/fakebin/npm
  echo "{\"providers\":${PROV}}" > /data/options.json
  export PASEO_HOME=/data/home/.paseo PATH=/tmp/fakebin:$PATH
  bash -c "source /usr/local/lib/paseo-ha/common.sh; source /h/20-providers.sh" > /tmp/hook.log 2>&1; echo "rc=$?" >> /tmp/hook.log'
log_has 'Failed to uninstall provider claude' && pass "failed uninstall logged" || fail "no uninstall failure logged"
docker exec "${C}" grep -q '^claude=' "${STAMP}" && pass "failed removal kept in the stamp" || fail "failed removal dropped from the stamp"
expect_enabled claude=false
run_hook '["pi"]'
log_has 'Removing provider claude' && pass "removal retried" || fail "removal not retried"
installed claude && fail "claude still installed" || pass "claude removed on retry"
docker exec "${C}" grep -q '^claude=' "${STAMP}" && fail "stamp still lists claude" || pass "stamp cleared after successful removal"

echo "== unreadable provider config is not overwritten"
docker exec "${C}" bash -c 'PASEO_HOME=/data/home/.paseo; paseo daemon config set agents.providers "{\"codex\":{\"enabled\":false,\"label\":\"Keep\"}}" --home $PASEO_HOME >/dev/null; cp $PASEO_HOME/config.json /tmp/config.before'
docker exec "${C}" bash -c 'export PASEO_HOME=/data/home/.paseo; echo "{\"providers\":[\"pi\"]}" > /data/options.json
  mkdir -p /tmp/badbin; printf "#!/bin/sh
[ \"$2\" = config ] && [ \"$3\" = get ] && { echo not-json; exit 1; }
exec %s \"$@\"
" "$(command -v paseo)" > /tmp/badbin/paseo; chmod +x /tmp/badbin/paseo
  PATH=/tmp/badbin:$PATH bash -c "source /usr/local/lib/paseo-ha/common.sh; source /h/20-providers.sh" > /tmp/hook.log 2>&1; echo "rc=$?" >> /tmp/hook.log'
log_has "Could not read Paseo's provider settings" && pass "read failure warned" || fail "no read-failure warning"
docker exec "${C}" cmp -s /tmp/config.before /data/home/.paseo/config.json && pass "provider config left untouched" || fail "provider config was rewritten"
hook_rc_ok && pass "hook exits 0" || fail "hook exit"

echo "== unknown provider ignored"
run_hook '["pi","nope"]'
log_has "Unknown provider 'nope'" && pass "unknown value warned" || fail "no warning"
hook_rc_ok && pass "hook exits 0" || fail "hook exit"

# --- Script providers (Muse Code, Antigravity) --------------------------------
# Neither is on npm, so the hook runs the vendor's installer. A stub installer is
# written into the container and handed over through PASEO_HA_TEST_SCRIPT_URL, so
# no test downloads the real thing (Muse Code alone is ~336 MB). The stub installs
# into the directory the hook passes - it takes the binary name from that
# directory's own name - and leaves a second file behind so deselection can be
# checked to remove the whole directory.
echo "== vendor-installed providers: a stub installer through the test seam"
docker exec -i "${C}" sh -c 'cat > /tmp/stub-install.sh' <<'STUB'
#!/bin/sh
# Stub vendor installer: writes a fake muse/agy into the directory the hook chose.
dir="${MUSE_INSTALL_DIR:-}"
if [ -z "${dir}" ]; then
  while [ "$#" -gt 0 ]; do
    case "$1" in --dir) dir="$2"; shift 2 ;; *) shift ;; esac
  done
fi
[ -n "${dir}" ] || { echo "stub: no install directory" >&2; exit 2; }
case "$(basename "${dir}")" in
  muse) bin=muse; ver="Muse Code 1.4.4 (1.4.4-R5419.1)" ;;
  *)    bin=agy;  ver=1.3.2 ;;
esac
printf '#!/bin/sh\necho "%s"\n' "${ver}" > "${dir}/${bin}"
chmod +x "${dir}/${bin}"
touch "${dir}/.stub-extra"
echo "stub installer: ${bin} ${ver} into ${dir}"
STUB
STUB_URL=/tmp/stub-install.sh

run_hook '["muse","antigravity"]' "PASEO_HA_TEST_SCRIPT_URL=${STUB_URL}"
hook_rc_ok && pass "hook exits 0 with script providers" || fail "hook exit"
script_installed muse muse && pass "muse installed by the vendor installer" || fail "muse not installed"
script_installed antigravity agy && pass "agy installed by the vendor installer" || fail "agy not installed"
stamp_has "muse=muse@Muse Code 1.4.4 (1.4.4-R5419.1)" && pass "muse stamped at the whole version its CLI reports" || fail "muse not stamped"
stamp_has "antigravity=agy@1.3.2" && pass "antigravity stamped at the version its CLI reports" || fail "antigravity not stamped"
expect_enabled muse=true antigravity=true
log_has 'Providers: muse Muse Code 1.4.4 \(1\.4\.4-R5419\.1\),' && pass "summary names the whole muse version" || fail "no muse summary line"
docker exec "${C}" grep -q '/data/agents/bin/muse' /run/paseo-ha/daemon.env && pass "the provider directory is on the daemon PATH" || fail "provider directory not on PATH"
docker exec "${C}" test -e /data/agents/bin/muse/.stub-extra && pass "the installer's other files land in the provider directory" || fail "unexpected install layout"

echo "== a script provider whose CLI runs is never reinstalled"
run_hook '["muse","antigravity"]' "PASEO_HA_TEST_SCRIPT_URL=${STUB_URL}"
log_has 'Installing provider (muse|antigravity) from' && fail "a running script provider was reinstalled" || pass "no reinstall while the CLI runs"

echo "== a self-updated script provider keeps working, and its new version is recorded"
docker exec "${C}" sh -c 'printf "#!/bin/sh\necho 1.5.0\n" > /data/agents/bin/muse/muse'
run_hook '["muse"]' "PASEO_HA_TEST_SCRIPT_URL=${STUB_URL}"
stamp_has "muse=muse@1.5.0" && pass "the version the CLI now reports is stamped" || fail "self-updated version not recorded"
log_has 'Installing provider muse from' && fail "a self-updated provider was reinstalled" || pass "no install for a self-updated CLI"
expect_enabled muse=true antigravity=false

# Antigravity is deselected above, so the stamp only lists muse here.
echo "== deselection removes the provider directory and keeps the login"
docker exec "${C}" sh -c 'mkdir -p /data/home/.config/muse; echo token > /data/home/.config/muse/auth.json'
run_hook '["pi"]' "PASEO_HA_TEST_SCRIPT_URL=${STUB_URL}"
log_has 'Removing provider muse' && pass "removal logged" || fail "no removal log"
docker exec "${C}" test -e /data/agents/bin/muse && fail "muse directory kept" || pass "muse directory (and its extra files) removed"
docker exec "${C}" test -e /data/agents/bin/antigravity && fail "antigravity directory kept" || pass "antigravity directory removed"
docker exec "${C}" test -f /data/home/.config/muse/auth.json && pass "muse login kept" || fail "muse login removed"
expect_enabled muse=false antigravity=false

echo "== a failing script install: disabled, logged, retried next start"
run_hook '["muse"]' "PASEO_HA_TEST_SCRIPT_URL=${STUB_URL}" PASEO_HA_TEST_FAIL_INSTALL=muse
hook_rc_ok && pass "hook exits 0 after a failed script install" || fail "hook exit"
log_has 'ERROR.*muse' && pass "script install failure logged" || fail "failure not logged"
expect_enabled muse=false
docker exec "${C}" grep -q '^muse=' "${STAMP}" && fail "failed script provider was stamped" || pass "failed script provider not stamped"
docker exec "${C}" test -e /data/agents/bin/muse && fail "failed install left a directory behind" || pass "failed install left nothing behind"
run_hook '["muse"]' "PASEO_HA_TEST_SCRIPT_URL=${STUB_URL}"
script_installed muse muse && pass "script install retried on the next start" || fail "script install not retried"
expect_enabled muse=true

# The installer can also "succeed" and leave a CLI that does not run: the hook must
# treat that as a failure, not as an installed provider.
echo "== a CLI that does not run counts as a failed install"
docker exec -i "${C}" sh -c 'cat > /tmp/bad-install.sh' <<'BADSTUB'
#!/bin/sh
dir="${MUSE_INSTALL_DIR:-}"
[ -n "${dir}" ] || exit 2
printf '#!/bin/sh\nexit 1\n' > "${dir}/muse"
chmod +x "${dir}/muse"
BADSTUB
# The previous start left a working muse behind; remove it so the bad installer runs.
docker exec "${C}" rm -rf /data/agents/bin/muse
run_hook '["muse"]' "PASEO_HA_TEST_SCRIPT_URL=/tmp/bad-install.sh"
hook_rc_ok && pass "hook exits 0 when the vendor CLI does not run" || fail "hook exit"
log_has 'ERROR.*muse' && pass "a CLI that does not run is logged" || fail "no error for a CLI that does not run"
expect_enabled muse=false
docker exec "${C}" grep -q '^muse=' "${STAMP}" && fail "a CLI that does not run was stamped" || pass "a CLI that does not run is not stamped"
docker exec "${C}" test -e /data/agents/bin/muse && fail "a broken half-install was kept" || pass "a broken half-install is removed"

# A vendor's post-install step can fail after the CLI is in place. What matters is
# that the CLI runs; otherwise the provider would be reinstalled on every start.
echo "== an installer that exits non-zero but leaves a working CLI is accepted"
docker exec -i "${C}" sh -c 'cat > /tmp/noisy-install.sh' <<'NOISY'
#!/bin/sh
dir="${MUSE_INSTALL_DIR:-}"
[ -n "${dir}" ] || exit 2
printf '#!/bin/sh\necho 9.9.9\n' > "${dir}/muse"
chmod +x "${dir}/muse"
echo "post-install step failed"
exit 3
NOISY
docker exec "${C}" rm -rf /data/agents/bin/muse
run_hook '["muse"]' "PASEO_HA_TEST_SCRIPT_URL=/tmp/noisy-install.sh"
hook_rc_ok && pass "hook exits 0" || fail "hook exit"
expect_enabled muse=true
stamp_has "muse=muse@9.9.9" && pass "the working CLI's version is stamped" || fail "not stamped"
run_hook '["muse"]' "PASEO_HA_TEST_SCRIPT_URL=/tmp/noisy-install.sh"
log_has 'Installing provider muse from' && fail "a working CLI was reinstalled" || pass "no reinstall loop"
run_hook '["pi"]'

echo
if [[ "${fails}" -ne 0 ]]; then echo "providers test: ${fails} failure(s)"; docker exec "${C}" cat /tmp/hook.log 2>/dev/null | tail -20; exit 1; fi
echo "providers test passed"
