## Why

Paseo 0.17.1 is out (stable; 0.17.0 was published to npm the same day without a GitHub release, and the 0.17.1 notes cover both). It is a minor release: Antigravity approvals, permission modes and session history (needs Antigravity CLI 1.5.0 or later), starting workspaces in existing worktrees or from a branch or pull request, provider status, installed version and in-app updates, quota forecasts and OpenRouter balances in Usage, watching PRs/MRs for checks and reviews, heartbeats in Background work, agent messages that wait for the current turn by default, goose model selection, plugin agent instructions, plus about 45 fixes (history timeouts after reconnect, slow reopening of long Claude chats, recovery after stopping a foreground daemon, Codex/OpenCode/OMP turn fixes, diff and Changes fixes). It also bundles a new plugin provider, goose. The add-on bundles Paseo 0.16.2, so users only get these once the pin moves. Pi 1.6.0 is the latest stable Pi (installed on start when selected, not bundled); `ha` 6.0.0 and gh 2.105.0 are already current.

## What Changes

- Pin Paseo 0.17.1 in `paseo/build.yaml` and both `ARG PASEO_VERSION` lines of `paseo/Dockerfile`; add-on version `0.17.1-1` in `paseo/config.yaml`.
- CHANGELOG entry naming the bundled Paseo **0.17.1** with its user-visible highlights, the new goose provider and the Pi release current at release time (**1.6.0**; installed on start when selected, not bundled in the image).

The bump itself does not change the add-on's specified behaviour. Two companion changes ship in the same PR: `add-goose-provider` (the new bundled goose provider, with an `agent-providers` spec delta) and `document-in-app-provider-updates` (DOCS.md, `skip_specs`). Checks:

- `paseo-anchors.sh --diff 0.16.2 0.17.1`: anchors unchanged. `paseo-anchors.sh --check 0.17.1`: all ingress anchors present.
- `check-providers.sh 0.17.1`: built-in `claude codex copilot omp opencode pi`, plugin `antigravity fx goose hoplite muse`, hoplite excluded. It fails on the bare bump (goose missing from the option) and passes with `add-goose-provider`.
- `npm pack` diff of `@getpaseo/server` 0.16.2 → 0.17.1: `dist/server/server/web-ui.js` is byte-identical; `web-ui/index.html` changes only the entry bundle hash in its root-absolute `<script src="/_expo/static/js/web/index-<hash>.js">` (rewritten by nginx `sub_filter '"/_expo/'`). The set of `PASEO_*` names the server reads is identical. Notable server changes: the provider installation contract (`provider-installation/`, `cli-installation.js`, `update-command.js`, `release-check.js`; see `document-in-app-provider-updates`), change-request watches (GitHub/GitLab/Gitea pollers), worktree creation intents, the goose plugin and a `persisted-config.js` migration of a hand-written `goose` entry with `extends: "acp"` (the add-on only merges `enabled` into whatever entry exists), and a Claude "ultracode" option migration in `daemon-config-store.js`. `dist/scripts/supervisor.js` now spawns the daemon worker `detached` on Linux ("Providers must stay alive until the worker has captured restart recovery"): the worker runs in its own session, and the supervisor orders its shutdown over IPC on SIGTERM. The add-on's `paseo` service still stops cleanly through `paseo daemon run` (s6 SIGTERM), and its run script already kills a leftover `Paseo Daemon`/`daemon-worker` by name before starting, so a worker orphaned by a killed supervisor cannot hold the pid lock; the smoke suite's restart and crash checks cover both.
- `@getpaseo/cli` changes only `agent ls`, `agent send`, `worktree create` and `package.json`, so the `paseo daemon run/status/stop/config` and `paseo provider ls` commands the add-on uses are unchanged.
- Release notes: no breaking, removed or `### Notes` entries; the eight "Changed" entries are UI and agent behaviour (content width, Antigravity tool cards, clone list order, quota bar colour, worktree teardown on timeout, mobile taps, Git status reload, `browser_new_tab`), none of them a command, flag, config key, environment variable, port, path or provider loading the add-on relies on. Antigravity's new features need its CLI 1.5.0 or later: Antigravity is vendor-installed at its latest release and updates itself.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None (`skip_specs`; the `agent-providers` delta belongs to `add-goose-provider`).

## Impact

- `paseo/build.yaml`, `paseo/Dockerfile`, `paseo/config.yaml` (`version`), `paseo/CHANGELOG.md`.
- Published images `ghcr.io/farajfarook/{amd64,aarch64}-addon-paseo:0.17.1-1`.
