# Proposal

## Why

The add-on treats Pi differently from the other five providers. Pi is baked into the image at a pinned version (`PI_VERSION` in `build.yaml` and the Dockerfile). Claude, Codex, Copilot, OpenCode and Oh My Pi are installed on start, but each one at a version hardcoded in `20-providers.sh`. Users only get a newer agent when a maintainer bumps a pin and ships a release. Agent CLIs release far more often than the add-on, so every user runs agents that are weeks out of date, and Pi can't be uninstalled like the others.

## What Changes

- **Pi becomes an ordinary provider.** It is no longer installed in the image. Like every other provider, it is installed into `/data/agents` on start when selected and uninstalled when deselected. The default stays `providers: [pi]`.
- **Every selected provider runs the latest stable release.** On each start the add-on asks the npm registry for each package's `latest` dist-tag and installs that version when it differs from the installed one. Oh My Pi's Bun runtime follows the same rule. The hardcoded version pins in `20-providers.sh` are removed.
- **A start without registry access keeps what is installed.** If the lookup fails, the provider keeps its installed version. If it was never installed, it stays disabled and the next start retries.
- **A broken upgrade rolls back.** If the new version installs but its CLI does not run, the add-on reinstalls the previous version and logs why.
- **Pi-dependent setup is skipped when Pi is absent.** Default Pi packages (`36-pi-packages.sh`) and the Pi MCP entry (`45-ha-mcp.sh`) only run when the `pi` command exists.
- Remove `PI_VERSION` from `build.yaml`, the Dockerfile, the image env and labels, the start-up log line and the docs check. Update DOCS.md, the README files, translations and CHANGELOG.

## Capabilities

### New Capabilities
<!-- None. -->

### Modified Capabilities
- `agent-providers`: Pi loses its built-in status; all providers install the latest stable release on start; upgrade rollback and offline behaviour are specified.
- `agent-runtime`: the superseded "Bundled Pi harness" requirement (the image includes Pi) is removed.

## Impact

- `paseo/Dockerfile`, `paseo/build.yaml`: drop the Pi install, `PI_VERSION`, `PASEO_HA_PI_VERSION` and the `io.hass.pi.version` label. The image gets smaller; Paseo stays pinned.
- `paseo/rootfs/etc/paseo-ha/init.d/20-providers.sh`: package names instead of pinned specs, a registry lookup per selected provider, rollback, Pi treated like the rest.
- `paseo/rootfs/etc/paseo-ha/init.d/36-pi-packages.sh`: skip when `pi` is not installed.
- `paseo/rootfs/etc/s6-overlay/scripts/init-paseo.sh`: the start-up log line no longer prints a Pi version from the image.
- `paseo/tests/providers/run.sh`, `paseo/tests/docs/run.sh`, smoke and agent-config tests: Pi installed at runtime, new test seams for the registry lookup.
- `paseo/DOCS.md`, `paseo/README.md`, `README.md`, `paseo/translations/en.yaml`, `paseo/CHANGELOG.md`, `paseo/config.yaml` (version bump).
- Every start now needs the npm registry for an up-to-date check. A fresh install with no network starts with no working agent until a later start succeeds.
- Existing installs: the first start after the update downloads Pi into `/data/agents`. Pi's settings, logins and packages under `/data/home/.pi` are untouched.
