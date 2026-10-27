## Why

Paseo 0.13.2 is out (stable, 2026-10-26). It fixes repeated Android animation exceptions and a background animation loop, stops finished Android chat messages being remeasured while streaming, and fixes bottom sheets keeping window-size listeners after they close. The add-on bundles 0.13.1, so users only get the fixes once the pin moves. gh 2.103.3 is also out (a `gh auth status` message fix); HA CLI 5.6.0 is already current.

## What Changes

- Pin Paseo 0.13.2 in `paseo/build.yaml` and both `ARG PASEO_VERSION` lines of `paseo/Dockerfile`; pin gh 2.103.3 in `paseo/build.yaml` and `paseo/Dockerfile`; add-on version `0.13.2-1` in `paseo/config.yaml`.
- CHANGELOG entry naming the bundled Paseo **0.13.2** and Pi **1.4.0**.

The add-on's specified behaviour is unchanged: nothing under `paseo/rootfs/` changes.

- `paseo-anchors.sh --diff 0.13.1 0.13.2`: anchors unchanged. `paseo-anchors.sh --check 0.13.2`: all ingress anchors present.
- `check-providers.sh 0.13.2`: built-in `claude codex copilot omp opencode pi`, plugin `antigravity hoplite muse`, hoplite excluded; the providers option matches.
- `npm pack` diff of `@getpaseo/server` 0.13.1 → 0.13.2: `dist/server/server/**` (including `web-ui.js`) is byte-identical; `web-ui/index.html` only changes the entry bundle hash in its `<script src="/_expo/static/js/web/index-<hash>.js">` (still root-absolute, rewritten by nginx `sub_filter '"/_expo/'`); the rest is version strings in `package.json` files.
- Release notes: no breaking, removed or changed entries.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None (pin-only bump, `skip_specs`, AGENTS.md Rule 1.4).

## Impact

- `paseo/build.yaml`, `paseo/Dockerfile`, `paseo/config.yaml`, `paseo/CHANGELOG.md`.
- Published images `ghcr.io/farajfarook/{amd64,aarch64}-addon-paseo:0.13.2-1`.
