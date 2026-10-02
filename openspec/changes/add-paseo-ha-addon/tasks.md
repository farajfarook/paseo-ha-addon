# Tasks

## 1. Repository and add-on scaffold

- [x] 1.0 Run `git init -b main` in this directory, add `.gitignore`, `LICENSE` (Apache-2.0) and an initial commit, then `gh repo create farajfarook/paseo-ha-addon --public --source . --push --description "Home Assistant add-on for Paseo"`. Verify `gh repo view farajfarook/paseo-ha-addon --json visibility` returns `PUBLIC` and `main` is pushed
- [x] 1.1 Create `repository.yaml` (name, `url: https://github.com/farajfarook/paseo-ha-addon`, maintainer) and a root `README.md` with the "Add repository" button/URL, then verify `repository.yaml` parses as YAML
- [x] 1.2 Create `paseo/config.yaml` with name/slug/description/version `0.10.3-1`, `arch: [aarch64, amd64, armv7]`, `init: false`, `ingress: true`, `ingress_port: 8099`, `panel_title: Paseo`, `panel_icon: mdi:robot-outline`, `ports: {6767/tcp: null}`, `map` per design D11, `homeassistant_api: true`, `hassio_api: true`, `hassio_role: manager`, `watchdog`, `image: ghcr.io/farajfarook/{arch}-addon-paseo`, and the options/schema from design D7a (`workspace`, `git_snapshot`, `agents`, `env_vars`, `password`, `hostnames`, `log_level`, `dictation`, `voice_mode`, `speech_provider`, `worktrees_root`, `relay`). Verify with `frenck/action-addon-linter` (or `docker run ghcr.io/frenck/action-addon-linter`) locally
- [x] 1.3 Create `paseo/build.yaml` with `build_from` for the three `ghcr.io/home-assistant/*-base:latest` images and `args: {PASEO_VERSION: 0.10.3, PI_VERSION: 1.0.0}`, then verify that the linter passes
- [x] 1.4 Add `paseo/translations/en.yaml` with a name and description for every option and verify each schema key has a translation entry
- [x] 1.5 Render `paseo/icon.png` (128×128) and `paseo/logo.png` from upstream `packages/website/public/logo.svg`, add Apache-2.0 attribution in `paseo/README.md`, and verify the images' dimensions and that they display correctly

## 2. Image build (Node, Paseo, Pi)

- [ ] 2.1 Write `paseo/Dockerfile`: `ARG BUILD_FROM`, install `nodejs npm nginx git openssh-client bash curl` plus build-stage `build-base python3 linux-headers`, set `ONNXRUNTIME_NODE_INSTALL=skip`, then `npm install -g @getpaseo/cli@${PASEO_VERSION}` and verify `node --version` ≥ 22.19 and `paseo --version` print the pinned version in a local amd64 build
- [ ] 2.2 Add `npm install -g --ignore-scripts @earendil-works/pi-coding-agent@${PI_VERSION}` and verify `pi --version` runs inside the built image
- [ ] 2.3 Build for `aarch64` and `armv7` via `home-assistant/builder --test` (QEMU) and check that `node -e "require('node-pty')"` works in each image. If musl/armv7 fails, apply the Debian-base fallback from design D1 and record the outcome in design.md
- [ ] 2.4 Add a Docker `HEALTHCHECK` against `http://127.0.0.1:6767/api/health` and verify `docker inspect` reports healthy after start
- [ ] 2.5 Install the pinned per-arch static `ha` CLI binary (`ARG HA_CLI_VERSION`) and verify `ha --version` runs in each arch image

## 3. Runtime: init, daemon service, persistence

- [ ] 3.1 Add the s6 `init-paseo` oneshot. It reads options with bashio, exports `HOME=/data/home`, `PASEO_HOME`, `CLAUDE_CONFIG_DIR`, `CODEX_HOME`, `PI_CODING_AGENT_DIR` and `XDG_*` under `/data/home`, creates the workspace dir if missing (default `/homeassistant`), and writes the daemon env file. Verify with a fake `/data/options.json` that the directories exist after start
- [ ] 3.2 Export `env_vars` option entries into the daemon environment while logging names only, and verify with `grep` on the add-on log that a test secret value never appears while `printenv` in a Paseo terminal shows it
- [ ] 3.3 Add the s6 `paseo` longrun that runs the daemon with `PASEO_WEB_UI_ENABLED=true`, `PASEO_LISTEN=127.0.0.1:6767` (default) and text logs to stdout, plus a `finish` script that halts the container after repeated crashes. Verify daemon logs appear in `docker logs` and that `kill`ing the daemon causes a restart or container exit
- [ ] 3.4 Verify persistence: create a Paseo project and log into Pi, restart the container with the same `/data` volume, and confirm the project and Pi auth remain
- [ ] 3.5 Map the Paseo options per design D7a. Always export `PASEO_DICTATION_ENABLED`/`PASEO_VOICE_MODE_ENABLED` (default `false`), the speech provider vars, `PASEO_LOG_CONSOLE_LEVEL` and `PASEO_LOG_CONSOLE_FORMAT=pretty`. Verify with defaults that no `models/local-speech` download happens and the dictation control is hidden, and that with `dictation: true` the control appears
- [ ] 3.6 Apply `worktrees_root` via `paseo daemon config set/unset worktrees.root --home $PASEO_HOME` before the daemon starts (mkdir if set). Verify a new worktree lands in `/share/<path>` when set and under `/data/home/.paseo/worktrees` when unset
- [ ] 3.7 Apply `relay`: unset means no env var, set means `PASEO_RELAY_ENABLED=<value>`. Verify that with it unset, enabling relay from Paseo's Pair device screen survives a restart, and that with `relay: false` no relay connection is logged
- [ ] 3.8 Verify that runtime settings stay editable: toggle auto-archive-after-merge and browser tools in Paseo's Settings, restart the add-on, and confirm the values persist and the UI shows no overridden paths
- [ ] 3.9 Enable local dictation on an armv7 (or musl) build and verify the daemon still starts and the log explains when local speech is unavailable

## 4. Optional agents

- [ ] 4.1 Implement agent install in `init-paseo`: map `claude-code|codex|opencode` to npm packages, `npm install --prefix /data/agents`, keep a stamp file so unchanged selections skip reinstall, uninstall deselected agents, and prepend `/data/agents/node_modules/.bin` to the daemon `PATH`. Verify that selecting `codex` makes `codex --version` available in a Paseo terminal and that a second start makes no network install
- [ ] 4.2 Make install failures non-fatal and log per-agent errors. Verify by forcing an invalid package/no network that the add-on still starts and Pi is still listed as a provider
- [ ] 4.3 Verify in the Paseo UI that Pi and each selected agent appear as available providers and a deselected agent disappears after restart

## 4a. Editable agent config (design D12)

- [ ] 4a.1 Seed `/config` (`AGENTS.md`, `README.md`, `skills/`, `claude/agents|commands`, `opencode/agents|plugins`, `pi/extensions|prompts`, `codex/prompts`) on first start without overwriting existing files. Verify that a second start leaves an edited `AGENTS.md` unchanged
- [ ] 4a.2 Create directory symlinks from each tool folder into `/config` on every start. Verify that an agent definition in `/config/claude/agents` shows up in Claude and a Pi extension in `/config/pi/extensions` loads
- [ ] 4a.3 Create per-skill symlinks for `/config/skills/*` into `~/.agents/skills` and `~/.claude/skills`, with a manifest in `/data` and cleanup of dangling links. Verify that a test skill is listed by Pi, Claude, Codex and OpenCode, and that after a daemon restart Paseo's own skills and the user links both still exist
- [ ] 4a.4 Generate global instruction files (Claude `CLAUDE.md`, Codex/OpenCode/Pi `AGENTS.md`) from `/opt/paseo-ha/AGENTS.base.md` + `/config/AGENTS.md` with a generated header. Verify that a sentence added to `/config/AGENTS.md` appears in each generated file after a restart
- [ ] 4a.5 Verify with `find /config` after an agent login and a session that no credential, session or key-pair file is written to `/config`

## 4b. Home Assistant integration (design D11, D13–D15)

- [ ] 4b.1 Export `SUPERVISOR_TOKEN`, `HASS_SERVER` and `HASS_TOKEN` to the daemon env. Verify from a Paseo terminal that `curl -H "Authorization: Bearer $SUPERVISOR_TOKEN" http://supervisor/core/api/` returns `API running.` and `POST /api/config/core/check_config` returns a result
- [ ] 4b.2 Verify that `ha core logs`, `ha core check`, `ha addons logs <slug>` and `ha backups new` work from a Paseo terminal, and that `ha core restart` restarts Core while the Paseo session survives
- [ ] 4b.3 Verify the mappings on a real HA: write a file to `/homeassistant` and `/addon_configs/<other>`, confirm that writes to `/ssl`, `/media` and `/backup` fail as read-only, and confirm the `all_addon_configs` + `addon_config` combination is accepted (else apply the D11 fallback)
- [ ] 4b.4 Probe HA's MCP endpoint via `http://supervisor/core/api/mcp` (fallback `http://homeassistant:8123/api/mcp`) with `SUPERVISOR_TOKEN`, record the result in design.md D13a, and implement the per-agent MCP config merge for Claude, Codex and OpenCode. Verify that with HA's MCP Server integration enabled each lists HA tools, and that without it sessions start and one info log line appears
- [ ] 4b.5 Write the bundled skill `/opt/paseo-ha/skills/home-assistant` (paths, layout, API/CLI recipes, workflow, hard rules) and `AGENTS.base.md`, linked per D12/D14. Verify by asking Pi to "add an automation that turns on <test light> at sunset": it edits the right file, runs check_config, reloads automations, verifies via the API, and doesn't print `secrets.yaml`
- [ ] 4b.6 Verify user override: copy the skill to `/config/skills/home-assistant`, edit it, restart, and confirm the user's version is the one agents load
- [ ] 4b.7 Add the `paseo-ha-bootstrap` oneshot (after daemon health) that ensures a single "Home Assistant" project for `/homeassistant` via the `paseo project` CLI. Verify on first open it is listed, that after a restart there is still exactly one, and that a user rename is kept
- [ ] 4b.8 Implement `git_snapshot` (init, `.gitignore` if absent, local identity, `safe.directory`, initial commit, and never touching an existing repo). Verify that with defaults no `.git` is created, that enabling it creates a repo whose `git status` doesn't show `secrets.yaml`/`.storage`, that an existing repo is left unchanged, and that `git revert` of an agent commit restores the file

## 5. Ingress adapter

- [ ] 5.1 Add an nginx server template on port 8099: `allow 172.30.32.2; deny all;`, proxy to `127.0.0.1:6767` with WebSocket upgrade, `proxy_buffering off`, 3600 s timeouts, `client_max_body_size 100m`, `Host 127.0.0.1:6767`, and an `Origin` rewrite. Verify with `curl` from a non-allowed IP that you get 403, and through the allowed path that `/api/health` returns 200
- [ ] 5.2 Add `sub_filter` rules (with `Accept-Encoding ""` upstream) that prefix `/_expo/`, `/manifest.json`, `/favicon.ico` and `/apple-touch-icon.png` with `$http_x_ingress_path` and inject `<script src="<prefix>/paseo-ha/shim.js">` before `</head>`. Verify with `curl -H "X-Ingress-Path: /api/hassio_ingress/test"` that the returned `index.html` has prefixed URLs and the shim tag
- [ ] 5.3 Write `paseo-ha/shim.js`. It sets `__PASEO_INITIAL_DAEMON_CONNECTION__` from `location` (host + explicit port, `useTls` from scheme), rewrites same-host `/ws` WebSocket URLs and `/api/`, `/mcp/` and `/public/` fetch/XHR URLs to the ingress prefix, and maps `history`/`location` so the router sees app-relative paths. Verify in a browser behind a local mock ingress (nginx adding `X-Ingress-Path` and a path prefix) that the UI auto-connects, live agent output streams, and a deep-link reload returns to the same page
- [ ] 5.4 Add an s6 `nginx` longrun that depends on `paseo` readiness and renders the template from `init-paseo`. Verify that nginx starts only after `/api/health` is up
- [ ] 5.5 Click-test the main UI flows under the mock ingress (new session, terminal, file pane, download, settings) and fix or document any URL that escapes the prefix in `DOCS.md` "Known limitations"

## 6. Direct port and auth

- [ ] 6.1 In `init-paseo`, if port 6767 is mapped and `password` is set, listen on `0.0.0.0:6767` with `PASEO_PASSWORD` and `PASEO_HOSTNAMES` from `hostnames`, and configure nginx to add `Authorization: Bearer` and the `paseo.bearer.<pw>` WS subprotocol upstream. Verify that the ingress UI still works without a prompt and a direct `curl <host>:6767/api/...` without a bearer returns 401
- [ ] 6.2 If the port is mapped without a password, keep loopback-only and log a warning. Verify that the direct port refuses connections and the warning appears in the log
- [ ] 6.3 Verify the Paseo CLI connects via `paseo project ls --host <ha-host>:6767` with the password and a custom hostname from `hostnames` is accepted

## 7. Documentation

- [ ] 7.1 Write `paseo/DOCS.md`: install, sidebar usage, options reference (including which Paseo settings are managed by the add-on and which stay in Paseo's Settings screen, plus how to edit `/data/home/.paseo/config.json` for advanced settings), the voice model download size and the relay vs. direct port trade-off, agent login via Paseo terminal, the folder map (`/homeassistant`, `/addon_configs`, `/config` editable agent config, `/share`, the read-only folders), how to add skills/instructions, the HA API/`ha` CLI/MCP capabilities and how to enable HA's MCP Server integration, `git_snapshot` and the "take a backup first" warning, the security/trust model (root, read-write mounts, Core token, Supervisor `manager` role, HA auth on ingress, password for direct port, lower security rating), `mdi` sidebar icon note, armv7 best-effort note and known limitations. Verify that every option in `config.yaml` is documented
- [ ] 7.2 Add a "Bumping Paseo" section to the root `README.md`: diff upstream `packages/server/src/server/web-ui.ts`, `packages/protocol/src/daemon-endpoints.ts` and the exported `web-ui/index.html` for asset-path, `/ws` or connection-hint changes, update `sub_filter`/shim if needed, and require the smoke test (8.3) to pass. Verify by following the steps once against the pinned 0.10.3
- [ ] 7.3 Write `paseo/CHANGELOG.md` with the first entry `0.10.3-1` naming Paseo 0.10.3 and Pi 1.0.0, and verify it renders in the HA Changelog tab

## 8. CI

- [ ] 8.1 Add `.github/workflows/lint.yaml` running `frenck/action-addon-linter` on `paseo/` and verify it passes on the branch and fails when a deliberate schema error is introduced
- [ ] 8.2 Add `.github/workflows/builder.yaml` with a `home-assistant/builder` `--test` matrix for `aarch64`, `amd64` and `armv7`, and verify all three jobs run and report per-arch status
- [ ] 8.3 Add an amd64 smoke-test job that runs the image with a fake `options.json`, then asserts `/api/health` via nginx with a stub `X-Ingress-Path`, rewritten `/_expo/` URLs plus the shim in `index.html`, and a successful WebSocket upgrade on `<prefix>/ws`. Verify the job passes in CI

- [ ] 8.4 Add `.github/workflows/publish.yaml` (on tag `v*` + `workflow_dispatch`, `permissions: packages: write`, GHCR login with `GITHUB_TOKEN`, a per-arch `home-assistant/builder` matrix with amd64/aarch64 on native runners and armv7 via QEMU, pushing `ghcr.io/farajfarook/{arch}-addon-paseo:<version>` and `:latest`, plus a guard that fails if the tag differs from `config.yaml` `version`). Verify by running it via `workflow_dispatch` on a test tag and seeing the three packages under the repo's Packages
- [ ] 8.5 Document the release process (bump version + CHANGELOG → merge → tag `v<version>` → publish) in the root `README.md` and verify a mismatched tag makes the publish guard fail

## 9. End-to-end validation on Home Assistant

- [ ] 9.0 Cut the first release `v0.10.3-1`, then set each of the three GHCR packages to Public. Verify with `docker logout ghcr.io && docker pull ghcr.io/farajfarook/amd64-addon-paseo:0.10.3-1` (and for aarch64/armv7 using `--platform`) that anonymous pulls succeed
- [ ] 9.1 Install the add-on from `https://github.com/farajfarook/paseo-ha-addon` (it should pull the pre-built image, not build locally) from the repository URL on a real HA OS instance (amd64 and, if available, aarch64), open "Paseo" from the sidebar over local HTTP and over HTTPS/Nabu Casa, confirm the "Home Assistant" project is preselected, ask Pi to make a small automation change end-to-end (edit → check → reload → verify), confirm live output, a deep-link reload, no mixed-content errors and no Paseo password prompt
- [ ] 9.2 Take an HA backup including the add-on, uninstall, restore, and confirm Paseo projects and agent logins are back
