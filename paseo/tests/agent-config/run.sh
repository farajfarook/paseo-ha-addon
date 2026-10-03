#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329  # commands are expanded inside the container; cleanup runs via trap
# ==============================================================================
# Integration test for the agent-config and HA-integration hooks (tasks 4a/4b).
# Runs the add-on image against a mock Supervisor (see mock-supervisor.js) and
# checks seeding, skill links, generated instructions, MCP merge, bootstrap and
# git_snapshot behaviour. No real Home Assistant is needed.
#
#   paseo/tests/agent-config/run.sh [image]          (default image: paseo-ha-test)
#
# Optional: AGENTS_DIR=<host dir with node_modules from
#   npm install --prefix <dir> @anthropic-ai/claude-code @openai/codex opencode-ai>
# to also check the Claude Code/Codex/OpenCode MCP entries.
# Section 8 covers the default Pi packages (36-pi-packages.sh) against a mock npm registry
# (mock-registry.js + fixtures/), so it needs no network.
# Uses names prefixed with $PREFIX (default: agentcfg-test) and cleans up after itself.
# ==============================================================================
set -uo pipefail
export MSYS_NO_PATHCONV=1

IMAGE="${1:-paseo-ha-test}"
PREFIX="${PREFIX:-agentcfg-test}"
HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/${PREFIX}.XXXXXX")"
NET="${PREFIX}-net"
APP="${PREFIX}-app"
SUP="${PREFIX}-sup"
REG="${PREFIX}-reg"
TOKEN="test-supervisor-token"
SECRET="s3cr3t-value-$$"
fails=0

hostpath() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else echo "$1"; fi; }
pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*"; fails=$((fails + 1)); if [[ -n "${DEBUG:-}" ]]; then last_start_log | grep -i -E 'pi package|pi-package|WARN|ERROR' | tail -n 12 | sed 's/^/    | /'; docker exec "${APP}" bash -c 'cat /data/paseo-ha/pi-packages.offered 2>&1; pi list 2>&1' | sed 's/^/    > /'; fi; }
check() { local desc="$1"; shift; if "$@" >/dev/null 2>&1; then pass "${desc}"; else fail "${desc}"; fi; }
in_app() { docker exec "${APP}" bash -c "source /run/paseo-ha/daemon.env; $1"; }

cleanup() {
  docker rm -f "${APP}" "${SUP}" "${REG}" >/dev/null 2>&1
  docker network rm "${NET}" >/dev/null 2>&1
  docker run --rm -v "$(hostpath "${WORK}"):/w" --entrypoint sh "${IMAGE}" -c 'rm -rf /w/*' >/dev/null 2>&1
  rm -rf "${WORK}"
}
trap cleanup EXIT

options() { # options <git_snapshot> <workspace>
  cat > "${WORK}/data/options.json" <<EOF
{"workspace":"$2","git_snapshot":$1,"agents":[],"env_vars":[{"name":"MY_SECRET","value":"${SECRET}"}],
 "hostnames":[],"log_level":"info","dictation":false,"voice_mode":false,"speech_provider":"local"}
EOF
}

start_sup() { # start_sup <200|404>
  docker rm -f "${SUP}" >/dev/null 2>&1
  docker run -d --name "${SUP}" --network "${NET}" --network-alias supervisor \
    -e MOCK_MCP="$1" -e MOCK_TOKEN="${TOKEN}" -v "$(hostpath "${HERE}"):/t" \
    --entrypoint node "${IMAGE}" /t/mock-supervisor.js >/dev/null
}

start_app() {
  docker rm -f "${APP}" >/dev/null 2>&1
  local extra=()
  [[ -n "${AGENTS_DIR:-}" ]] && extra=(-v "$(hostpath "${AGENTS_DIR}"):/data/agents")
  docker run -d --name "${APP}" --network "${NET}" -e SUPERVISOR_TOKEN="${TOKEN}" \
    -v "$(hostpath "${WORK}/data"):/data" -v "$(hostpath "${WORK}/ha"):/homeassistant" \
    -v "$(hostpath "${WORK}/config"):/config" -v "$(hostpath "${WORK}/share"):/share" \
    -v "$(hostpath "${WORK}/pidef"):/pidef" -e PASEO_HA_PI_DEFAULTS=/pidef/list -e npm_config_registry=http://registry \
    "${extra[@]}" "${IMAGE}" >/dev/null
  wait_ready
}

# Log lines of the most recent container start only.
last_start_log() { docker logs "${APP}" 2>&1 | awk '/service init-paseo: starting/{buf=""} {buf=buf $0 "\n"} END{printf "%s", buf}'; }
starts() { docker logs "${APP}" 2>&1 | grep -c 'service init-paseo: starting'; }
restart_app() {
  local before
  before="$(starts)"
  docker restart "${APP}" >/dev/null
  wait_ready "${before}"
}

wait_ready() { # [previous start count] -> until a new start's bootstrap oneshot has finished
  local before="${1:-0}"
  # docker logs keeps earlier runs: the last of these two lines must be the bootstrap one.
  # (No grep -q directly on docker logs: with pipefail an early exit fails the pipeline.)
  for _ in $(seq 1 90); do
    if [[ "$(starts)" -gt "${before}" ]] &&
      [[ "$(docker logs "${APP}" 2>&1 | grep -E 'service (init-paseo: starting|paseo-ha-bootstrap successfully started)' | tail -n 1)" == *bootstrap* ]]; then
      return 0
    fi
    sleep 1
  done
  echo "app did not become ready"; docker logs "${APP}" 2>&1 | grep -E '^(s6-rc|\[paseo-ha\]|\[[0-9:]+\] )' | tail -30; exit 1
}

mkdir -p "${WORK}"/{data,ha,config,share,pidef,registry}
: > "${WORK}/pidef/list"
printf 'homeassistant:\n  name: Test\nautomation: !include automations.yaml\n' > "${WORK}/ha/configuration.yaml"
echo '[]' > "${WORK}/ha/automations.yaml"
echo 'pw: hunter2-secret' > "${WORK}/ha/secrets.yaml"
mkdir -p "${WORK}/ha/.storage" && echo '{}' > "${WORK}/ha/.storage/core.config"
touch "${WORK}/ha/home-assistant_v2.db"
docker network create "${NET}" >/dev/null

# Mock npm registry for the Pi-package scenarios: pack the fixtures with the image's npm.
pack_fixture() { # pack_fixture <name> [version]  -> registry/<name>-<version>.tgz
  local name="$1" version="${2:-1.0.0}"
  docker run --rm -v "$(hostpath "${HERE}/fixtures"):/f:ro" -v "$(hostpath "${WORK}/registry"):/r" --entrypoint sh "${IMAGE}" -c     "rm -rf /tmp/p && cp -r /f/${name} /tmp/p && sed -i 's/\"version\": \"1.0.0\"/\"version\": \"${version}\"/' /tmp/p/package.json && cd /tmp/p && npm pack --pack-destination /r >/dev/null"
}
for n in a b c d f; do pack_fixture "paseo-test-${n}"; done
pack_fixture paseo-test-a 1.1.0
docker run -d --name "${REG}" --network "${NET}" --network-alias registry -e REGISTRY_DIR=/registry   -v "$(hostpath "${WORK}/registry"):/registry" -v "$(hostpath "${HERE}"):/t" --entrypoint node "${IMAGE}" /t/mock-registry.js >/dev/null

# --- 1. First start: seeding, links, instructions, MCP (200), bootstrap -------
options false /homeassistant
start_sup 200
start_app

for f in AGENTS.md README.md skills claude/agents claude/commands opencode/agents opencode/plugins pi/extensions pi/prompts codex/prompts; do
  check "seeded /config/${f}" test -e "${WORK}/config/${f}"
done
check "dir link ~/.claude/agents" in_app '[ "$(readlink $CLAUDE_CONFIG_DIR/agents)" = /config/claude/agents ]'
check "dir link opencode/plugins" in_app '[ "$(readlink $XDG_CONFIG_HOME/opencode/plugins)" = /config/opencode/plugins ]'
check "dir link pi/extensions" in_app '[ "$(readlink $PI_CODING_AGENT_DIR/extensions)" = /config/pi/extensions ]'
check "dir link codex/prompts" in_app '[ "$(readlink $CODEX_HOME/prompts)" = /config/codex/prompts ]'
check "bundled skill linked (agents)" in_app '[ "$(readlink $HOME/.agents/skills/home-assistant)" = /opt/paseo-ha/skills/home-assistant ]'
check "bundled skill linked (claude)" in_app '[ "$(readlink $CLAUDE_CONFIG_DIR/skills/home-assistant)" = /opt/paseo-ha/skills/home-assistant ]'
check "HASS_SERVER/HASS_TOKEN in daemon env" in_app '[ "$HASS_SERVER" = http://supervisor/core ] && [ "$HASS_TOKEN" = "$SUPERVISOR_TOKEN" ]'
check "core API via mock supervisor" in_app 'curl -fs -H "Authorization: Bearer $SUPERVISOR_TOKEN" $HASS_SERVER/api/ | grep -q "API running."'
check "Pi MCP entry written" in_app 'jq -e ".mcpServers.homeassistant.url == \"http://supervisor/core/api/mcp\"" $PI_CODING_AGENT_DIR/mcp.json'
check "one 'Home Assistant' project" in_app '[ "$(paseo project ls --home $PASEO_HOME --json | jq "[.[] | select(.path==\"/homeassistant\" and .name==\"Home Assistant\")] | length")" = 1 ]'
check "no .git by default" test ! -e "${WORK}/ha/.git"
if [[ -n "${AGENTS_DIR:-}" ]]; then
  check "Claude MCP entry" in_app 'jq -e ".mcpServers.homeassistant.headers.Authorization == \"Bearer \${SUPERVISOR_TOKEN}\"" $CLAUDE_CONFIG_DIR/.claude.json'
  check "Codex MCP table" in_app 'grep -q "^bearer_token_env_var = \"SUPERVISOR_TOKEN\"" $CODEX_HOME/config.toml'
  check "OpenCode MCP entry" in_app 'jq -e ".mcp.homeassistant.type == \"remote\"" $XDG_CONFIG_HOME/opencode/opencode.json'
fi

# --- 2. User content: AGENTS.md edit, user skill, override, rename, other MCP --
echo "User sentence MARKER-4a4." >> "${WORK}/config/AGENTS.md"
sum_before="$(md5sum < "${WORK}/config/AGENTS.md")"
mkdir -p "${WORK}/config/skills/my-skill"
printf -- '---\nname: my-skill\ndescription: test\n---\n' > "${WORK}/config/skills/my-skill/SKILL.md"
cp -r "${HERE}/../../rootfs/opt/paseo-ha/skills/home-assistant" "${WORK}/config/skills/"
sed -i 's/^description: /description: USER-OVERRIDE /' "${WORK}/config/skills/home-assistant/SKILL.md"
in_app 'id=$(paseo project ls --home $PASEO_HOME --json | jq -r ".[0].projectId"); paseo project rename $id "My HA" --home $PASEO_HOME >/dev/null'
in_app 'jq ".mcpServers.other = {\"command\":\"echo\"} | .keep = 1" $PI_CODING_AGENT_DIR/mcp.json > /tmp/m && mv /tmp/m $PI_CODING_AGENT_DIR/mcp.json'
restart_app

check "edited AGENTS.md unchanged by restart" test "$(md5sum < "${WORK}/config/AGENTS.md")" = "${sum_before}"
for f in '$CLAUDE_CONFIG_DIR/CLAUDE.md' '$CODEX_HOME/AGENTS.md' '$XDG_CONFIG_HOME/opencode/AGENTS.md' '$PI_CODING_AGENT_DIR/AGENTS.md'; do
  check "generated ${f} has header + base + user text" in_app "grep -q GENERATED $f && grep -q 'home-assistant' $f && grep -q MARKER-4a4 $f"
done
check "user skill linked" in_app '[ "$(readlink $HOME/.agents/skills/my-skill)" = /config/skills/my-skill ]'
check "user override wins" in_app '[ "$(readlink $CLAUDE_CONFIG_DIR/skills/home-assistant)" = /config/skills/home-assistant ]'
check "manifest lists our links" in_app 'grep -qx $HOME/.agents/skills/my-skill /data/paseo-ha/skill-links.manifest'
check "Pi skill discovery lists user override" in_app 'cd /homeassistant; (echo "{\"type\":\"get_commands\",\"id\":\"1\"}"; sleep 5) | timeout 30 pi --mode rpc 2>/dev/null | head -1 | jq -e "[.data.commands[] | select(.name==\"skill:my-skill\" or (.name==\"skill:home-assistant\" and (.description | startswith(\"USER-OVERRIDE\"))))] | length == 2"'
check "rename kept, no duplicate" in_app '[ "$(paseo project ls --home $PASEO_HOME --json | jq -c "[.[] | select(.path==\"/homeassistant\") | .name]")" = "[\"My HA\"]" ]'
check "Pi MCP merge kept other content" in_app 'jq -e ".keep == 1 and .mcpServers.other.command == \"echo\" and .mcpServers.homeassistant != null" $PI_CODING_AGENT_DIR/mcp.json'

# --- 3. Paseo's own skill sync coexists with our links ------------------------
in_app 'node -e "
const b=\"/opt/node/lib/node_modules/@getpaseo/cli/node_modules/@getpaseo/server/dist/server/server/orchestration-skills/\";
import(b+\"index.js\").then(async m=>{const s=m.createOrchestrationSkills({get:()=>({}),setAgentSkillSelection(){}});await s.reconcile();});"' >/dev/null 2>&1
check "Paseo skills installed next to ours" in_app '[ -f $HOME/.agents/skills/paseo/SKILL.md ] && [ -L $HOME/.agents/skills/my-skill ]'
restart_app
check "after restart both Paseo skills and user links exist" in_app '[ -f $CLAUDE_CONFIG_DIR/skills/paseo/SKILL.md ] && [ -L $CLAUDE_CONFIG_DIR/skills/my-skill ]'

# --- 4. Cleanup of stale links, MCP 404 removes our entries --------------------
rm -rf "${WORK}/config/skills/my-skill" "${WORK}/config/skills/home-assistant"
start_sup 404
restart_app
check "stale user skill link removed" in_app '[ ! -e $HOME/.agents/skills/my-skill ] && [ ! -L $HOME/.agents/skills/my-skill ]'
check "bundled skill restored after override removed" in_app '[ "$(readlink $HOME/.agents/skills/home-assistant)" = /opt/paseo-ha/skills/home-assistant ]'
check "Paseo-managed skill untouched" in_app '[ -f $HOME/.agents/skills/paseo/SKILL.md ]'
check "MCP 404: one info line" test "$(last_start_log | grep -c "Model Context Protocol Server")" = 1
check "MCP 404: stale Pi entry removed, other kept" in_app 'jq -e ".mcpServers.homeassistant == null and .mcpServers.other.command == \"echo\"" $PI_CODING_AGENT_DIR/mcp.json'

# --- 5. Workspace project ------------------------------------------------------
options false /share/ws
restart_app
check "workspace project registered" in_app 'paseo project ls --home $PASEO_HOME --json | jq -e "[.[] | select(.path==\"/share/ws\")] | length == 1"'
check "HA project still single" in_app 'paseo project ls --home $PASEO_HOME --json | jq -e "[.[] | select(.path==\"/homeassistant\")] | length == 1"'

# --- 6. git_snapshot -----------------------------------------------------------
options true /homeassistant
restart_app
check "git repo created" test -d "${WORK}/ha/.git"
check "secrets/.storage/db ignored" in_app 'cd /homeassistant && [ -z "$(git ls-files secrets.yaml .storage home-assistant_v2.db)" ] && [ -z "$(git status --porcelain)" ]'
check "initial commit by Paseo Agent" in_app 'cd /homeassistant && git log -1 --format=%an | grep -qx "Paseo Agent"'
check "safe.directory set" in_app 'git config --global --get-all safe.directory | grep -qx /homeassistant'
in_app 'cd /homeassistant && cp automations.yaml /tmp/a && echo "- id: x" > automations.yaml && git commit -qam "Agent change" && git revert --no-edit HEAD >/dev/null'
check "git revert restores file" in_app 'cmp /homeassistant/automations.yaml /tmp/a'
head_before="$(in_app 'git -C /homeassistant rev-parse HEAD')"
echo "# user" >> "${WORK}/ha/.gitignore"
restart_app
check "existing repo left unchanged" test "$(in_app 'git -C /homeassistant rev-parse HEAD')" = "${head_before}"
check "existing .gitignore kept" grep -qx "# user" "${WORK}/ha/.gitignore"

# --- 8. Default Pi packages (36-pi-packages.sh) ---------------------------------
set_defaults() { printf 'npm:%s\n' "$@" > "${WORK}/pidef/list"; }   # one default per line
pi_list() { in_app 'pi list 2>/dev/null'; }
has_pkg() { local list; list="$(pi_list)"; grep -Eq "npm:$1(@| |$)" <<<"${list}"; }   # no pipe: grep -q + pipefail
no_pkg() { ! has_pkg "$1"; }
all_pkgs() { local p list; list="$(pi_list)"; for p in "$@"; do grep -Eq "npm:${p}(@| |$)" <<<"${list}" || return 1; done; }
in_ledger() { local p; for p in "$@"; do grep -qx "npm:${p}" "${WORK}/data/paseo-ha/pi-packages.offered" || return 1; done; }
not_in_ledger() { ! in_ledger "$1"; }
installed_version() { in_app "jq -r .version \$PI_CODING_AGENT_DIR/npm/node_modules/$1/package.json"; }
no_install_attempts() { [[ -z "$(last_start_log | grep -E 'Installing default Pi package|Could not install default')" ]]; }

set_defaults paseo-test-a@1.0.0 paseo-test-b@1.0.0
restart_app
check "defaults installed on first offer" all_pkgs paseo-test-a paseo-test-b
check "ledger records both defaults" in_ledger paseo-test-a paseo-test-b
check "start log lists Pi packages" test -n "$(last_start_log | grep 'Pi packages:.*paseo-test-a')"

restart_app
check "restart does not reinstall" no_install_attempts

in_app 'pi remove npm:paseo-test-b >/dev/null 2>&1; pi install npm:paseo-test-c >/dev/null 2>&1'
restart_app
check "removed default stays removed" no_pkg paseo-test-b
check "user-installed package persists" has_pkg paseo-test-c
check "remaining default kept" has_pkg paseo-test-a
check "no installs after user changes" no_install_attempts

set_defaults paseo-test-a@1.0.0 paseo-test-b@1.0.0 paseo-test-d@1.0.0
restart_app
check "new default is installed once" has_pkg paseo-test-d
check "removed default still absent after list grows" no_pkg paseo-test-b

set_defaults paseo-test-a@1.1.0 paseo-test-b@1.0.0 paseo-test-d@1.0.0
restart_app
check "version-only change does not reinstall" no_install_attempts
check "installed version unchanged" test "$(installed_version paseo-test-a)" = 1.0.0

in_app 'pi install npm:paseo-test-f >/dev/null 2>&1'
set_defaults paseo-test-a@1.1.0 paseo-test-b@1.0.0 paseo-test-d@1.0.0 paseo-test-f@1.0.0
restart_app
check "default the user already installed: no install run" no_install_attempts
check "...but it is recorded as offered" in_ledger paseo-test-f

# Image update = a new container on the same /data.
docker rm -f "${APP}" >/dev/null 2>&1
start_app
check "after container recreate: user + default packages kept" all_pkgs paseo-test-a paseo-test-c paseo-test-d paseo-test-f
check "after container recreate: removed default still absent" no_pkg paseo-test-b
check "after container recreate: nothing reinstalled" no_install_attempts

# A broken source warns, never blocks startup, and is retried until it works.
set_defaults paseo-test-a@1.1.0 paseo-test-e@1.0.0
restart_app
check "unavailable default: warning logged" test -n "$(last_start_log | grep 'Could not install default Pi package npm:paseo-test-e')"
check "unavailable default: not recorded" not_in_ledger paseo-test-e
check "unavailable default: daemon still healthy" in_app 'curl -fs http://127.0.0.1:6767/api/health'
pack_fixture paseo-test-e
restart_app
check "retried and installed once available" has_pkg paseo-test-e
check "...then recorded" in_ledger paseo-test-e

# --- 7. Secrets ----------------------------------------------------------------
check "no secrets/credentials in /config" in_app '! grep -rq -e "'"${SECRET}"'" -e "'"${TOKEN}"'" /config && [ -z "$(find /config \( -name "*.json" -o -name "*auth*" -o -name "*key*" -o -name "*session*" \) -print)" ]'
check "no secret values in agent configs" in_app '! grep -rqs -e "'"${TOKEN}"'" $CLAUDE_CONFIG_DIR/.claude.json $CODEX_HOME/config.toml $XDG_CONFIG_HOME/opencode/opencode.json $PI_CODING_AGENT_DIR/mcp.json'
check "no secret values in add-on log" test "$(docker logs "${APP}" 2>&1 | grep -c -e "${SECRET}" -e "${TOKEN}")" = 0

echo
if [[ "${fails}" -eq 0 ]]; then echo "ALL PASSED"; else echo "${fails} FAILED"; fi
exit $(( fails > 0 ))
