## Why

Paseo 0.17.3 is out (stable), together with 0.17.2 since the last bump. 0.17.2 adds per-turn and session stats (timing, tokens, cache, cost) for Claude, OpenCode v2, Pi, Oh My Pi and plugin providers, background model-list refresh every 30 minutes for enabled providers, the sidebar usage summary on by default, provider docs links and fuller diagnostic reports, Archive workspace on mobile, and fixes (stale `/exit` in the slash menu archiving an agent, busy host connections dropping, Antigravity turns staying running after creating a schedule, zombie child processes from local directory plugins). 0.17.3 fixes iPhone sheets, Antigravity thinking levels blocking Orchestrator chats, and the `/` and `@` pickers disappearing after history navigation. The add-on bundles Paseo 0.17.1, so users only get these once the pin moves. Pi 1.6.0 is the latest stable Pi (installed on start when selected, not bundled); `ha` 6.0.0 and gh 2.105.0 are already current.

## What Changes

- Pin Paseo 0.17.3 in `paseo/build.yaml` and both `ARG PASEO_VERSION` lines of `paseo/Dockerfile`; add-on version `0.17.3-1` in `paseo/config.yaml`.
- CHANGELOG entry naming the bundled Paseo **0.17.3** with its user-visible highlights and the Pi release current at release time (**1.6.0**; installed on start when selected, not bundled in the image).

The bump itself does not change the add-on's specified behaviour. One companion change ships in the same PR: `fix-provider-check-bundle-parsing` (CI tooling, `skip_specs`), without which `check-providers.sh` cannot read 0.17.3's provider definitions. Checks:

- `paseo-anchors.sh --diff 0.17.1 0.17.3`: anchors unchanged. `paseo-anchors.sh --check 0.17.3`: all ingress anchors present.
- `check-providers.sh 0.17.3` (with the companion fix): built-in `claude codex copilot omp opencode pi`, plugin `antigravity fx goose hoplite muse`, hoplite excluded and still `requiresConfiguration: true`; the providers option matches unchanged.
- `npm pack` diff of `@getpaseo/server` 0.17.1 → 0.17.3: `dist/server/server/web-ui.js` is byte-identical; `web-ui/index.html` changes only the entry bundle hash in its root-absolute `<script src="/_expo/static/js/web/index-<hash>.js">` (rewritten by nginx `sub_filter '"/_expo/'`). The set of `PASEO_*` names the server reads is identical, and the bundled plugin list is identical (plugin providers only gain `docsUrl`; Antigravity gains SSH sign-in diagnostics and per-model thinking options). Server changes are inside the agent manager, agent messages (new `queue` active-turn behaviour), the Claude/OMP/OpenCode/Pi providers, provider snapshot and background refresh, plugin process handling (zombie reaping), usage sources and the bundled Paseo agent skill. `bootstrap.js` gains a `lazyTerminalWorker` option, but only the test utilities set it; the daemon still launches the terminal worker eagerly.
- `@getpaseo/cli` changes only `agent send` (new `--behavior queue`) and `package.json`, so the `paseo daemon run/status/stop/config` and `paseo provider ls` commands the add-on uses are unchanged.
- Release notes: no breaking, removed or `### Notes` entries; the one "Changed" entry removes an OpenCode v2 info row from chats. None of it names a command, flag, config key, environment variable, port, path or provider loading the add-on relies on.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None (`skip_specs`, AGENTS.md Rule 1.4).

## Impact

- `paseo/build.yaml`, `paseo/Dockerfile`, `paseo/config.yaml` (`version`), `paseo/CHANGELOG.md`.
- Published images `ghcr.io/farajfarook/{amd64,aarch64}-addon-paseo:0.17.3-1`.
