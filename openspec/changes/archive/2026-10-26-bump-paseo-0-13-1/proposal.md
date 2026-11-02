## Why

Paseo 0.13.1 is out (stable, 2026-10-26). It fixes a startup crash when Show background is enabled and a project has eight or more workspaces. The add-on bundles 0.13.0, so users only get the fix once the pin moves. HA CLI 5.6.0 and gh 2.103.2 are already current.

## What Changes

- Pin Paseo 0.13.1 in `paseo/build.yaml` and both `ARG PASEO_VERSION` lines of `paseo/Dockerfile`; add-on version `0.13.1-1` in `paseo/config.yaml`.
- CHANGELOG entry naming the bundled Paseo **0.13.1** and Pi **1.4.0**.

The add-on's specified behaviour is unchanged: nothing under `paseo/rootfs/` changes.

- `paseo-anchors.sh --diff 0.13.0 0.13.1`: anchors unchanged. `paseo-anchors.sh --check 0.13.1`: all ingress anchors present.
- `check-providers.sh 0.13.1`: built-in `claude codex copilot omp opencode pi`, plugin `antigravity hoplite muse`, hoplite excluded; the providers option matches.
- `npm pack` diff of `@getpaseo/server` 0.13.0 → 0.13.1: `dist/server/server/**` (including `web-ui.js`) is byte-identical; `web-ui/index.html` only changes the entry bundle hash in its `<script src="/_expo/static/js/web/index-<hash>.js">` (still root-absolute, rewritten by nginx `sub_filter '"/_expo/'`); the rest is version strings in `package.json` files.
- Release notes: no breaking, removed or changed entries.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None (pin-only bump, `skip_specs`, AGENTS.md Rule 1.4).

## Impact

- `paseo/build.yaml`, `paseo/Dockerfile`, `paseo/config.yaml`, `paseo/CHANGELOG.md`.
- Published images `ghcr.io/farajfarook/{amd64,aarch64}-addon-paseo:0.13.1-1`.
