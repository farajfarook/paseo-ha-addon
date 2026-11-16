## Why

Paseo 0.16.0 is out (stable, 2026-11-16). It adds background tasks above the composer (Claude Code, Codex, OpenCode v2), a built-in plugin gallery, command center tabs, plugin sidebar views and composer controls, undo for workspace archive, a Change base picker for worktree diffs, background agents, faster diff loading, a rebuilt mobile chat, the fx provider, and many fixes (Claude, Codex, OpenCode, Pi and ACP agents, terminals, schedules, voice mode with OpenAI speech). The add-on bundles 0.15.4, so users only get these once the pin moves. Pi 1.5.2 is the latest stable Pi (installed on start when selected); HA CLI 5.7.0 and gh 2.104.0 are already current.

## What Changes

- Pin Paseo 0.16.0 in `paseo/build.yaml` and both `ARG PASEO_VERSION` lines of `paseo/Dockerfile`; add-on version `0.16.0-1` in `paseo/config.yaml`.
- CHANGELOG entry naming the bundled Paseo **0.16.0** and the Pi release current at release time (**1.5.2**; Pi is installed on start when selected, not bundled in the image), the new `fx` provider from the `add-fx-provider` change, the vendor-installer download fix from the `fix-vendor-installer-download` change, and the upstream note that the Paseo apps need updating too for the new features.

The bump itself does not change the add-on's specified behaviour (anchors checked below). Paseo 0.16.0 does add a provider, fx, which the `providers` option must list for CI's provider check to pass: that is its own change in the same PR, `add-fx-provider` (fx as a vendor-installed provider, `agent-providers` spec delta, providers test). Checking fx live on the 0.16.0 image showed that no vendor installer could ever be downloaded (npm-only options passed to curl, since 0.11.1-1); that fix is a third change, `fix-vendor-installer-download`.

- `paseo-anchors.sh --diff 0.15.4 0.16.0`: anchors unchanged. `paseo-anchors.sh --check 0.16.0`: all ingress anchors present.
- `check-providers.sh 0.16.0`: built-in `claude codex copilot omp opencode pi`, plugin `antigravity fx hoplite muse`, hoplite excluded; fails with the 0.15.4 option (fx missing) and passes with the option from `add-fx-provider`.
- `npm pack` diff of `@getpaseo/server` 0.15.4 → 0.16.0 (289 files outside the web UI chunks changed; it is a minor release):
  - `dist/server/server/web-ui.js`: the only change is that `/.well-known` and `/.well-known/*` requests the web UI does not serve now get a JSON 404 instead of the SPA's `index.html` (upstream #8622, for MCP OAuth discovery). `injectConnectionHint` and the hint's `listen`/`useTls`/`label` handling are unchanged, so `shim.js` and `nginx/paseo.conf.tpl` are unaffected: nginx proxies every path under the ingress prefix to the daemon, and the add-on serves nothing under `/.well-known`.
  - `web-ui/index.html`: the entry bundle hash in its root-absolute `<script src="/_expo/static/js/web/index-<hash>.js">` (rewritten by nginx `sub_filter '"/_expo/'`) and an inline focus-ring style that now reads the theme's `--colors-ring` CSS variable. No new root-absolute paths.
  - The set of `PASEO_*` names the server reads is identical (118 names); every variable the add-on sets is still read.
  - Persisted config schema: only an optional `options` record added to agent profile entries. The add-on writes only `agents.providers` and `worktrees.root` through `paseo daemon config`.
  - New bundled plugin `fx-provider` (see `add-fx-provider`); `provider-registry.js` still registers a configuration-required plugin provider once its `agents.providers.<id>` override exists, which is how Hoplite stays unregistered (the add-on never writes its override).
- `@getpaseo/cli` 0.15.4 → 0.16.0: only the `agent archive/detach/logs/ls/reload/wait` commands and agent-ID resolution change (`utils/client.js`: a full agent UUID no longer falls back to a name search). The `paseo daemon run/status/stop/config` commands the add-on uses are unchanged.
- Release notes, checked against the add-on (`grep -rn` over `paseo/rootfs` and `paseo/Dockerfile`):
  - Breaking: the deprecated `agent.turn.after.timeline` plugin SDK field is removed. The add-on ships no Paseo plugin, so nothing uses it.
  - Changed: thirteen UI/behaviour changes (workspace tab restore, question cards, slash menu, Claude Bypass and permission reasons, Pi agents with an exited process failing immediately, macOS shortcuts, ...). None names a command, flag, config key, environment variable, port, path or provider loading the add-on relies on.
  - Notes: "Update both the host and app" for the new features - the add-on serves the web UI that matches the bundled daemon; users of the Paseo desktop/mobile apps need the app update too (CHANGELOG line). The plugin-author note (same SDK field) does not apply. "Archive undo restores the workspace, not uncommitted files removed with its worktree" is upstream behaviour with no add-on hook.
  - The plugin gallery installs plugins with npm under `$PASEO_HOME` (`/data/home/.paseo`, persistent); the image has npm and the add-on does not restrict plugins.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None for the bump itself (`skip_specs`, AGENTS.md Rule 1.4). The companion change `add-fx-provider` carries the `agent-providers` spec delta; `fix-vendor-installer-download` restores already-specified behaviour (`skip_specs`).

## Impact

- `paseo/build.yaml`, `paseo/Dockerfile`, `paseo/config.yaml` (`version`), `paseo/CHANGELOG.md`.
- Published images `ghcr.io/farajfarook/{amd64,aarch64}-addon-paseo:0.16.0-1`.
