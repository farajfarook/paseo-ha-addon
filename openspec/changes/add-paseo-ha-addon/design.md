# Design

## Context

- The repository is empty apart from OpenSpec tooling. This is a greenfield HA add-on repository. Motivation: see `proposal.md`. Requirements: see `specs/`.
- Upstream Paseo (inspected at `getpaseo/paseo`, npm `@getpaseo/cli@0.10.3` latest stable, `0.11.0-beta.3` beta):
  - `@getpaseo/server` ships a prebuilt Expo web export in `dist/server/web-ui/` (with `.br`/`.gz` siblings). It is enabled with `PASEO_WEB_UI_ENABLED=true` and served from the same Express origin as `/api/*`, `/mcp/*` and the `/ws` WebSocket.
  - The exported `index.html` and JS bundle use **absolute root paths** (`/_expo/static/...`, `/manifest.json`, `/favicon.ico`). Expo is built with `web.output: "single"` and no `experiments.baseUrl`.
  - On every `index.html` response the daemon injects `window.__PASEO_INITIAL_DAEMON_CONNECTION__ = { listen: <Host header>, useTls: req.protocol === "https" }`. The client builds `ws(s)://<listen>/ws` (`buildDaemonWebSocketUrl`, hard-coded `/ws` path) and fetches `/api/*` on that host.
  - The host allowlist (`PASEO_HOSTNAMES`) accepts localhost and any IP by default. The WebSocket origin check passes same-origin requests or anything in `PASEO_CORS_ORIGINS`. Forwarded headers are trusted only from `PASEO_TRUSTED_PROXIES` (default `loopback`).
  - Auth is an optional bcrypt password (`PASEO_PASSWORD`) checked as an HTTP bearer token or a `paseo.bearer.<token>` WebSocket subprotocol. Without a password, everything is open.
  - Native deps: `node-pty` and `sherpa-onnx-node`. The official image sets `ONNXRUNTIME_NODE_INSTALL=skip` and uses `tini`.
  - The official Docker image is Debian `node:22-bookworm-slim`, is amd64/arm64 only, and runs as uid 1000.
- Home Assistant Ingress proxies `https://<ha>/api/hassio_ingress/<token>/…` to `http://<addon-ip>:<ingress_port>/…`. It strips the prefix, sends `X-Ingress-Path: /api/hassio_ingress/<token>`, supports WebSocket, and connects from `172.30.32.2`. Panel icons must be `mdi:*`.
- Pi (`@earendil-works/pi-coding-agent@1.0.0`) requires Node ≥ 22.19.

## Goals / Non-Goals

**Goals:**
- Paseo works in the HA sidebar with zero manual pairing, using the upstream npm release unchanged (no fork, no rebuild of the Expo app).
- One add-on directory in the public GitHub repo `farajfarook/paseo-ha-addon`, with pre-built multi-arch images published to GHCR so HA pulls instead of building on-device.
- Agent installs and credentials survive updates and are part of HA backups.

**Non-Goals:**
- Patching, forking or requesting changes from Paseo upstream. Paseo has no base-path setting: `PASEO_APP_BASE_URL` only sets the hosted-app link used for pairing/share URLs. The ingress adapter (D3) is the permanent solution owned by this add-on.
- Exposing HA entities/services to Paseo as tools, or HA integrations/sensors for Paseo state.
- Relay pairing UX inside HA. Users can still run `paseo` pairing via the direct port.
- Supporting `i386`.

## Decisions

### D1. Add-on layout and base image
```
repository.yaml
paseo/
  config.yaml  build.yaml  Dockerfile  icon.png  logo.png
  DOCS.md  README.md  CHANGELOG.md  translations/en.yaml
  rootfs/etc/s6-overlay/s6-rc.d/{init-paseo,paseo,nginx}/...
  rootfs/etc/nginx/templates/ingress.conf.tpl
  rootfs/usr/local/bin/paseo-ha-*  (helper scripts)
.github/workflows/{lint.yaml,builder.yaml}
```
- `build.yaml` uses the user-specified `ghcr.io/home-assistant/{aarch64,amd64,armv7}-base:latest` (Alpine + s6-overlay v3 + bashio). Node is installed with `apk add nodejs npm`, using an Alpine release whose `nodejs` is ≥ 22.19 (verify at implementation; otherwise pin the `-base:<alpine-version>` tag that provides it).
- **Alternative considered:** `ghcr.io/home-assistant/*-base-debian` or extending `ghcr.io/getpaseo/paseo`. The upstream image has no armv7 and no s6/bashio. Debian base would avoid musl risk for `node-pty`/`sherpa-onnx-node`. Alpine is kept because the user asked for it. **Fallback:** if `npm install` of `@getpaseo/cli` fails on musl (no prebuilt binary and no build toolchain), switch `build_from` to `*-base-debian:bookworm` and install Node 22 from NodeSource. The Dockerfile is written so only the `FROM`/package-install stage differs.
- Native modules: install `build-base python3 linux-headers` in a build stage so `node-pty` can compile from source on musl/armv7. Set `ONNXRUNTIME_NODE_INSTALL=skip`. If `sherpa-onnx-node` has no binary for the platform, voice features degrade but the daemon must still start. Treat this as an acceptance check per arch.

### D2. Pinned Paseo version
- `Dockerfile` `ARG PASEO_VERSION=0.10.3` → `npm install -g @getpaseo/cli@${PASEO_VERSION}`. The same version goes in `build.yaml` `args`.
- Add-on `version` = Paseo version, plus an add-on revision suffix when only the add-on changes (e.g. `0.10.3-1`). The CHANGELOG names the Paseo version.
- **Alternative:** track `latest` at build time. This was rejected because it is not reproducible and the ingress shim depends on upstream internals.

### D3. Ingress adapter: nginx on the ingress port with path rewriting
Paseo assumes it lives at `/`, but under ingress the browser is at `/api/hassio_ingress/<token>/`. If nothing changes, the root-absolute asset URLs, `/api/*` calls and the `ws://<host>/ws` URL would all hit Home Assistant itself. The fix is an nginx server on `ingress_port: 8099` in front of the daemon (daemon bound to `127.0.0.1:6767`):

1. **Allow only the ingress proxy:** `allow 172.30.32.2; deny all;`.
2. **Proxy everything to the daemon** with WebSocket upgrade, `proxy_buffering off`, 3600 s timeouts and `client_max_body_size 100m`. It sets `Host 127.0.0.1:6767` so the host allowlist passes, and strips `Origin` (or rewrites it to `http://127.0.0.1:6767`) so the WS same-origin check passes. nginx is the only thing that can reach the daemon port, so origin trust moves to nginx's allowlist.
3. **Rewrite HTML/JS/CSS/manifest responses** with `sub_filter` (and `proxy_set_header Accept-Encoding ""` so the daemon serves uncompressed files that can be rewritten):
   - `"/_expo/` → `"<X-Ingress-Path>/_expo/`, and the same for `/manifest.json`, `/favicon.ico` and `/apple-touch-icon.png`.
   - Replace the injected connection hint so the client connects back through HA. It gets `listen` = the browser's HA host, with TLS taken from the page scheme. This is done by injecting a small `<script>` before `</head>` (served by nginx from `/paseo-ha/shim.js`) that runs before the app bundle:
     - Sets `window.__PASEO_INITIAL_DAEMON_CONNECTION__ = { listen: location.host (with explicit port: 443/80 when absent), useTls: location.protocol === "https:", label: "Home Assistant" }`.
     - Wraps `window.WebSocket` so any URL whose path is `/ws` on `location.host` is rewritten to `<ingressPath>/ws`.
     - Wraps `fetch`/`XMLHttpRequest` so same-host URLs starting with `/api/`, `/mcp/` or `/public/` are prefixed with `<ingressPath>`.
     - Patches `history.pushState`/`replaceState` and the initial `location` so the Expo router sees app-relative paths. The router runs at `/` while the real URL keeps the ingress prefix. The shim prefixes outgoing navigations and strips the prefix from what the router reads, so deep-link reloads land on the right page.
   - The ingress path comes from the `X-Ingress-Path` request header, which nginx exposes to `sub_filter` via `$http_x_ingress_path`.
4. HA serves the panel in an iframe from the same origin, so cookies and storage are shared with HA. Paseo's client-side storage (IndexedDB/localStorage) is namespaced by Paseo keys, which is acceptable.

- **Alternatives considered:**
  - *Rebuild the Expo web app with `experiments.baseUrl`.* This doesn't work because the ingress token is dynamic per install/session and Expo's baseUrl is fixed at build time. It would also mean a heavy Expo build per arch.
  - *Only redirect to a direct port (`webui:` link).* This fails the "open in the side menu" requirement and needs a password and a port mapping.
  - *Node/TS proxy instead of nginx.* This is viable, but nginx `sub_filter` and WebSocket proxying are standard for HA add-ons and add no new runtime code.
- **Why this preserves ingress-only auth:** the daemon runs **without** `PASEO_PASSWORD` on its loopback listener when the direct port is disabled. Only nginx (loopback) and the ingress proxy (`172.30.32.2` → nginx) can reach it.
- **Fragility:** the rewrite depends on upstream's root-absolute paths, the `/ws` path and the hint global. Each version bump must pass the ingress smoke test (task 8.3) before the pinned version is raised.

### D4. Optional direct port with mandatory password
- `config.yaml` declares `ports: {"6767/tcp": null}`, so the port is disabled unless the user maps it. Options: `password` (`password?`) and `hostnames` (`[str]`).
- Startup logic (`init-paseo`): if the user mapped the direct port (detected via `bashio::addon.port 6767`) **and** set a password, the daemon listens on `0.0.0.0:6767` with `PASEO_PASSWORD`. nginx then authenticates to the daemon by adding `Authorization: Bearer <password>` on HTTP and injecting the `paseo.bearer.<password>` subprotocol on WS upgrades, so ingress stays password-free. If the port is mapped without a password, the daemon stays on loopback and a clear warning is logged.
- `PASEO_HOSTNAMES` comes from the `hostnames` option. Direct-port users connect with the regular Paseo apps/CLI.

### D5. Process supervision
- s6-overlay v3 services: `init-paseo` (oneshot: read options, prepare dirs, install agents, render nginx config) → `paseo` (longrun: `paseo daemon run`, or the server's `supervisor-entrypoint.js` as in upstream Docker, with `PASEO_WEB_UI_ENABLED=true`, `PASEO_LISTEN`, `PASEO_LOG_FORMAT=text`) and `nginx` (longrun, depends on `paseo` readiness).
- A `finish` script calls `/run/s6/basedir/bin/halt` after repeated failures so the Supervisor `watchdog: tcp://[HOST]:[PORT:8099]` restarts the add-on. The Docker `HEALTHCHECK` polls `http://127.0.0.1:6767/api/health`.
- `init: false` in `config.yaml` (required for s6-overlay v3).

### D6. Persistence, files and user
- **Private state** lives under `/data`, which is per-add-on, persistent, in backups and not visible to File Editor or Samba. `HOME=/data/home` and `PASEO_HOME=/data/home/.paseo`. `CLAUDE_CONFIG_DIR`, `CODEX_HOME`, `XDG_*` and `PI_CODING_AGENT_DIR=/data/home/.pi/agent` all live under `/data/home`. All credentials, sessions, history, caches, `~/.claude.json` and Paseo's `config.json` and daemon key pair stay here.
- **Editable agent config** lives in the add-on's own `addon_config` folder (D12).
- **Mappings** are listed in D11. The workspace option defaults to `/homeassistant`.
- **Run as root inside the container.** Most HA add-ons do this. `/share`, `/homeassistant` and `/addon_configs` are root-owned, and a uid-1000 user could not write them without `chown`ing the user's HA config, which is unacceptable. This means dropping the upstream image's non-root model. Claude Code refuses `--dangerously-skip-permissions` as root, so the docs must note this (users can still approve permissions interactively). Revisit with a dedicated user plus ACLs if it becomes a problem.

### D7. Agents: Pi bundled, others opt-in and installed persistently
- The image runs `npm install -g @earendil-works/pi-coding-agent@<pinned> --ignore-scripts`, and `pi` is on `PATH`. Pi is baked in so it is available offline from first start.
- Option `agents: [list(claude-code|codex|opencode)]`, default `[]`. `init-paseo` installs selected agents with `npm install --prefix /data/agents <pkg>` and adds `/data/agents/node_modules/.bin` to `PATH`. Installs run only when the selected set or the pinned version map changes. A stamp file in `/data/agents` records what is installed, and agents that are no longer selected are uninstalled. Failures are logged per agent and never abort startup.
- Package map: `claude-code → @anthropic-ai/claude-code`, `codex → @openai/codex`, `opencode → opencode-ai`. Codex and OpenCode ship platform binaries. On armv7 (and on musl where unsupported), install is attempted and logged as unsupported on failure.
- **Alternative:** bake all agents into the image. This was rejected because it bloats the image for every user and agent CLIs update far more often than add-on releases.
- Option `env_vars: [{name: str, value: password}]` is exported into the daemon environment (and so into agents). Values are never echoed. `bashio::log` prints only names.
- Interactive logins (`claude login`, `pi` auth) are done from a Paseo terminal session inside the UI, which runs in the same container and `HOME`. The docs explain this.

### D7a. Add-on options ↔ Paseo configuration
Paseo has three configuration layers: defaults, then `$PASEO_HOME/config.json`, then environment variables (for foreground `daemon run`). **Environment variables lock a setting**: Paseo's UI then reports it under `overrideControlledPaths` and can't change it. The add-on's rule is therefore to use env vars only for settings that are add-on-owned or startup-only, and never for settings Paseo's UI edits at runtime.

| Add-on option | Schema | Default | Applied as |
|---|---|---|---|
| `workspace` | `str` | `/homeassistant` | mkdir if missing, daemon `cwd`/terminal default |
| `git_snapshot` | `bool` | `false` | D15 |
| `agents` | `[list(claude-code\|codex\|opencode)]` | `[]` | npm install (D7) |
| `env_vars` | `[{name: match(^[A-Za-z_][A-Za-z0-9_]*$), value: password}]` | `[]` | exported into the daemon env; names only are logged |
| `password` | `password?` | — | `PASEO_PASSWORD`, only when the direct port is mapped (D4) |
| `hostnames` | `[str]` | `[]` | `PASEO_HOSTNAMES` (lists append with `config.json`, so nothing is locked) |
| `log_level` | `list(trace\|debug\|info\|warn\|error)` | `info` | `PASEO_LOG_CONSOLE_LEVEL` |
| `dictation` | `bool` | `false` | `PASEO_DICTATION_ENABLED` |
| `voice_mode` | `bool` | `false` | `PASEO_VOICE_MODE_ENABLED` |
| `speech_provider` | `list(local\|openai)` | `local` | `PASEO_DICTATION_STT_PROVIDER`, `PASEO_VOICE_STT_PROVIDER`, `PASEO_VOICE_TTS_PROVIDER` (turn detection stays `local`) |
| `worktrees_root` | `str?` | — (Paseo default `$PASEO_HOME/worktrees`) | no env var exists, so `init-paseo` runs `paseo daemon config set worktrees.root <path> --home $PASEO_HOME` before the daemon starts. Unset means `config unset`. mkdir if missing |
| `relay` | `bool?` | unset | unset: no env, so Paseo's "Pair device" toggle owns `daemon.relay.enabled` in `config.json`. Set: `PASEO_RELAY_ENABLED=<value>` (locks it, by design) |

- **Speech defaults off.** Upstream defaults both features to enabled, which downloads about 0.6–1 GB of sherpa-onnx models (Parakeet STT, Kokoro TTS) into `$PASEO_HOME/models/local-speech` and runs CPU inference. The add-on always exports both `*_ENABLED` vars, so they default to `false`. Local models persist under `/data`. If `sherpa-onnx-node` cannot load (musl/armv7), the daemon must still start. Verify this and log a hint to use `openai`.
- **Fixed by the add-on, not exposed:** `PASEO_LISTEN`, `PASEO_WEB_UI_ENABLED=true`, `PASEO_HOME`, `PASEO_TRUSTED_PROXIES=loopback`, `PASEO_LOG_CONSOLE_FORMAT=pretty`. CORS, the app base URL and the service proxy keep Paseo defaults.
- **Deliberately left to Paseo's UI (never env):** `mcp.injectIntoAgents`, `browserTools`, `autoArchiveAfterMerge`, `enableTerminalAgentHooks`, `appendSystemPrompt`, `terminalProfiles`, `agentProfiles`, `agents.providers`, `metadataGeneration`, `skills`, `plugins`/`pluginsEnabled`, git limits and voice LLM provider/model. Advanced users can still edit `/data/home/.paseo/config.json` (documented) or set Paseo env vars through `env_vars`.
- **Option changes take effect on add-on restart**, which is HA's standard behaviour. Because `init-paseo` re-applies them on every start, removing an option reverts to the Paseo default.
- **Alternative considered:** write every option into `config.json` instead of env. That was rejected because it would silently overwrite UI edits on every restart. Env vars make the override visible in Paseo's UI.

### D8. Branding
- `icon.png` (128×128) and `logo.png` (250×100 area) are rendered from upstream `packages/website/public/logo.svg` (Apache-2.0, with attribution in README). Sources: `packages/app/assets/images/icon.png` and `favicon.svg`.
- `panel_icon` can't be custom (HA only accepts `mdi:`). Use `mdi:robot-outline` as the closest neutral match, and note this in the docs.

### D9. CI
- `frenck/action-addon-linter` on `paseo/`.
- `home-assistant/builder` action in `--test` mode for `aarch64`, `amd64` and `armv7` (matrix, QEMU) on pull requests and pushes. It does not push images.
- A smoke-test job on amd64: run the built image with a fake `/data/options.json`, start nginx with a stub `X-Ingress-Path`, then assert that `/api/health` is 200 through nginx, that `index.html` contains rewritten `/_expo/` paths and the shim, and that a WebSocket upgrade to `<prefix>/ws` succeeds.

### D10. Hosting and image publishing
- **Repository:** public GitHub repo `https://github.com/farajfarook/paseo-ha-addon`, created with `gh repo create farajfarook/paseo-ha-addon --public` from this directory. `main` is the default branch. `repository.yaml` `url` and the README "Add repository" link point to it. The license is Apache-2.0, to match Paseo.
- **Images:** `paseo/config.yaml` sets `image: ghcr.io/farajfarook/{arch}-addon-paseo`. The Supervisor substitutes `{arch}` and pulls the tag that equals the add-on `version`.
- **Publish workflow** (`.github/workflows/publish.yaml`): triggered by a release/tag `v*` and `workflow_dispatch`. It has `permissions: { contents: read, packages: write }` and logs in to `ghcr.io` with the built-in `GITHUB_TOKEN`, so no stored secrets are needed. A matrix of `home-assistant/builder` jobs runs one per arch with `--{arch} --target paseo --docker-hub ghcr.io/farajfarook --image {arch}-addon-paseo`, pushing `:<version>` and `:latest`. A pre-step fails the job if the tag (minus `v`) differs from `paseo/config.yaml` `version`. amd64 and aarch64 use native runners (`ubuntu-latest`, `ubuntu-24.04-arm`). armv7 uses QEMU on `ubuntu-latest`, so its build is slow.
- **Visibility:** GHCR creates new packages as private. After the first publish, each of the three packages must be set to **Public** once (Package settings → Change visibility), because the Supervisor pulls anonymously. The packages are linked to the repo via the `org.opencontainers.image.source` label so they show up on the repo page.
- **Release order:** bump `version` + CHANGELOG → merge → tag `v<version>` → the publish workflow pushes the images → users see the update. If the tag were published before its images existed, installs would fail. Because the Supervisor reads `version` from `main`, the version bump is merged only together with the tag, and the tag is pushed immediately after the merge.
- **Alternative:** leave out `image:` and let the Supervisor build locally. That was rejected because the build is slow on Raspberry Pi-class hardware and native module compiles can fail on-device.

### D11. Home Assistant folder mappings
```yaml
map:
  - type: homeassistant_config   # → /homeassistant
    read_only: false
  - type: all_addon_configs      # → /addon_configs (other add-ons' configs)
    read_only: false
  - type: addon_config           # → /config (this add-on's editable folder, D12)
    read_only: false
  - type: share                  # → /share
    read_only: false
  - type: ssl                    # → /ssl (ro)
  - type: media                  # → /media (ro)
  - type: backup                 # → /backup (ro)
```
- `all_addon_configs` and `addon_config` both cover this add-on's own folder. The linter/Supervisor must accept both mappings together. If it rejects the combination, drop `addon_config` and use `/addon_configs/<repo>_paseo` directly (the path is resolved at start from `bashio::addon.slug`).
- Paths are documented in DOCS and in the bundled HA guidance (D14), so agents and users use the same names.

### D12. Editable agent-config folder (`/config` inside the container = `/addon_configs/<repo>_paseo` on the host)
The folder is seeded on first start, and files are never overwritten once they exist:
```
/config/
  AGENTS.md            ← user's shared instructions (starts empty, with a comment header)
  skills/              ← user's skills, shared by every agent
  claude/agents/  claude/commands/
  opencode/agents/  opencode/plugins/
  pi/extensions/  pi/prompts/
  codex/prompts/
  README.md            ← explains each folder
```
- **Directory links only.** Tools save single files by write-temp-then-rename, which would replace a link to a single file with a plain file. On each start `init-paseo` (re)creates symlinks from tool folders to the editable folder: `~/.claude/agents → /config/claude/agents`, `~/.claude/commands → /config/claude/commands`, `$XDG_CONFIG_HOME/opencode/agents → /config/opencode/agents`, and similarly for opencode/plugins, pi/extensions, pi/prompts and codex/prompts.
- **Skills without colliding with Paseo's skill sync.** Paseo's daemon writes its own orchestration skills into `~/.agents/skills/<name>` and `~/.claude/skills/<name>` with a managed-files manifest, and deletes stale ones there. We therefore do **not** link those whole folders to `/config/skills`. Instead, on each start `init-paseo` creates **per-skill symlinks** `~/.agents/skills/<user-skill> → /config/skills/<user-skill>` and the same under `~/.claude/skills/`. It removes dangling links it created, recorded in a manifest in `/data`, and never touches Paseo-managed entries. Pi, Codex and OpenCode read `~/.agents/skills`. Claude reads `~/.claude/skills`. Verify that Paseo's sync ignores foreign symlinks.
- **Instructions:** the bundled HA guidance (D14) and the user's `/config/AGENTS.md` are concatenated into each tool's global instruction file on every start: `~/.claude/CLAUDE.md`, `$CODEX_HOME/AGENTS.md`, `$XDG_CONFIG_HOME/opencode/AGENTS.md` and `$PI_CODING_AGENT_DIR/AGENTS.md`. These generated files live in `/data` and carry a "generated, edit /config/AGENTS.md instead" header. Generating them keeps bundled guidance updatable without overwriting user edits.
- Tool settings files (`~/.claude/settings.json`, `opencode.json`, Pi `settings.json`, Codex `config.toml`) stay in `/data` because they're single files rewritten by the tools. Advanced users edit them via a Paseo terminal.

### D13. Live HA access: Core API, Supervisor and `ha` CLI
- `config.yaml`: `homeassistant_api: true`, `hassio_api: true`, `hassio_role: manager`. The Supervisor injects `SUPERVISOR_TOKEN`, and the daemon environment (and so every agent) inherits it. The add-on also exports `HASS_SERVER=http://supervisor/core` and `HASS_TOKEN=$SUPERVISOR_TOKEN` as conventional names.
- **Core API:** REST at `http://supervisor/core/api/...` (e.g. `POST /api/config/core/check_config`, `POST /api/services/automation/reload`, `GET /api/states`). WebSocket at `ws://supervisor/core/websocket` for registries, dashboards and similar. Both are authorised with `Authorization: Bearer $SUPERVISOR_TOKEN`.
- **`ha` CLI:** install the official static `ha` binary from `home-assistant/cli` releases (per-arch, pinned version, `ARG HA_CLI_VERSION`). It talks to `http://supervisor` with `SUPERVISOR_TOKEN`. It supports `ha core check|restart|logs`, `ha addons logs|restart <slug>`, `ha backups new` and `ha supervisor logs`.
- **Role choice:** `manager` permits Core restart and add-on management but not host/OS operations (that needs `admin`). The linter flags elevated roles in the security rating, which is acceptable and documented.
- `ha core restart` restarts Core only. The Paseo add-on keeps running, so the agent session survives and can read logs afterwards.

### D13a. Home Assistant MCP wiring
- HA's `mcp_server` integration serves Streamable HTTP at `/api/mcp`. Via the Supervisor proxy this is `http://supervisor/core/api/mcp`. **Must verify** that the proxy forwards it, including streaming. Fallback: `http://homeassistant:8123/api/mcp` on the internal network with the same token. If neither works with `SUPERVISOR_TOKEN`, document a long-lived token supplied via `env_vars` as `HA_MCP_TOKEN`.
- On each start `init-paseo` probes the endpoint. If it responds (not 404), the add-on writes an `homeassistant` MCP server entry into each MCP-capable agent's user config, merging rather than replacing:
  - Claude: `~/.claude.json` `mcpServers`, via `claude mcp add --scope user --transport http`.
  - Codex: a `[mcp_servers.homeassistant]` table in `$CODEX_HOME/config.toml`, with a bearer header.
  - OpenCode: an `mcp.homeassistant` entry of type `remote` in `opencode.json`, with headers.
  - Pi has no built-in MCP, so it relies on REST/CLI via the HA skill.
- If the probe returns 404, the add-on logs one info line explaining how to enable the integration.
- Paseo's own MCP injection (`mcp.injectIntoAgents`) is unaffected.

### D14. Bundled Home Assistant guidance
- The image ships `/opt/paseo-ha/skills/home-assistant/SKILL.md` (plus `reference/*.md`) and `/opt/paseo-ha/AGENTS.base.md`. These are versioned with the add-on and read-only.
- **The skill** covers:
  - Paths: `/homeassistant`, `/addon_configs`, `/share`, and the read-only `/ssl`, `/media` and `/backup`.
  - Config layout: `configuration.yaml`, `automations.yaml`, `scripts.yaml`, `scenes.yaml`, `packages/`, `blueprints/`, `custom_components/`, and `.storage` as read-only.
  - API recipes using `curl` with `$SUPERVISOR_TOKEN`.
  - `ha` CLI recipes.
  - The MCP note.
- **The required workflow:**
  1. Snapshot: git commit if enabled, else suggest `ha backups new` for large changes.
  2. Edit.
  3. `check_config`.
  4. Reload the narrowest domain, or restart only if required.
  5. Verify via states and `ha core logs`.
  6. Roll back on failure.
- **Hard rules:**
  - Never print or exfiltrate `secrets.yaml` values. Use `!secret` references.
  - Never edit `.storage/*` while Core runs.
  - Never delete `home-assistant_v2.db`.
  - Ask before `ha core restart` or touching other add-ons.
- It is linked per-skill into `~/.agents/skills/home-assistant` and `~/.claude/skills/home-assistant` (as in D12). `AGENTS.base.md` is prepended to the generated instruction files (D12).
- A user who wants to customise the guidance copies the skill to `/config/skills/home-assistant`. The user's copy takes precedence because its link is created last and replaces the bundled link.

### D14a. Default "Home Assistant" project
- After the daemon is healthy, a oneshot `paseo-ha-bootstrap` runs:
  1. `paseo project ls --json` against the local daemon.
  2. If no project's path is `/homeassistant`, run `paseo project create /homeassistant`, then `paseo project rename <id> "Home Assistant"`.
  3. It never renames an existing project.
- The same oneshot also registers the workspace option's path when it differs from `/homeassistant`.
- Failure is logged and non-fatal.

### D15. Optional git snapshots (`git_snapshot`, default false)
- When enabled and `/homeassistant/.git` does not exist:
  1. `git init -b main`.
  2. Write a `.gitignore` (only if absent) excluding `secrets.yaml`, `.storage/`, `*.db*`, `*.log*`, `.cloud/`, `deps/`, `tts/`, `__pycache__/`, `.HA_VERSION` and `home-assistant.log*`.
  3. Set a local `user.name`/`user.email` of "Paseo Agent".
  4. Create an initial commit.
- If `.git` already exists, do nothing to it. Mark it as a `safe.directory` because root owns it.
- The bundled guidance instructs agents to commit before and after each change with descriptive messages when `/homeassistant/.git` exists. Users can review the history in a Paseo terminal and the git UI.
- Disabling the option later does not delete `.git`.

## Risks / Trade-offs

- [Ingress rewrite breaks on Paseo upgrades (paths, hint global, `/ws`)] → Pin the version (D2), CI smoke test (D9), and before each bump diff upstream `web-ui.ts`/`daemon-endpoints.ts` and the exported `index.html` for path changes.
- [Monkey-patching `WebSocket`/`fetch`/`history` misses some code path (e.g. downloads, service-proxy routes, `<a href="/...">`)] → Also `sub_filter` common string literals in JS and click-test the main flows (sessions, terminal, file pane, downloads) during implementation. Document known gaps.
- [Alpine/musl native modules (`node-pty`, `sherpa-onnx-node`) or agent binaries fail, especially on armv7] → Build-stage toolchain, the Debian-base fallback (D1), and best-effort armv7 documented as such.
- [Agents have root, read-write access to `/homeassistant` and `/addon_configs`, a Core token and the Supervisor `manager` role. A bad change or a prompt injection could break HA or restart it] → Bundled guidance with a check/reload/rollback workflow and hard rules, ask-before-restart, the optional git snapshots (D15), backups via `ha backups new`, and an explicit security section in DOCS. The add-on reports a lower security rating in HA, which is documented.
- [Supervisor proxy may not forward HA's MCP endpoint] → Probe with a fallback URL and a documented long-lived token (D13a). Agents still have REST/CLI access regardless.
- [Paseo's skill sync could interfere with user skill links] → Per-skill links plus a manifest (D12). Verify during implementation; fall back to copying user skills if links are removed.
- [Generated instruction files may conflict with Paseo's `appendSystemPrompt` or project `AGENTS.md`] → Global files only. Project-level files in `/homeassistant` are left to the user.
- [Running as root blocks Claude Code's skip-permissions mode] → Documented. Interactive approval still works.
- [Ingress iframe shares origin with HA] → The daemon has no password on ingress, but it is reachable only via HA-authenticated ingress. Paseo-served HTML (agent HTML previews) runs in HA's origin, which is the same trust level as other ingress add-ons. Document it.
- [Large image size] → Keep dependencies minimal and leave extra agents opt-in. Images are pre-built on GHCR (D10), so devices only download them.
- [`version` on `main` ahead of published images → "image not found" on update] → Follow the D10 release order. The publish workflow is fast for amd64/aarch64, but armv7 users may see a delay of up to the length of the QEMU build.
- [GHCR packages left private → anonymous pull fails] → Make the one-time visibility change part of the first-release task and verify it with an anonymous `docker pull`.

## Migration Plan

- New add-on, so nothing to migrate. Rollout: tag the repo, users add the repository URL, install. Rollback: users restore the add-on from an HA backup or reinstall a previous tag. `/data` is forward-compatible because Paseo owns its own state migrations.
