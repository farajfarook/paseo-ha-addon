## Why

Paseo 0.11.4 is out (stable, 2026-10-15). 0.11.3 adds search to the Add provider catalog, shows Add provider failures as a toast and stops offering Remove for plugin providers such as Muse Code and Antigravity; 0.11.4 is a Hoplite-only fix. The add-on bundles 0.11.2, so users only get these once the pin moves.

0.11.3 also bundles a new plugin provider, Hoplite (`hoplite acp`). It is a sponsored provider and the owner decided the add-on will not offer it. The provider check in CI requires the `providers` option to match the pinned Paseo's providers exactly, so it fails on 0.11.4 until Hoplite is excluded on purpose.

## What Changes

- Pin Paseo 0.11.4 in `paseo/build.yaml` and both `ARG PASEO_VERSION` lines of `paseo/Dockerfile`; add-on version `0.11.4-1` in `paseo/config.yaml`.
- `.github/scripts/check-providers.sh`: an `EXCLUDED_PROVIDERS` list (`hoplite`). Excluded providers are left out of the comparison. The check fails if an excluded provider is in the `providers` option, is a built-in provider, or no longer has `requiresConfiguration: true` (Paseo only registers such a plugin provider once its `agents.providers.<id>` override exists, and the add-on never writes one for an excluded provider).
- `paseo/DOCS.md`: one sentence that Hoplite is not offered.
- `paseo/tests/providers/run.sh` (test only, not shipped): assert the hook never writes a `hoplite` override.
- CHANGELOG entry naming the bundled Paseo **0.11.4** and Pi **1.3.0**.

No change under `paseo/rootfs/`: `20-providers.sh` only installs and writes enable flags for its own eight providers, so Hoplite gets no CLI and no override, and Paseo does not register it.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `agent-providers`: the provider selection option matches the pinned Paseo's providers except deliberately excluded ones (Hoplite).

## Impact

- `paseo/build.yaml`, `paseo/Dockerfile`, `paseo/config.yaml`, `paseo/CHANGELOG.md`, `paseo/DOCS.md`, `.github/scripts/check-providers.sh`, `paseo/tests/providers/run.sh`.
- Published images `ghcr.io/farajfarook/{amd64,aarch64}-addon-paseo:0.11.4-1`.
