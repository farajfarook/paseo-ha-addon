## Why

Paseo 0.13.0 is out (stable, 2026-10-24). It adds connected hosts (agents can create, prompt and monitor agents on other machines), an All changes view in the Changes pane, and pasting images or dropping files into terminals, and it fixes agents showing as running after a daemon restart and large Claude sessions showing an empty chat or crashing the daemon. The add-on bundles 0.12.0, so users only get these once the pin moves. The bundled GitHub CLI also has a new release (2.103.0 → 2.103.2).

## What Changes

- Pin Paseo 0.13.0 in `paseo/build.yaml` and both `ARG PASEO_VERSION` lines of `paseo/Dockerfile`; gh 2.103.2 in the same files (HA CLI 5.6.0 is current); add-on version `0.13.0-1` in `paseo/config.yaml`.
- CHANGELOG entry naming the bundled Paseo **0.13.0** and Pi **1.4.0**.

The add-on's specified behaviour is unchanged: nothing under `paseo/rootfs/` changes. Checked with the companion change `fix-anchor-bundle-selection`, which makes the CI scripts read the entry bundle that `index.html` loads (0.13.0 added a lazy `index-<hash>.js` chunk that the old glob picked instead):

- `paseo-anchors.sh --check 0.13.0`: all ingress anchors present. `check-providers.sh 0.13.0`: built-in `claude codex copilot omp opencode pi`, plugin `antigravity hoplite muse`, hoplite excluded; the providers option matches.
- `paseo-anchors.sh --diff 0.12.0 0.13.0` moves two counts, both compatible:
  - `index.html: "/_expo/` 2 → 3: the same three URLs as before (xterm css preload, xterm css stylesheet, entry script); the two css `<link>` tags are now on separate lines and `grep -c` counts lines. They stay root-absolute and `</head>` is still there, so nginx's `sub_filter '"/_expo/'` and the shim injection before `</head>` apply unchanged.
  - `bundle: "/_expo/` 1 → 2: the new lazy chunk's path `"/_expo/static/js/web/index-3c04….js"` sits in its own `paths` map on another line, in the same root-absolute form as the existing attachment-store chunk paths, so `sub_filter '"/_expo/'` prefixes it with the ingress path. The chunk itself (a ZXing barcode-detector polyfill) only fetches its wasm from an absolute `https://fastly.jsdelivr.net/` URL.
  - `web-ui.js` is byte-identical; `bootstrap.js` keeps `app.use("/public")` and `GET /api/health`; `daemon-endpoints.js` only adds a `security` parameter to relay connection URIs, and `buildDaemonWebSocketUrl` and the `/ws` path are unchanged.
- Release notes: no breaking, removed or changed entries. The plugin API additions (file panels, plugin translations, `@getpaseo/plugin/client/ui`) do not touch the add-on.

The companion change `fix-ingress-browser-suite` lets the ingress browser suite run on Linux, which this bump runs because an anchor count moved.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None (pin-only bump, `skip_specs`, AGENTS.md Rule 1.4).

## Impact

- `paseo/build.yaml`, `paseo/Dockerfile`, `paseo/config.yaml`, `paseo/CHANGELOG.md`.
- Published images `ghcr.io/farajfarook/{amd64,aarch64}-addon-paseo:0.13.0-1`.
