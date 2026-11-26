## Why

Paseo 0.17.5 is out (stable, npm `latest`, tag `v0.17.5`). It lets you select several workspaces and archive them together, redesigns the agent profiles page and Add project, adds Tailscale support for hosts, host icons and latency in the host picker, and Archive on finish for schedules, plus many fixes: agents no longer hide the subagents they create, Claude subagents return their final reply, agents watching a pull request no longer stay Running, large Git workspaces no longer stall the daemon while their file watchers scan, a Git change in one repository no longer rescans every checkout, Hermes and other plugin ACP providers no longer leave processes behind after a model list refresh times out, and idle plugin sessions no longer wake the daemon every 10 seconds. Paseo now passes MCP server tokens to Claude Code 2.1.326 or later over stdin instead of in process arguments. The add-on bundles Paseo 0.17.4, so users only get these once the pin moves.

The GitHub CLI `gh` the image bundles for agents also has a new release, 2.106.0, with seven security fixes (terminal control characters in several commands' output, `gh skill update` installing from a different repository, `gh codespace jupyter` exposing localhost services); `gh auth logout` now revokes the OAuth token and clears saved HTTPS credentials from Git credential helpers. Pi 1.6.1 is the latest stable Pi (installed on start when selected, not bundled); `ha` 6.0.0 is already current.

## What Changes

- Pin Paseo 0.17.5 in `paseo/build.yaml` and both `ARG PASEO_VERSION` lines of `paseo/Dockerfile`; pin `GH_CLI_VERSION` 2.106.0 in `paseo/build.yaml` and its `ARG` line; add-on version `0.17.5-1` in `paseo/config.yaml`.
- CHANGELOG entry naming the bundled Paseo **0.17.5** with its user-visible highlights, the updated `gh` and the Pi release current at release time (**1.6.1**; installed on start when selected, not bundled in the image).

The bump does not change the add-on's specified behaviour (nothing under `paseo/rootfs/` changes; AGENTS.md Rule 1.4 names the Paseo and `gh` pins). There are no companion changes. Checks:

- `paseo-anchors.sh --diff 0.17.4 0.17.5`: anchors unchanged. `paseo-anchors.sh --check 0.17.5`: all ingress anchors present.
- `check-providers.sh 0.17.5`: built-in `claude codex copilot omp opencode pi`, plugin `antigravity fx goose hermes hoplite muse`, hoplite excluded; the providers option matches. The set of bundled plugins is unchanged.
- `npm pack` diff of `@getpaseo/server` 0.17.4 → 0.17.5: `dist/server/server/web-ui.js` is byte-identical; `web-ui/index.html` changes only the entry bundle hash. The set of `PASEO_*` names the server reads is identical. `PASEO_LISTEN` now also accepts comma-separated extra TCP listeners (new `listeners.js`, used by the Tailscale setting); a single `host:port`, which is all the add-on sets, parses as before. When `PASEO_LISTEN` comes from the environment, as in the add-on, Paseo reports the Tailscale setting as locked by the launch configuration and does not change listeners. Other server changes: agent manager and finish subscriptions, Claude/Codex/OMP/OpenCode/Pi providers, ACP provider cleanup, plugin runtime (new `command.run.before` hook), file observer scan slicing, workspace/worktree services, and a host machine kind probe (bounded by a 1.5 s timeout).
- `@getpaseo/cli` changes `daemon status` (adds `tailscale` and `extraListeners`, `configuredListen` shows the main address; `localDaemon`, which the run script reads, is unchanged), `hub login` and `schedule create|update` (archive on finish). The `paseo daemon run/stop/config` and `paseo provider ls` commands the add-on uses are unchanged.
- Release notes: no breaking, removed or `### Notes` entries; one Changed entry (Desktop update timing) does not apply to the add-on. The Claude Code token-over-stdin security change needs Claude Code 2.1.326 or later, which the add-on meets: `20-providers.sh` has no `PACKAGE_HOLD` and installs the latest stable on every start (2.1.332 at release). The OpenCode 2 MCP fix needs OpenCode 2.0.29 or later; the add-on installs the latest stable `opencode-ai` (1.19.6), which is not affected.
- `gh` 2.106.0 release notes, compared with how the add-on uses `gh` (git's HTTPS credential helper for github.com via `gh auth git-credential`, login state in `/data/home/.config/gh`, the start log reads the account with `gh config get -h github.com user`): the security fixes and the `run view` log fix change no command the add-on runs; `gh auth logout` now revokes the token (`--no-revoke` keeps the old behaviour) and runs `git credential reject`, which reaches the add-on's helper chain without changing git config. The CHANGELOG tells users about the logout change.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None (`skip_specs`, AGENTS.md Rule 1.4).

## Impact

- `paseo/build.yaml`, `paseo/Dockerfile`, `paseo/config.yaml` (`version`), `paseo/CHANGELOG.md`.
- Published images `ghcr.io/farajfarook/{amd64,aarch64}-addon-paseo:0.17.5-1`.
