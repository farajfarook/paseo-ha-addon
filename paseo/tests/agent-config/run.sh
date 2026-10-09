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
GIT="${PREFIX}-git"
GIT_IMAGE="${GIT_IMAGE:-alpine:3.22}"
TOKEN="test-supervisor-token"
SECRET="s3cr3t-value-$$"
fails=0

hostpath() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else echo "$1"; fi; }
pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*"; fails=$((fails + 1)); if [[ -n "${DEBUG:-}" ]]; then last_start_log | grep -i -E 'pi package|pi-package|WARN|ERROR' | tail -n 12 | sed 's/^/    | /'; docker exec "${APP}" bash -c 'cat /data/paseo-ha/pi-packages.offered 2>&1; pi list 2>&1' | sed 's/^/    > /'; fi; }
check() { local desc="$1"; shift; if "$@" >/dev/null 2>&1; then pass "${desc}"; else fail "${desc}"; fi; }
in_app() { docker exec "${APP}" bash -c "source /run/paseo-ha/daemon.env; $1"; }

cleanup() {
  docker rm -f "${APP}" "${SUP}" "${REG}" "${GIT}" >/dev/null 2>&1
  docker network rm "${NET}" >/dev/null 2>&1
  docker run --rm -v "$(hostpath "${WORK}"):/w" --entrypoint sh "${IMAGE}" -c 'rm -rf /w/*' >/dev/null 2>&1
  rm -rf "${WORK}"
}
trap cleanup EXIT

options() { # options <git_snapshot> <workspace>
  cat > "${WORK}/data/options.json" <<EOF
{"workspace":"$2","git_snapshot":$1,"providers":["pi"],"env_vars":[{"name":"MY_SECRET","value":"${SECRET}"}],
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
  [[ -n "${PI_BUDGET:-}" ]] && extra+=(-e "PASEO_HA_PI_BUDGET=${PI_BUDGET}")   # test seam for the install time budget
  [[ -n "${AGENTS_DIR:-}" ]] && extra+=(-v "$(hostpath "${AGENTS_DIR}"):/data/agents")
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
for n in a b c d f g; do pack_fixture "paseo-test-${n}"; done
pack_fixture paseo-test-a 1.1.0
docker run -d --name "${REG}" --network "${NET}" --network-alias registry -e REGISTRY_DIR=/registry   -v "$(hostpath "${WORK}/registry"):/registry" -v "$(hostpath "${HERE}"):/t" --entrypoint node "${IMAGE}" /t/mock-registry.js >/dev/null

# Pi is installed at runtime by 20-providers, but the app container uses the mock
# registry. Seed /data/agents with Pi from the real registry first; the hook's own
# lookup then fails against the mock and keeps the installed version.
seed_pi() { # seed_pi <host agents dir>
  docker run --rm -v "$(hostpath "$1"):/a" --entrypoint sh "${IMAGE}" -c '
    set -e; [ -f /a/package.json ] || echo "{\"name\":\"paseo-ha-agents\",\"private\":true}" > /a/package.json
    v="$(npm view @earendil-works/pi-coding-agent@latest version)"
    npm install --prefix /a --no-audit --no-fund --omit=dev "@earendil-works/pi-coding-agent@${v}" >/dev/null
    { grep -v "^pi=" /a/.paseo-ha-providers.stamp 2>/dev/null || true; printf "pi=@earendil-works/pi-coding-agent@%s" "${v}"; } > /tmp/stamp
    mv /tmp/stamp /a/.paseo-ha-providers.stamp' || { echo "cannot seed Pi (needs network)"; exit 1; }
}
mkdir -p "${WORK}/data/agents"
seed_pi "${AGENTS_DIR:-${WORK}/data/agents}"

# --- 1. First start: seeding, links, instructions, MCP (200), bootstrap -------
options false /homeassistant
start_sup 200
start_app
check "Pi kept with the registry unreachable" test -n "$(last_start_log | grep 'Could not check for a newer pi')"
check "Pi enabled" in_app 'jq -e ".agents.providers.pi.enabled == true" $PASEO_HOME/config.json'

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
mkdir -p "${WORK}/ha/.ssh"
echo "FAKE-PRIVATE-KEY" > "${WORK}/ha/.ssh/id_ed25519"
echo "ssh-ed25519 AAAA fake" > "${WORK}/ha/.ssh/id_ed25519.pub"
echo "FAKE-PRIVATE-KEY" > "${WORK}/ha/deploy.pem"
options true /homeassistant
restart_app
check "git repo created" test -d "${WORK}/ha/.git"
check "SSH keys not in initial snapshot" in_app 'cd /homeassistant && [ -z "$(git ls-files .ssh deploy.pem)" ]'
check "generated .gitignore has SSH rules" grep -qx ".ssh/" "${WORK}/ha/.gitignore"
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

# An add-on .gitignore from before the SSH rules gets them appended once.
cp "${WORK}/ha/.gitignore" "${WORK}/gitignore.saved"
printf '%s\nsecrets.yaml\n.storage/\n' "# Written by the Paseo add-on (git_snapshot). Secrets and runtime state stay out of git." > "${WORK}/ha/.gitignore"
restart_app
restart_app
check "old add-on .gitignore: SSH rules appended once" test "$(grep -cx '.ssh/' "${WORK}/ha/.gitignore")" = 1
check "old add-on .gitignore: earlier lines kept" grep -qx ".storage/" "${WORK}/ha/.gitignore"
check "history unchanged by .gitignore update" test "$(in_app 'git -C /homeassistant rev-parse HEAD')" = "${head_before}"

# A user .gitignore is never changed; tracked keys only produce a warning.
printf '# user ignore\nsecrets.yaml\n.storage/\n*.db\n' > "${WORK}/ha/.gitignore"
in_app 'cd /homeassistant && git add -f .ssh/id_ed25519 && git commit -qm "track a key"'
head_key="$(in_app 'git -C /homeassistant rev-parse HEAD')"
sum_before="$(md5sum < "${WORK}/ha/.gitignore")"
restart_app
check "user .gitignore unchanged" test "$(md5sum < "${WORK}/ha/.gitignore")" = "${sum_before}"
check "tracked key warning logged" grep -q 'SSH key file(s) are tracked in /homeassistant: .ssh/id_ed25519' <<<"$(last_start_log)"
# The log goes through a file: passed as one argument it can exceed the kernel's 128 KB
# single-argument limit (Paseo 0.11 logs every bundled plugin on each start), and a
# failed `docker logs` must fail the check instead of looking like a clean log.
check "no key material in log" bash -c 'docker logs "$1" > "$2" 2>&1 && ! grep -q FAKE-PRIVATE-KEY "$2"' _ "${APP}" "${WORK}/app.log"
check "repo untouched by warning" test "$(in_app 'git -C /homeassistant rev-parse HEAD')" = "${head_key}"
in_app 'cd /homeassistant && git rm -q --cached .ssh/id_ed25519 && git commit -qm "untrack key"'
cp "${WORK}/gitignore.saved" "${WORK}/ha/.gitignore"

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

# The shared time budget stops installs and defers the rest to the next start.
set_defaults paseo-test-a@1.1.0 paseo-test-e@1.0.0 paseo-test-g@1.0.0
docker rm -f "${APP}" >/dev/null 2>&1
PI_BUDGET=0 start_app
check "budget used up: warning names the deferral" test -n "$(last_start_log | grep 'time budget')"
check "budget used up: daemon still healthy" in_app 'curl -fs http://127.0.0.1:6767/api/health'
check "budget used up: deferred default not recorded" not_in_ledger paseo-test-g
docker rm -f "${APP}" >/dev/null 2>&1
PI_BUDGET= start_app
check "next start installs the deferred default" has_pkg paseo-test-g
check "...and records it" in_ledger paseo-test-g

# Without Pi on PATH the step is skipped and records nothing, not even a default the
# user already installed (paseo-test-c), so it is offered once Pi is back.
set_defaults paseo-test-c@1.0.0
check "no Pi: default packages step skipped" in_app 'export PATH=/opt/node/bin:/usr/sbin:/usr/bin:/sbin:/bin; ! command -v pi >/dev/null && (source /usr/local/lib/paseo-ha/common.sh; source /etc/paseo-ha/init.d/36-pi-packages.sh) 2>&1 | grep -q "Pi is not installed; skipping"'
check "no Pi: nothing recorded as offered" not_in_ledger paseo-test-c
restart_app
check "Pi back: the default is recorded" in_ledger paseo-test-c

# --- 7. Secrets ----------------------------------------------------------------
check "no secrets/credentials in /config" in_app '! grep -rq -e "'"${SECRET}"'" -e "'"${TOKEN}"'" /config && [ -z "$(find /config \( -name "*.json" -o -name "*auth*" -o -name "*key*" -o -name "*session*" \) -print)" ]'
check "no secret values in agent configs" in_app '! grep -rqs -e "'"${TOKEN}"'" $CLAUDE_CONFIG_DIR/.claude.json $CODEX_HOME/config.toml $XDG_CONFIG_HOME/opencode/opencode.json $PI_CODING_AGENT_DIR/mcp.json'
check "no secret values in add-on log" test "$(docker logs "${APP}" 2>&1 | grep -c -e "${SECRET}" -e "${TOKEN}")" = 0

# --- 8. Speech guard (task 10.1) -----------------------------------------------
# The local engine cannot load on the Alpine image, so dictation/voice must be forced
# off (no model download). With speech_provider openai nothing is guarded.
# speech_options <speech_provider> <dictation true|false> <voice_mode true|false>
# (sed on a known options shape: the host may not have jq)
speech_options() {
  sed -i -e "s/\"dictation\":[a-z]*/\"dictation\":$2/" -e "s/\"voice_mode\":[a-z]*/\"voice_mode\":$3/" \
    -e "s/\"speech_provider\":\"[a-z]*\"/\"speech_provider\":\"$1\"/" "${WORK}/data/options.json"
}
# One flag on at a time: the guard must force that flag off (a regression could cover just one).
speech_options local true false
restart_app
check "local speech, dictation only: dictation forced off" in_app '[ "$PASEO_DICTATION_ENABLED" = false ]'
check "local speech, dictation only: voice mode stays off" in_app '[ "$PASEO_VOICE_MODE_ENABLED" = false ]'
check "local speech, dictation only: warning logged" test "$(last_start_log | grep -c "no speech models are downloaded")" -ge 1
speech_options local false true
restart_app
check "local speech, voice only: voice mode forced off" in_app '[ "$PASEO_VOICE_MODE_ENABLED" = false ]'
check "local speech, voice only: dictation stays off" in_app '[ "$PASEO_DICTATION_ENABLED" = false ]'
check "local speech, voice only: warning logged" test "$(last_start_log | grep -c "no speech models are downloaded")" -ge 1
speech_options local true true
restart_app
check "local speech unavailable: dictation forced off" in_app '[ "$PASEO_DICTATION_ENABLED" = false ]'
check "local speech unavailable: voice mode forced off" in_app '[ "$PASEO_VOICE_MODE_ENABLED" = false ]'
check "local speech unavailable: warning names the fix" test "$(last_start_log | grep -c "no speech models are downloaded")" -ge 1
check "local speech unavailable: no models directory" in_app '[ ! -e "$PASEO_HOME/models/local-speech" ]'
speech_options openai true true
restart_app
check "openai speech: dictation stays on" in_app '[ "$PASEO_DICTATION_ENABLED" = true ]'
check "openai speech: voice mode stays on" in_app '[ "$PASEO_VOICE_MODE_ENABLED" = true ]'
check "openai speech: no unavailable warning" test "$(last_start_log | grep -c "cannot load on this platform")" = 0
check "openai speech: no models directory" in_app '[ ! -e "$PASEO_HOME/models/local-speech" ]'

# --- 9. Git access (47-git-auth.sh) --------------------------------------------
# A throwaway git-over-ssh server (alpine + openssh + git) on the test network.
start_git_server() { # start_git_server -> fresh host key each time
  docker rm -f "${GIT}" >/dev/null 2>&1
  docker run -d --name "${GIT}" --network "${NET}" --network-alias gitsrv \
    -v "$(hostpath "${WORK}/gitsrv"):/srv" --entrypoint sh "${GIT_IMAGE}" -c '
      apk add -q --no-cache openssh-server git >/dev/null &&
      ssh-keygen -A >/dev/null &&
      adduser -D -s /usr/bin/git-shell git && passwd -u git >/dev/null 2>&1;
      mkdir -p /home/git/.ssh && cp /srv/authorized_keys /home/git/.ssh/ &&
      chown -R git /home/git/.ssh && chmod 700 /home/git/.ssh && chmod 600 /home/git/.ssh/authorized_keys &&
      { [ -d /home/git/repo.git ] || git init -q --bare -b main /home/git/repo.git; } && chown -R git /home/git/repo.git &&
      exec /usr/sbin/sshd -D -e' >/dev/null
  for _ in $(seq 1 60); do
    docker logs "${GIT}" 2>&1 | grep -q "Server listening" && return 0
    sleep 1
  done
  echo "git server did not start"; docker logs "${GIT}" 2>&1 | tail -5
}
clone_ok() { in_app 'rm -rf /tmp/c && timeout 30 git clone -q git@gitsrv:repo.git /tmp/c'; }

mkdir -p "${WORK}/gitsrv" "${WORK}/share/.ssh"
rm -rf "${WORK}/ha/.ssh"; mkdir -p "${WORK}/ha/.ssh"
in_app 'ssh-keygen -q -t ed25519 -N "" -C ha -f /homeassistant/.ssh/id_ed25519 && chmod 644 /homeassistant/.ssh/id_ed25519'
in_app 'ssh-keygen -q -t ed25519 -N secret -C enc -f /share/.ssh/locked'
cat "${WORK}/ha/.ssh/id_ed25519.pub" > "${WORK}/gitsrv/authorized_keys"
set_env_vars() { # set_env_vars <json array> (single-line options.json key; no host jq needed)
  sed -i -E "s/\"env_vars\":\[[^]]*\]/\"env_vars\":$1/" "${WORK}/data/options.json"
}
set_env_vars '[{"name":"GH_TOKEN","value":"dummy-gh-token"}]'
start_git_server
restart_app
log="$(last_start_log)"
check "gh version matches the pin" in_app "gh --version | grep -q \"gh version $(awk '/^ *GH_CLI_VERSION:/{print $2; exit}' "${HERE}/../../build.yaml") \""
check "gh is git's helper for github.com" in_app 'git config --global --get-all credential.https://github.com.helper | grep -qx "!/usr/local/bin/gh auth git-credential"'
check "GH_TOKEN reaches git over HTTPS" in_app 'printf "protocol=https\nhost=github.com\n\n" | git credential fill | grep -qx password=dummy-gh-token'
check "loose key permissions fixed" test "$(in_app 'stat -c %a /homeassistant/.ssh/id_ed25519')" = 600
check "permission fix logged" grep -q "restricted permissions of /homeassistant/.ssh/id_ed25519" <<<"${log}"
check "passphrase key skipped with warning" grep -q "skipping /share/.ssh/locked" <<<"${log}"
check "start log names key and gh state" grep -q "Git access: SSH keys /homeassistant/.ssh/id_ed25519; GitHub CLI uses a token from GH_TOKEN" <<<"${log}"
check "no token or key material in log" bash -c 'docker logs "$1" > "$2" 2>&1 && ! grep -qE "dummy-gh-token|PRIVATE KEY" "$2"' _ "${APP}" "${WORK}/app.log"
check "clone over ssh with HA key, no prompt" clone_ok
check "new host remembered in /data" grep -q "^gitsrv " "${WORK}/data/home/.ssh/known_hosts"
check "bundled host keys trusted" in_app 'ssh-keygen -F github.com -f /opt/paseo-ha/ssh_known_hosts >/dev/null && ssh -G github.com | grep -q "^globalknownhostsfile /opt/paseo-ha/ssh_known_hosts"'
check "no copy of the key under /data" bash -c '! grep -rlq "$(sed -n 2p "$1")" "$2"' _ "${WORK}/ha/.ssh/id_ed25519" "${WORK}/data"

# User ~/.ssh/config comes first; a custom credential helper is kept.
in_app 'printf "Host gitsrv\n  IdentityFile /data/home/.ssh/pinned\n" > ~/.ssh/config && git config --global --replace-all credential.https://github.com.helper store'
restart_app
check "user ssh config IdentityFile first" test "$(in_app 'ssh -G gitsrv | grep -m1 ^identityfile')" = "identityfile /data/home/.ssh/pinned"
check "discovered key still offered" in_app 'ssh -G gitsrv | grep -qx "identityfile /homeassistant/.ssh/id_ed25519"'
check "custom credential helper kept" test "$(in_app 'git config --global --get-all credential.https://github.com.helper')" = store
in_app 'rm -f ~/.ssh/config; git config --global --unset-all credential.https://github.com.helper'

# Host key change is refused.
start_git_server
host_key_refused() { ! clone_ok && grep -q "HOST IDENTIFICATION HAS CHANGED" <<<"$(in_app 'timeout 30 ssh git@gitsrv 2>&1')"; }
check "changed host key refused" host_key_refused
in_app 'ssh-keygen -q -R gitsrv -f /data/home/.ssh/known_hosts' >/dev/null 2>&1

# Removed key is dropped; own key from ssh-keygen persists across container recreation.
rm -f "${WORK}/ha/.ssh/id_ed25519" "${WORK}/ha/.ssh/id_ed25519.pub"
in_app 'ssh-keygen -q -t ed25519 -N "" -C own -f ~/.ssh/id_ed25519'
cat "${WORK}/data/home/.ssh/id_ed25519.pub" > "${WORK}/gitsrv/authorized_keys"
set_env_vars '[]'
start_git_server
start_app   # recreate: simulates an add-on update
check "removed key no longer referenced" bash -c '! docker exec "$1" ssh -G gitsrv | grep -q /homeassistant/.ssh/id_ed25519' _ "${APP}"
check "own key persisted under /data" test -f "${WORK}/data/home/.ssh/id_ed25519"
check "clone with own key after recreate" clone_ok
check "gh not signed in reported" grep -q "GitHub CLI not signed in" <<<"$(last_start_log)"

echo
if [[ "${fails}" -eq 0 ]]; then echo "ALL PASSED"; else echo "${fails} FAILED"; fi
exit $(( fails > 0 ))
