## Why

Paseo 0.18.0 is out (stable, npm `latest`, tag `v0.18.0`), and with it 0.17.6 from the same day. 0.18.0 adds per-device notification preferences (agent, terminal and plugin events; plugins can send notifications), optional system prompts on agent profiles, syntax highlighting for diff/patch files and many more languages, and a browser proxy for Paseo Desktop tabs in remote workspaces. ACP plugin providers now cache their model catalogs on disk across daemon restarts instead of probing in the background, and the Antigravity provider drops its `--disable-telemetry` flag and needs Antigravity CLI 1.5.1 or later. 0.17.6 reorganises Settings into Device and Host sections, adds arrow-key navigation to the model picker, removes the Antigravity usage source that ran `agy -p /usage` in the background, and fixes, among others, OpenCode v2 agents staying Running after Stop, steering a self-started Pi run, PR workspaces in fork clones, worktree ownership drifting outside the worktrees root, and timelines dropping rows. The add-on bundles Paseo 0.17.5, so users only get these once the pin moves.

Pi 1.6.1 is still the latest stable Pi (installed on start when selected, not bundled); `ha` 6.0.0 and `gh` 2.106.0 are already current.

## What Changes

- Pin Paseo 0.18.0 in `paseo/build.yaml` and both `ARG PASEO_VERSION` lines of `paseo/Dockerfile`; add-on version `0.18.0-1` in `paseo/config.yaml`.
- CHANGELOG entry naming the bundled Paseo **0.18.0** with its user-visible highlights, the Antigravity CLI minimum and the Pi release current at release time (**1.6.1**; installed on start when selected, not bundled in the image).

The bump does not change the add-on's specified behaviour (nothing under `paseo/rootfs/` changes; AGENTS.md Rule 1.4). There are no companion changes. Checks:

- `paseo-anchors.sh --diff 0.17.5 0.18.0`: anchors unchanged. `paseo-anchors.sh --check 0.18.0`: all ingress anchors present.
- `check-providers.sh 0.18.0`: built-in `claude codex copilot omp opencode pi`, plugin `antigravity fx goose hermes hoplite muse`, hoplite excluded; the providers option matches. The set of bundled plugins is unchanged.
- `npm pack` diff of `@getpaseo/server` 0.17.5 → 0.18.0: `dist/server/server/web-ui.js` is byte-identical; `web-ui/index.html` changes only the entry bundle hash. The set of `PASEO_*` names the server reads is identical. `listeners.js` only adds a retry for waiting extra listeners (the add-on sets a single `PASEO_LISTEN` address); `config-environment.js`/`paseo-env.js` strip Linux AppImage variables only when `APPIMAGE`/`APPDIR` are set (never in the add-on). No new HTTP route in `bootstrap.js`; the Desktop browser proxy (`network-tunnel/`) runs over the existing session. The new provider catalog cache is `<PASEO_HOME>/cache/provider-catalogs.json`, i.e. under `/data/home/.paseo` in the add-on, keyed by the provider binary's fingerprint, so a provider upgrade on start invalidates it. Other server changes: agent manager, OpenCode v2 and Pi providers, plugin notifications and push tokens, workspace/worktree/git-fetch services, daemon config (profile `systemPrompt`).
- `@getpaseo/cli`: only `package.json` changes, so the `paseo daemon run/stop/config` and `paseo provider ls` commands the add-on uses are unchanged.
- Release notes: no breaking, removed or `### Notes` entries. Two Changed entries touch Antigravity: 0.17.6 removes the background `agy -p /usage` usage source; 0.18.0 caches ACP catalogs, drops `--disable-telemetry` from the launch command (the add-on never set Antigravity's launch command) and needs Antigravity CLI 1.5.1 or later. The add-on installs Antigravity with Google's installer, which gives the latest CLI (1.5.18 at release), and the CLI updates itself afterwards. Checked in the built image with `providers: [pi, antigravity]`: `Providers: pi 1.6.1, antigravity 1.5.18`, Paseo lists Antigravity enabled; its status is `error` until the user signs in to `agy`, exactly as with the published 0.17.5-1 image under the same options.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None (`skip_specs`, AGENTS.md Rule 1.4).

## Impact

- `paseo/build.yaml`, `paseo/Dockerfile`, `paseo/config.yaml` (`version`), `paseo/CHANGELOG.md`.
- Published images `ghcr.io/farajfarook/{amd64,aarch64}-addon-paseo:0.18.0-1`.
