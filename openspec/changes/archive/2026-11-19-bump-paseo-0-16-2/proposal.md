## Why

Paseo 0.16.2 is out (stable), a bug-fix release on top of 0.16.1: agents no longer get stuck after a second Stop when the provider reuses the cancelled turn ID, Steer no longer cancels a Claude compaction in progress, Collapse turns no longer hides a finished Claude reply, archiving a workspace no longer loses detached worktree commits, worktree creation no longer times out scanning large ignored folders, failed file downloads no longer take over the web UI, plus Desktop and Hub fixes. The add-on bundles Paseo 0.16.1, so users only get these once the pin moves. Pi 1.5.2 is the latest stable Pi (installed on start when selected, not bundled); `ha` 6.0.0 and gh 2.105.0 are already current.

## What Changes

- Pin Paseo 0.16.2 in `paseo/build.yaml` and both `ARG PASEO_VERSION` lines of `paseo/Dockerfile`; add-on version `0.16.2-1` in `paseo/config.yaml`.
- CHANGELOG entry naming the bundled Paseo **0.16.2** with its user-visible fixes and the Pi release current at release time (**1.5.2**; installed on start when selected, not bundled in the image).

The bump does not change the add-on's specified behaviour (AGENTS.md Rule 1.4: pin-only bump). No companion change ships in this PR. Checks:

- `paseo-anchors.sh --diff 0.16.1 0.16.2`: anchors unchanged. `paseo-anchors.sh --check 0.16.2`: all ingress anchors present.
- `check-providers.sh 0.16.2`: built-in `claude codex copilot omp opencode pi`, plugin `antigravity fx hoplite muse`, hoplite excluded; the providers option matches.
- `npm pack` diff of `@getpaseo/server` 0.16.1 → 0.16.2: `dist/server/server/web-ui.js` is byte-identical; `web-ui/index.html` changes only the entry bundle hash in its root-absolute `<script src="/_expo/static/js/web/index-<hash>.js">` (rewritten by nginx `sub_filter '"/_expo/'`). The set of `PASEO_*` names the server reads is identical. Other server changes: agent manager and Claude/OMP providers (stop/turn-ID and compaction fixes), workspace archive/git/registry and `worktree-include` (detached commits, ignored-folder scan), Hub relationship controller, file observer, and the terminal worker, which now tries the next socket directory when a filesystem refuses a Unix socket bind (`EPERM`/`EACCES`/`EOPNOTSUPP`), a more tolerant fallback that does not change where it listens on the add-on's `/data` home. `bootstrap.js`/`websocket-server.js` share one origin check (`isDaemonOriginAllowed`) between the `/ws` upgrade and HTTP CORS: the WebSocket rule (allow-list, `*` or same origin) is unchanged, and the HTTP CORS header is now also sent for same-origin requests. The ingress path (`/ws` through nginx with the rewritten Host) is unaffected; the ingress browser suite covers it.
- `@getpaseo/cli` changes only `commands/workspace/create.js` and `package.json`, so the `paseo daemon run/status/stop/config` and `paseo provider ls` commands the add-on uses are unchanged; `@getpaseo/{protocol,relay,plugin,client}` change only `package.json`.
- Release notes: ten fixes, no breaking, removed or changed entries and no `### Notes` section, so nothing names a command, flag, config key, environment variable, port, path or provider loading the add-on relies on.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None (`skip_specs`, AGENTS.md Rule 1.4).

## Impact

- `paseo/build.yaml`, `paseo/Dockerfile`, `paseo/config.yaml` (`version`), `paseo/CHANGELOG.md`.
- Published images `ghcr.io/farajfarook/{amd64,aarch64}-addon-paseo:0.16.2-1`.
