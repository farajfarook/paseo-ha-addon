## Why

Paseo 0.17.4 is out (stable). It is a bug-fix release: numbered sublists and quotes in lists no longer overlap on Android, Android terminal input asks the keyboard not to learn typed text, conversations no longer disappear when directory capitalization differs on a case-insensitive file system, interrupt and steer messages to archived agents start a turn again, Hermes Shell rows show the whole command, OpenCode Go usage works for logins in the OpenCode 2 database, existing OpenCode sessions reopen after Paseo tool definitions change, Paseo tools reach agents that use MCP protocol version `2026-07-28`, Codex MCP startup failures reach the daemon warning log, and the daemon no longer exits when it closes a session after the plugin process has stopped. It also ships Hermes (Nous Research's Hermes Agent) as a bundled plugin provider. The add-on bundles Paseo 0.17.3, so users only get these once the pin moves. Pi 1.6.0 is the latest stable Pi (installed on start when selected, not bundled); `ha` 6.0.0 and gh 2.105.0 are already current.

## What Changes

- Pin Paseo 0.17.4 in `paseo/build.yaml` and both `ARG PASEO_VERSION` lines of `paseo/Dockerfile`; add-on version `0.17.4-1` in `paseo/config.yaml`.
- CHANGELOG entry naming the bundled Paseo **0.17.4** with its user-visible highlights and the Pi release current at release time (**1.6.0**; installed on start when selected, not bundled in the image).

The bump itself does not change the add-on's specified behaviour. One companion change ships in the same PR: `add-hermes-provider` (`agent-providers` spec delta), without which `check-providers.sh` fails for 0.17.4 because the pinned Paseo's new bundled `hermes` provider is missing from the `providers` option. Checks:

- `paseo-anchors.sh --diff 0.17.3 0.17.4`: anchors unchanged. `paseo-anchors.sh --check 0.17.4`: all ingress anchors present.
- `check-providers.sh 0.17.4`: built-in `claude codex copilot omp opencode pi`, plugin `antigravity fx goose hermes hoplite muse`, hoplite excluded and still `requiresConfiguration: true`; with the companion change the providers option matches (and still fails for 0.17.3, which has no `hermes`).
- `npm pack` diff of `@getpaseo/server` 0.17.3 → 0.17.4: `dist/server/server/web-ui.js` is byte-identical; `web-ui/index.html` changes only the entry bundle hash in its root-absolute `<script src="/_expo/static/js/web/index-<hash>.js">` (rewritten by nginx `sub_filter '"/_expo/'`). The set of `PASEO_*` names the server reads is identical. New: the `hermes-provider` bundled plugin, and `goose`/`hermes` share one migration of legacy hand-written `extends: "acp"` provider entries to the bundled plugin (`persisted-config.js`, `plugin-provider.js`). Other server changes: the agent MCP endpoint moves to `@modelcontextprotocol/server`'s stateless handler (both protocol eras), plugin session close no longer throws when the plugin process is gone, Codex app-server transport and OpenCode bridge fixes, git repository discovery and worktree helpers, and the OpenCode Go usage source.
- `@getpaseo/cli` changes only `package.json`, so the `paseo daemon run/status/stop/config` and `paseo provider ls` commands the add-on uses are unchanged.
- Release notes: no breaking, removed, changed or `### Notes` entries. None of the fixes names a command, flag, config key, environment variable, port, path or provider loading the add-on relies on; the Hermes provider is handled by the companion change.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None (`skip_specs`, AGENTS.md Rule 1.4).

## Impact

- `paseo/build.yaml`, `paseo/Dockerfile`, `paseo/config.yaml` (`version`), `paseo/CHANGELOG.md`.
- Published images `ghcr.io/farajfarook/{amd64,aarch64}-addon-paseo:0.17.4-1`.
