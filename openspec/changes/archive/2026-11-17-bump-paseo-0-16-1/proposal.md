## Why

Paseo 0.16.1 is out (stable, 2026-11-17), a bug-fix release on top of 0.16.0: Claude Bypass mode no longer approves actions without a permission card when a `permissions.ask` rule or a hook returns `ask`, Claude sessions no longer fail until `/login` when the model list refresh races a token renewal, Pi/OMP model names containing `/` are no longer cut, an OpenCode question can be answered after a steered turn, Codex chats opened only for their history are unloaded again, and several web UI fixes. The `ha` CLI 6.0.0 is also out (2026-11-16). The add-on bundles Paseo 0.16.0 and `ha` 5.7.0, so users only get these once the pins move. Pi 1.5.2 is the latest stable Pi (installed on start when selected, not bundled); gh 2.104.0 is already current.

## What Changes

- Pin Paseo 0.16.1 in `paseo/build.yaml` and both `ARG PASEO_VERSION` lines of `paseo/Dockerfile`, and `HA_CLI_VERSION` 6.0.0 in `paseo/build.yaml` and its `ARG` line; add-on version `0.16.1-1` in `paseo/config.yaml`.
- CHANGELOG entry naming the bundled Paseo **0.16.1** with its user-visible fixes, the `ha` CLI 6.0.0 behaviour changes users may notice (with the guidance wording from `fix-ha-cli-guidance-version`), and the Pi release current at release time (**1.5.2**; installed on start when selected, not bundled in the image).

The bump itself does not change the add-on's specified behaviour (AGENTS.md Rule 1.4 names `PASEO_VERSION` and `HA_CLI_VERSION` as pins; checks below). One companion change ships in the same PR: `fix-ha-cli-guidance-version`, which removes the "`ha` CLI 5.x" wording from the bundled agent guidance (`ha-cli.md`) and DOCS.md, which would be wrong with 6.0.0 bundled.

- `paseo-anchors.sh --diff 0.16.0 0.16.1`: anchors unchanged. `paseo-anchors.sh --check 0.16.1`: all ingress anchors present.
- `check-providers.sh 0.16.1`: built-in `claude codex copilot omp opencode pi`, plugin `antigravity fx hoplite muse`, hoplite excluded; the providers option matches.
- `npm pack` diff of `@getpaseo/server` 0.16.0 → 0.16.1: `dist/server/server/web-ui.js` is byte-identical; `web-ui/index.html` changes only the entry bundle hash in its root-absolute `<script src="/_expo/static/js/web/index-<hash>.js">` (rewritten by nginx `sub_filter '"/_expo/'`). The other server changes are inside the Claude (new `bypass-approval`, model discovery), Codex, OMP, OpenCode and Pi provider code, the agent manager/timeline projection and `checkout-git.js` (index-copy mtime for racy-git); `@anthropic-ai/claude-agent-sdk` moves 0.3.246 → 0.3.326. The set of `PASEO_*` names the server reads is identical (118 names). `@getpaseo/{cli,protocol,relay,plugin}` change only `package.json`, so the `paseo daemon run/status/stop/config` and `paseo provider ls` commands the add-on uses are unchanged; `@getpaseo/client` changes only `daemon-client.js`, which the add-on does not use.
- Release notes: ten fixes, no breaking, removed or changed entries and no `### Notes` section, so nothing names a command, flag, config key, environment variable, port, path or provider loading the add-on relies on.
- `ha` CLI 6.0.0 release notes, compared with how the add-on uses `ha` (installed at `/usr/local/bin/ha`, used by agents through the bundled Home Assistant guidance, never by the add-on's own scripts; the Dockerfile runs `ha help` at build time):
  - Config handling moved from viper to a small built-in package (home-assistant/cli#694): same precedence (flag, environment, config file, default) and the same `SUPERVISOR_<KEY>`/`SUPERVISOR_TOKEN` variables; only `$HOME/.homeassistant.{yaml,yml,json}` are searched for a config file. The add-on writes no `ha` config file and relies on `SUPERVISOR_TOKEN` (or `SUPERVISOR_SOCKET`) from the environment.
  - HTTP is written directly to a TCP or Unix socket connection (home-assistant/cli#695): `https://` endpoints are rejected, `HTTP_PROXY` and similar variables are ignored, redirects are not followed, every request uses its own connection and responses arrive uncompressed. The Supervisor endpoint is plain `http://supervisor` or the `SUPERVISOR_SOCKET` Unix socket, so the guidance's commands work as before; a user who sets a proxy in `env_vars` now gets `ha` going straight to the Supervisor (CHANGELOG line).
  - Shell-completion fixes (home-assistant/cli#699): no effect on the add-on.
  - `ha addons` (and the other add-on aliases) still work on 6.0.0 with a deprecation warning, which the companion change's wording relies on.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None for the bump itself (`skip_specs`, AGENTS.md Rule 1.4). The companion change `fix-ha-cli-guidance-version` corrects version wording in the bundled guidance and DOCS.md without changing a requirement (`skip_specs`).

## Impact

- `paseo/build.yaml`, `paseo/Dockerfile`, `paseo/config.yaml` (`version`), `paseo/CHANGELOG.md`.
- Published images `ghcr.io/farajfarook/{amd64,aarch64}-addon-paseo:0.16.1-1`.
