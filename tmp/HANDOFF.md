# Handoff: Paseo Home Assistant add-on (`add-paseo-ha-addon`)

Last updated: 2026-10-02 (working tree state at commit `HEAD` on `main`).

Repo: `D:/paseo-ha-addon` (GitHub: `farajfarook/paseo-ha-addon`), branch `main`.
OpenSpec change: `add-paseo-ha-addon` (spec-driven). Roots: `openspec/changes/add-paseo-ha-addon/`.

## What this change is

A Home Assistant add-on repository that packages the Paseo daemon + web UI, exposes it
through HA Ingress, bundles Pi, optionally installs Claude Code / Codex / OpenCode, and
integrates with Home Assistant.

Progress at handoff: **28 of 55 tasks complete** (was 25 when the parallel lanes landed).

## Ground rules that must not be dropped

- Follow the OpenSpec workflow. Mark a task done only with real evidence; use each task's
  `sourcePath`/`line` from `openspec instructions apply --change add-paseo-ha-addon --json`
  and re-run that command after edits.
- **Never mark a task complete because code was written.** Several tasks need a real Home
  Assistant (see "Needs a real HA" below); leave them unchecked and list them.
- Do not narrow, defer or silently drop specified behavior.
- Shell: bash, LF endings, shellcheck-clean where practical.
- On Windows/Git Bash use `MSYS_NO_PATHCONV=1` for Docker commands with container paths.
- Docker Desktop on Windows needs **native host paths** for bind mounts (`cygpath -m`), not
  `/tmp/...` MSYS paths.

## Current state of the work

### Done and merged (main)

| Area | Files |
|---|---|
| Repo + add-on scaffold | `repository.yaml`, `README.md`, `paseo/config.yaml`, `paseo/build.yaml`, `paseo/translations/en.yaml`, `paseo/icon.png`, `paseo/logo.png` |
| Image build | `paseo/Dockerfile` (Alpine + node, Paseo 0.10.3, Pi 1.0.0, HA CLI, nginx, node-pty rebuilt from source) |
| Runtime core | `paseo/rootfs/etc/s6-overlay/scripts/init-paseo.sh`, `s6-rc.d/init-paseo/*`, `s6-rc.d/paseo/{run,finish,type}`, `usr/local/lib/paseo-ha/common.sh`, hook dir `/etc/paseo-ha/init.d/*.sh` |
| Optional agents | `rootfs/etc/paseo-ha/init.d/20-agents.sh` |
| Agent config + HA integration | `init.d/3*.sh`, `init.d/4*.sh`, `rootfs/opt/paseo-ha/{skills,config-seed,AGENTS.base.md}`, `s6-rc.d/paseo-ha-bootstrap/*`, tests in `paseo/tests/agent-config/` |
| CI | `.github/workflows/{lint,builder,publish}.yaml`, `.github/scripts/{build-args,check-version}.sh`, `paseo/tests/smoke/` |

### Group 5 (ingress adapter) — implemented by the orchestrator, merged, curl-verified

The lane-B subagent stalled (77 min of investigation, no files), was paused, and the
orchestrator wrote the deliverables:

- `paseo/rootfs/opt/paseo-ha/nginx/paseo.conf.tpl` — ingress server on 8099,
  `allow 172.30.32.2; deny all;`, proxy to `127.0.0.1:6767`, WS upgrade,
  `proxy_buffering off`, 3600 s timeouts, 100 MB body, `Host`/`Origin` rewrite,
  `Accept-Encoding ""`, `sub_filter` rules for `/_expo/`, `manifest.json`, favicon,
  apple-touch-icon, pwa icons, `start_url`, plus shim injection before `</head>`.
- `paseo/rootfs/opt/paseo-ha/nginx/render.js` — renders the template in node (escapes the
  password for nginx conf); adds `Authorization: Bearer` and the
  `paseo.bearer.<pw>` WS subprotocol map only when `PASEO_PASSWORD` is set (group 6 seam).
- `paseo/rootfs/etc/paseo-ha/init.d/50-nginx.sh` — renders + `nginx -t` validates.
- `paseo/rootfs/etc/s6-overlay/s6-rc.d/nginx/{run,type,dependencies.d/paseo}` +
  `user/contents.d/nginx` — longrun, starts after the `paseo` service signals readiness.
- `paseo/rootfs/opt/paseo-ha/www/shim.js` — browserside ingress shim: overrides
  `__PASEO_INITIAL_DAEMON_CONNECTION__`, patches `WebSocket`, `fetch`, XHR, `window.open`,
  and maps `history.pushState/replaceState` + wrapped `popstate` listeners so the Expo
  router reads app-relative paths while the address bar keeps the ingress prefix.
- `paseo/rootfs/etc/s6-overlay/scripts/init-paseo.sh` — group 6 direct-port logic added:
  daemon listens on `0.0.0.0:6767` with `PASEO_PASSWORD` only when port 6767 is **mapped
  and** a password is set; otherwise it stays loopback-only and logs a warning.

**Verified** with `bash paseo/tests/smoke/run.sh local/paseo-addon:group5` → all PASS
(health 200 through ingress, prefixed `/_expo/` URLs, shim tag, no bare `"/_expo/`,
WS upgrade 101 on `/ws`, 403 from a non-allowed IP).

Tasks marked complete from that evidence: **5.1, 5.2, 5.4**.

### In progress: `paseo/tests/ingress/` (browser test for 5.3 / 5.5)

- `paseo/tests/ingress/mock-ingress.conf` — mock HA ingress (nginx, `resolver 127.0.0.11`,
  `@TARGET@`/`@PREFIX@` placeholders rendered by run.sh).
- `paseo/tests/ingress/run.sh` — creates network `172.30.32.0/23`, starts the add-on at
  `172.30.33.10` and the mock at `172.30.32.2` (published on a host port), waits for
  health, then runs an inline Playwright script (Edge/Chrome via `playwright-core`).
- Playwright browser binaries are **not** installed; `playwright-core` is installed in
  `/tmp/browsertest` (gitignored) and `run.sh` skips browser checks when it cannot require
  `playwright-core`. Expected to work by launching msedge with `executablePath`.

**Where it stopped:** the last `run.sh` invocations were aborted by the operator before
finishing; the resolver fix is in place but the browser run has not completed yet. Next
step is simply: rebuild the image if needed and run
`bash paseo/tests/ingress/run.sh local/paseo-addon:group5 18081`.

Watch out for:
- `run.sh` looks for `playwright-core` via `node -e "require('playwright-core')"` in the
  repo cwd; if that fails it silently skips the browser part. Run it with
  `PLAYWRIGHT_DIR=/d/paseo-ha-addon/tmp/browsertest` and/or install playwright-core in
  `paseo/tests/browsertest/`.
- The wait loop can take up to `INGRESS_TIMEOUT` (180) × 2 s. Lower it while iterating.

### Version pinning / release docs

- `paseo/CHANGELOG.md` written with the first entry `0.10.3-1` (Paseo 0.10.3, Pi 1.0.0).
- Root `README.md` has `## Releasing` (lane D). A "Bumping Paseo" section (task 7.2) is
  **not written yet**.
- `paseo/DOCS.md` (task 7.1) is **not written yet**; lane B was supposed to own its
  "Known limitations" section, so the next agent owns the whole file.

## OpenSpec task state (what is left)

- **5.3 / 5.5** — shim/browser verification and the click-through. Shim is written;
  needs the browser run above, and any escaping request has to be either handled by a
  generic hook or logged under "Known limitations" in `paseo/DOCS.md`.
- **6.1 / 6.2 / 6.3** — code is in place in `init-paseo.sh` + the nginx render seam. Verify
  by running the image with `-e PASEO_HA_DIRECT_PORT=6767` and a `password` in
  `options.json`, then `curl` the daemon port without a bearer (expect 401) and with
  `Authorization: Bearer <pw>` (expect 200); separately run without the password and check
  the warning plus a refused connection. 6.3 (CLI over the network with a custom hostname)
  is a real-HA / LAN check.
- **7.1 DOCS.md**, **7.2 README "Bumping Paseo"**, **7.3** verify the changelog renders in
  HA (the file exists).
- **8.1–8.5** — CI is implemented but nothing has been pushed/run yet. Push `main`, then
  verify Lint, Builder (3 arches) and the smoke job. For the publish guard, push a
  deliberately mismatched tag such as `v0.0.0-test` (no release is created because the
  guard fails first).
- **Group 9 end-to-end validation** — needs a real HA instance; do not attempt locally.

## Needs a real Home Assistant (stop and report, do not fake)

Supervisor token/`SUPERVISOR_TOKEN`, HA MCP endpoint `/api/mcp`, real ingress browser
behavior in the HA panel/iframe, real folder mappings (`/homeassistant`,
`/addon_configs/<slug>`, `/share`, `/ssl`, `/media`, `/backup`), Pi/agent login
persistence across restarts, armv7 on real hardware, and the "Known limitations" items
that only appear on real hardware.

## Useful commands

```bash
# OpenSpec progress (55 tasks total)
openspec instructions apply --change add-paseo-ha-addon --json

# Build amd64 image (Docker Desktop, Git Bash)
MSYS_NO_PATHCONV=1 docker build -f paseo/Dockerfile \
  --build-arg BUILD_FROM=ghcr.io/home-assistant/amd64-base:latest \
  --build-arg PASEO_VERSION=0.10.3 --build-arg PI_VERSION=1.0.0 \
  --build-arg HA_CLI_VERSION=5.5.0 --build-arg HA_CLI_ARMV7_VERSION=4.46.0 \
  -t local/paseo-addon:group5 paseo

# Curl-level ingress + restricted-IP smoke test
MSYS_NO_PATHCONV=1 bash paseo/tests/smoke/run.sh local/paseo-addon:group5

# Browser ingress test (mock HA ingress + Playwright)
bash paseo/tests/ingress/run.sh local/paseo-addon:group5 18081

# Agent config / HA integration suite
bash paseo/tests/agent-config/run.sh local/paseo-addon:group5
```

## Background that is easy to lose

- **Why nginx + a shim instead of only URL rewriting:** nginx can only rewrite bytes in
  responses. The runtime API/WS URLs and the Expo router's view of `location.pathname`
  exist only in the browser. Prior art doing the same thing (a ~989-line Node proxy with
  HTML/JS regex rewrites and a fetch shim) is
  `magnusoverli/opencode` → `ha_opencode/rootfs/usr/local/bin/openchamber-ingress-proxy.js`.
- **Upstream facts used by the design** (Paseo 0.10.3, `@getpaseo/server`):
  - `dist/server/server/web-ui.js` → `injectConnectionHint()` injects
    `window.__PASEO_INITIAL_DAEMON_CONNECTION__` immediately before `</head>`; it is built
    from the request `Host` (which nginx sets to `127.0.0.1:6767`) and `req.protocol`.
  - The web UI bundle builds absolute URLs `http(s)://<listen>/...` from that hint, and
    sends `protocols: ['paseo.bearer.<token>']` only when it has a credential.
  - `index.html`/JS reference root-absolute `/_expo/...` (including the lazy
    `desktop-attachment-bridge-*.js` worker), `/manifest.json`, `/favicon.ico`,
    `/apple-touch-icon.png`, `/pwa-icon-*.png`, and the manifest's `"start_url": "/"`.
  - The Expo router (react-navigation web history) reads `window.location.pathname` and
    writes app-relative paths through `history.pushState/replaceState`, and re-reads
    location inside `popstate` listeners.
- **Lane status:** A (image), C (agent config + HA), D (CI) completed and merged. B
  (ingress) was paused by `subagent({action:"interrupt", id:"77a960bc-8d06-49c1-a5df-839c725218d2"})`
  and then taken over by the orchestrator. Its worktree and branch
  (`D:/worktrees/paseo-ha-addon/pi-worktree-77a960bc-...`, branch
  `pi-subagents/lane-b-ingress-77a960b-a932-s0-t0`) contain nothing worth keeping.

## Suggested next steps, in order

1. Finish `paseo/tests/ingress/run.sh` (browser) and close out 5.3 / 5.5.
2. Verify 6.1 / 6.2 with the direct-port curl checks.
3. Write `paseo/DOCS.md` (7.1) and the README "Bumping Paseo" section (7.2).
4. Run the agent-config suite and the smoke suite once more against the final image.
5. Commit, push `main`, verify CI (8.1–8.3), check the publish guard with `v0.0.0-test` (8.5).
6. Run a read-only reviewer subagent against all four specs, then produce the final list of
   real-HA validation tasks (group 9) with exact manual test steps.
