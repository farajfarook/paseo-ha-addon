## Why

There is no new Paseo (0.16.1 is still the latest stable) and the Home Assistant `ha` CLI is current (6.0.0), but the GitHub CLI `gh` the image bundles for agents has a new release, 2.105.0 (2026-11-18). The add-on pins 2.104.0, so agents only get it once the pin moves. Pi 1.5.2 is the latest stable Pi (installed on start when selected, not bundled).

## What Changes

- Pin `GH_CLI_VERSION` 2.105.0 in `paseo/build.yaml` and its `ARG` line in `paseo/Dockerfile`; add-on version `0.16.1-2` in `paseo/config.yaml` (Paseo is unchanged, so the revision goes up, AGENTS.md Rule 3).
- CHANGELOG entry naming the updated `gh`, what changes for agents, the unchanged bundled Paseo **0.16.1** and the Pi release current at release time (**1.5.2**).

The bump does not change the add-on's specified behaviour (nothing under `paseo/rootfs/` changes, AGENTS.md Rule 1.4 names `GH_CLI_VERSION` as a pin). There are no companion changes.

- `paseo-anchors.sh --check 0.16.1`: all ingress anchors present. `check-providers.sh 0.16.1`: providers `antigravity claude codex copilot fx muse omp opencode pi`, hoplite excluded; the providers option matches. Both are unchanged from 0.16.1-1 because Paseo did not move.
- `gh` 2.105.0 release notes, compared with how the add-on uses `gh` (git's HTTPS credential helper for github.com via `gh auth git-credential`, login state in `/data/home/.config/gh`, the start log reads the account offline with `gh config get -h github.com user`):
  - New `gh event listen` and `gh event subscription create|list|view|delete` (GitHub Event Streams, preview): wait for pull request events instead of polling. Event Streams is available on all plans once GitHub approves the account from its wait list. New commands only; the add-on does not use them, and the CHANGELOG tells users they need preview access.
  - When `gh` detects an agent caller, `gh pr create`, `gh pr view` and `gh api` GETs of a pull request on github.com print a `gh event listen` hint on stderr (cli/cli#15077, #15081 also for `gh run view`/`gh run watch`). Stdout, JSON output and exit statuses are unchanged, so agents that parse `gh` output are unaffected; the CHANGELOG mentions the hint.
  - Dependency bumps (`golang.org/x/{text,term,crypto}`) and evals/docs chores. `gh auth git-credential` and `gh config get` are unchanged.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None (pin-only bump, `skip_specs`, AGENTS.md Rule 1.4).

## Impact

- `paseo/build.yaml`, `paseo/Dockerfile`, `paseo/config.yaml`, `paseo/CHANGELOG.md`.
- Published images `ghcr.io/farajfarook/{amd64,aarch64}-addon-paseo:0.16.1-2`.
