## Why

Paseo 0.12.0 is out (stable, 2026-10-19). It adds background workspaces, a Send feedback button in the diff pane, a fullscreen composer on phones and `paseo usage`, and fixes plugin hosts and the daemon growing to about 1 GB of memory and running out of memory during long OpenCode replies. The add-on bundles 0.11.4, so users only get these once the pin moves. The bundled HA CLI (5.5.0 → 5.6.0) and GitHub CLI (2.102.0 → 2.103.0) also have new releases.

## What Changes

- Pin Paseo 0.12.0 in `paseo/build.yaml` and both `ARG PASEO_VERSION` lines of `paseo/Dockerfile`; HA CLI 5.6.0 and gh 2.103.0 in the same files; add-on version `0.12.0-1` in `paseo/config.yaml`.
- CHANGELOG entry naming the bundled Paseo **0.12.0** and Pi **1.3.0**.

No change under `paseo/rootfs/` beyond the version pins. One ingress anchor count changed (`useTls` in `web-ui.js`, 2 → 3): `injectConnectionHint` now appends the scheme's default port when the Host header has none. The hint keeps its shape (`listen`, `useTls`, `label`), its global and its place before `</head>`. Under ingress nginx sends `Host: 127.0.0.1:6767`, which has an explicit port, and `shim.js` overwrites the hint with the browser's host and the same default-port rule, so the adapter is unaffected.

The 0.12.0 breaking notes (`paseo run --background` deprecated, `paseo permit allow/deny` exit codes) name commands the add-on does not use.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None (pin-only bump, `skip_specs`).

## Impact

- `paseo/build.yaml`, `paseo/Dockerfile`, `paseo/config.yaml`, `paseo/CHANGELOG.md`.
- Published images `ghcr.io/farajfarook/{amd64,aarch64}-addon-paseo:0.12.0-1`.
