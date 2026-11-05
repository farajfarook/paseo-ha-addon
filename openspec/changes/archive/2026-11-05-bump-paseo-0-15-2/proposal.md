## Why

Paseo 0.15.1 and 0.15.2 are out (stable, both 2026-11-05). 0.15.1 lets the daemon start without terminals when its terminal worker cannot read its own process identity, instead of not starting at all. 0.15.2 adds a first-run setup on web and desktop (theme, providers, projects, agent orchestration, mobile app; Settings → General → Show setup again reopens it), project suggestions from the folders where Claude Code, Codex, OpenCode or Pi ran, a tile grid theme picker and skeleton rows while Providers settings load. The add-on bundles 0.15.0, so users only get these once the pin moves. Pi 1.5.0 is still the latest stable Pi (the add-on installs the latest Pi at build time); HA CLI 5.6.0 and gh 2.103.3 are already current.

## What Changes

- Pin Paseo 0.15.2 in `paseo/build.yaml` and both `ARG PASEO_VERSION` lines of `paseo/Dockerfile`; add-on version `0.15.2-1` in `paseo/config.yaml`.
- CHANGELOG entry naming the bundled Paseo **0.15.2** and Pi **1.5.0**.

The bump does not change the add-on's specified behaviour (nothing under `paseo/rootfs/` changes; anchors and providers checked below). There are no companion changes.

- `paseo-anchors.sh --diff 0.15.0 0.15.2`: anchors unchanged. `paseo-anchors.sh --check 0.15.2`: all ingress anchors present.
- `check-providers.sh 0.15.2`: built-in `claude codex copilot omp opencode pi`, plugin `antigravity hoplite muse`, hoplite excluded; the providers option matches.
- `npm pack` diff of `@getpaseo/server` 0.15.0 → 0.15.2: `dist/server/server/web-ui.js` is byte-identical; `web-ui/index.html` only changes the entry bundle hash in its root-absolute `<script src="/_expo/static/js/web/index-<hash>.js">` (rewritten by nginx `sub_filter '"/_expo/'`). The server's set of `PASEO_*` environment variable names is unchanged. Other server changes are additive: a `project.suggestions` request (new `project-suggestions.js`, a `projectSuggestions` capability flag and its `workspace.read` permission), session-import helpers for it, and the 0.15.1 terminal worker change (a worker that fails to start is logged and retried on the first terminal creation instead of failing daemon start). The add-on keeps `procps-ng` from 0.15.0-1, so its terminal worker still starts; smoke check f) proves terminals survive a daemon restart.
- `@getpaseo/cli` 0.15.0 → 0.15.2: only `package.json` (version and dependency pins) changes, so the `paseo daemon ...` and `paseo provider ls` commands the add-on uses are unchanged.
- Release notes: no breaking, removed or changed entries and no upgrade notes. The first-run setup and project suggestions are web UI features served through the existing ingress adapter; the ingress browser suite runs against the new bundle.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None (pin-only bump, `skip_specs`, AGENTS.md Rule 1.4).

## Impact

- `paseo/build.yaml`, `paseo/Dockerfile`, `paseo/config.yaml`, `paseo/CHANGELOG.md`.
- Published images `ghcr.io/farajfarook/{amd64,aarch64}-addon-paseo:0.15.2-1`.
