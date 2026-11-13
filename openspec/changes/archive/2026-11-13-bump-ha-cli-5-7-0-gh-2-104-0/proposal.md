## Why

There is no new Paseo (0.15.4 is still the latest stable), but two other tools the image bundles for agents have new releases: the Home Assistant `ha` CLI 5.7.0 (2026-11-12) and the GitHub CLI `gh` 2.104.0 (2026-11-12). The add-on pins 5.6.0 and 2.103.3, so agents only get the fixes once the pins move. Pi 1.5.2 is the latest stable Pi (installed on start when selected, not bundled).

## What Changes

- Pin `HA_CLI_VERSION` 5.7.0 and `GH_CLI_VERSION` 2.104.0 in `paseo/build.yaml` and their `ARG` lines in `paseo/Dockerfile`; add-on version `0.15.4-2` in `paseo/config.yaml` (Paseo is unchanged, so the revision goes up, AGENTS.md Rule 3).
- CHANGELOG entry naming the updated tools, what changes for agents, the unchanged bundled Paseo **0.15.4** and the Pi release current at release time (**1.5.2**).

The bump does not change the add-on's specified behaviour (nothing under `paseo/rootfs/` changes, AGENTS.md Rule 1.4 names `HA_CLI_VERSION` and `GH_CLI_VERSION` as pins). There are no companion changes.

- `paseo-anchors.sh --check 0.15.4`: all ingress anchors present. `check-providers.sh 0.15.4`: providers `antigravity claude codex copilot muse omp opencode pi`, hoplite excluded; the providers option matches. Both are unchanged from 0.15.4-1 because Paseo did not move.
- `ha` CLI 5.7.0 release notes, compared with how the add-on uses `ha` (installed at `/usr/local/bin/ha`, used by agents through the bundled Home Assistant guidance, never by the add-on's own scripts):
  - HTTP client moved from resty to `net/http`, YAML library replaced, and requests now send a `HomeAssistantCLI/<version>` User-Agent: internal; the commands and output the guidance documents are unchanged.
  - `--raw-json` now exits non-zero when the Supervisor answers with an error result (it used to exit 0). The guidance only pipes successful `--raw-json` output into `jq`, so it is unaffected; scripts that relied on exit 0 for errors were hiding failures.
  - When `SUPERVISOR_SOCKET` is set, `ha` talks to the Supervisor over that Unix socket without a token instead of over TCP with `SUPERVISOR_TOKEN`. Supervisor sets `SUPERVISOR_SOCKET` and mounts the per-app socket for every app (home-assistant/supervisor#7463); requests on it carry the app as principal with the same role checks as its token. The daemon is started with `with-contenv`, so agents inherit the variable and the add-on's `manager` role applies either way. The add-on keeps the default `supervisor_api_tcp`, so `SUPERVISOR_TOKEN`, `HASS_TOKEN` and the documented `curl` recipes keep working over TCP. The add-on has no custom AppArmor profile, so nothing in it blocks the socket.
  - The default branch rename is repository housekeeping; the release assets (`ha_amd64`, `ha_aarch64`) the Dockerfile downloads are unchanged.
- `gh` 2.104.0 release notes, compared with how the add-on uses `gh` (git's HTTPS credential helper for github.com via `gh auth git-credential`, login state in `/data/home/.config/gh`, the start log reads the account offline with `gh config get -h github.com user`):
  - `gh repo delete` asks for an extra confirmation, even with `--yes`, when deleting a private or internal repository would also delete its forks; non-interactive callers add `--accept-cascading-deletion-of-private-forks`. The add-on never deletes repositories; the CHANGELOG tells users whose agents do.
  - `gh auth status` now surfaces rate-limit, server and network errors, and token refresh is skipped when gh's state directory is not writable. The start log does not call `gh auth status`, and `/data/home/.config/gh` is writable, so nothing changes for the add-on; users running `gh auth status` in a terminal see clearer errors.
  - `gh auth git-credential` is unchanged.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None (pin-only bump, `skip_specs`, AGENTS.md Rule 1.4).

## Impact

- `paseo/build.yaml`, `paseo/Dockerfile`, `paseo/config.yaml`, `paseo/CHANGELOG.md`.
- Published images `ghcr.io/farajfarook/{amd64,aarch64}-addon-paseo:0.15.4-2`.
