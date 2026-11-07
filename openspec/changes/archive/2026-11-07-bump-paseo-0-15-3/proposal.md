## Why

Paseo 0.15.3 is out (stable, 2026-11-06). It fixes conversation text becoming blurred when the keyboard opens or closes on iOS 26 and later. The add-on bundles 0.15.2, so users only get the fix once the pin moves. Pi 1.5.0 is still the latest stable Pi (installed on start when selected); HA CLI 5.6.0 and gh 2.103.3 are already current.

## What Changes

- Pin Paseo 0.15.3 in `paseo/build.yaml` and both `ARG PASEO_VERSION` lines of `paseo/Dockerfile`; add-on version `0.15.3-1` in `paseo/config.yaml`.
- CHANGELOG entry naming the bundled Paseo **0.15.3** and the Pi release current at release time (**1.5.0**; Pi is installed on start when selected, not bundled in the image).

The bump does not change the add-on's specified behaviour (nothing under `paseo/rootfs/` changes; anchors and providers checked below). There are no companion changes.

- `paseo-anchors.sh --diff 0.15.2 0.15.3`: anchors unchanged. `paseo-anchors.sh --check 0.15.3`: all ingress anchors present.
- `check-providers.sh 0.15.3`: built-in `claude codex copilot omp opencode pi`, plugin `antigravity hoplite muse`, hoplite excluded; the providers option matches.
- `npm pack` diff of `@getpaseo/server` 0.15.2 → 0.15.3: every server file is byte-identical, including `dist/server/server/web-ui.js`; only `package.json` (version and dependency pins), `builtin-plugins/package.json` (version) and the web UI entry bundle change. `web-ui/index.html` only changes the entry bundle hash in its root-absolute `<script src="/_expo/static/js/web/index-<hash>.js">` (rewritten by nginx `sub_filter '"/_expo/'`). The `PASEO_*` environment variable names are unchanged.
- `@getpaseo/cli`, `@getpaseo/protocol`, `@getpaseo/relay`, `@getpaseo/plugin` and `@getpaseo/client` 0.15.2 → 0.15.3: only `package.json` changes, so the `paseo daemon ...` and `paseo provider ls` commands the add-on uses are unchanged.
- Release notes: no breaking, removed or changed entries and no upgrade notes. The fix is in the web UI bundle served through the existing ingress adapter; the ingress browser suite runs against the new bundle.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None (pin-only bump, `skip_specs`, AGENTS.md Rule 1.4).

## Impact

- `paseo/build.yaml`, `paseo/Dockerfile`, `paseo/config.yaml`, `paseo/CHANGELOG.md`.
- Published images `ghcr.io/farajfarook/{amd64,aarch64}-addon-paseo:0.15.3-1`.
