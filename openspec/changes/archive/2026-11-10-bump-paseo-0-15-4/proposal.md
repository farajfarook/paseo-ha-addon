## Why

Paseo 0.15.4 is out (stable, 2026-11-10). It adds the Claude Fable 5.2 and Mythos 5.2 models (medium default effort) to the Claude provider's model list. The add-on bundles 0.15.3, so users only get the new models once the pin moves. Pi 1.5.1 is the latest stable Pi (installed on start when selected); HA CLI 5.6.0 and gh 2.103.3 are already current.

## What Changes

- Pin Paseo 0.15.4 in `paseo/build.yaml` and both `ARG PASEO_VERSION` lines of `paseo/Dockerfile`; add-on version `0.15.4-1` in `paseo/config.yaml`.
- CHANGELOG entry naming the bundled Paseo **0.15.4** and the Pi release current at release time (**1.5.1**; Pi is installed on start when selected, not bundled in the image).

The bump does not change the add-on's specified behaviour (nothing under `paseo/rootfs/` changes; anchors and providers checked below). There are no companion changes.

- `paseo-anchors.sh --diff 0.15.3 0.15.4`: anchors unchanged. `paseo-anchors.sh --check 0.15.4`: all ingress anchors present.
- `check-providers.sh 0.15.4`: providers `antigravity claude codex copilot muse omp opencode pi`, hoplite excluded; the providers option matches.
- `npm pack` diff of `@getpaseo/server` 0.15.3 → 0.15.4: only the Claude provider's `model-manifest.{js,d.ts}` (two new models, Fable 5.1 relabelled "Previous release") and `feature-definitions.js` (the fast-mode description no longer says "Opus"), `package.json` (version and dependency pins), `builtin-plugins/package.json` (version) and the web UI entry bundle change. `dist/server/server/web-ui.js` is byte-identical. `web-ui/index.html` only changes the entry bundle hash in its root-absolute `<script src="/_expo/static/js/web/index-<hash>.js">` (rewritten by nginx `sub_filter '"/_expo/'`). The `PASEO_*` environment variable names are unchanged.
- `@getpaseo/cli`, `@getpaseo/protocol`, `@getpaseo/relay`, `@getpaseo/plugin` and `@getpaseo/client` 0.15.3 → 0.15.4: only `package.json` changes, so the `paseo daemon ...` and `paseo provider ls` commands the add-on uses are unchanged.
- Release notes: no breaking, removed or changed entries. The one upgrade note says both new models need Claude Code 2.1.321 or newer and Mythos 5.2 only appears when Claude Code advertises access. The add-on installs `@anthropic-ai/claude-code` at its latest stable release on every start (`20-providers.sh`, no `PACKAGE_HOLD`), which is 2.1.322 at release time, so a restart after the update already meets the requirement; nothing to change and nothing for users to do beyond the normal restart.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None (pin-only bump, `skip_specs`, AGENTS.md Rule 1.4).

## Impact

- `paseo/build.yaml`, `paseo/Dockerfile`, `paseo/config.yaml`, `paseo/CHANGELOG.md`.
- Published images `ghcr.io/farajfarook/{amd64,aarch64}-addon-paseo:0.15.4-1`.
