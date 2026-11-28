## Why

Paseo 0.18.1 is out (stable, npm `latest`, tag `v0.18.1`). It adds host-wide metadata instructions (one setting that guides the language, tone and formatting of generated workspace titles, branch names, commit messages and pull requests) and shows Claude extra-usage spending and Codex individual spending limits in Usage. It fixes, among others, messages sent while Pi runs a self-started turn failing instead of queuing, stuck OpenCode v2 tool approvals, idle ACP agents failing permanently after their process exits, Mark as read not clearing finished terminal attention, Command Center results reordering while typing, Kimi usage for global `kimi.ai` accounts and the Z.ai Usage card with `Z_AI_API_KEY`. The add-on bundles Paseo 0.18.0, so users only get these once the pin moves.

Pi 1.7.0 is the latest stable Pi (installed on start when selected, not bundled); `ha` 6.0.0 and `gh` 2.106.0 are already current.

## What Changes

- Pin Paseo 0.18.1 in `paseo/build.yaml` and both `ARG PASEO_VERSION` lines of `paseo/Dockerfile`; add-on version `0.18.1-1` in `paseo/config.yaml`.
- CHANGELOG entry naming the bundled Paseo **0.18.1** with its user-visible highlights and the Pi release current at release time (**1.7.0**; installed on start when selected, not bundled in the image).

The bump does not change the add-on's specified behaviour (nothing under `paseo/rootfs/` changes; AGENTS.md Rule 1.4). There are no companion changes. Checks:

- `paseo-anchors.sh --diff 0.18.0 0.18.1`: anchors unchanged. `paseo-anchors.sh --check 0.18.1`: all ingress anchors present.
- `check-providers.sh 0.18.1`: built-in `claude codex copilot omp opencode pi`, plugin `antigravity fx goose hermes hoplite muse`, hoplite excluded; the providers option matches. The set of bundled plugins is unchanged.
- `npm pack` diff of `@getpaseo/server` 0.18.0 → 0.18.1: `dist/server/server/web-ui.js` is byte-identical; `web-ui/index.html` changes only the entry bundle hash. The set of `PASEO_*` names the server reads is identical. The daemon config gains an optional `metadataGeneration.instructions` string (`persisted-config.js`, `daemon-config-store.js`, `bootstrap.js`), which the add-on does not write, and `websocket-server.js` only advertises the matching capability. Other server changes are inside the ACP, OMP, OpenCode v2 and Pi providers, the usage-source plugins (Claude, Codex, Kimi, Z.ai), push notifications, git metadata generation and the GitLab service. No HTTP route, port, listener or `/ws` handling changes.
- `@getpaseo/cli`: only `package.json` changes, so the `paseo daemon run/stop/config` and `paseo provider ls` commands the add-on uses are unchanged.
- Release notes: no breaking, removed, changed or `### Notes` entries; one plugin-SDK addition (OMP tool-call intent in timeline metadata) that the add-on does not use.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None (`skip_specs`, AGENTS.md Rule 1.4).

## Impact

- `paseo/build.yaml`, `paseo/Dockerfile`, `paseo/config.yaml` (`version`), `paseo/CHANGELOG.md`.
- Published images `ghcr.io/farajfarook/{amd64,aarch64}-addon-paseo:0.18.1-1`.
