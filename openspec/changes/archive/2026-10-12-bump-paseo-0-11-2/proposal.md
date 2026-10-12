## Why

Paseo 0.11.2 is out (stable, 2026-10-09). It fixes intermittent text clipping in iOS chats and Markdown previews. The add-on bundles 0.11.1, so users only get the fix once the pin moves.

## What Changes

- Pin Paseo 0.11.2 in `paseo/build.yaml` and both `ARG PASEO_VERSION` lines of `paseo/Dockerfile`.
- Add-on version `0.11.2-1` in `paseo/config.yaml`.
- CHANGELOG entry naming the bundled Paseo **0.11.2** and Pi **1.1.0**.
- Test-only lint fix: `PI_BUDGET= start_app` becomes `PI_BUDGET='' start_app` in `paseo/tests/agent-config/run.sh` (ShellCheck SC1007; same behaviour, not shipped in the image).

No behaviour change in the add-on itself: the ingress anchors are identical between 0.11.1 and 0.11.2 and the provider list is unchanged.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. Version pin bump only (`skip_specs`).

## Impact

- `paseo/build.yaml`, `paseo/Dockerfile`, `paseo/config.yaml`, `paseo/CHANGELOG.md`, `paseo/tests/agent-config/run.sh`.
- Published images `ghcr.io/farajfarook/{amd64,aarch64}-addon-paseo:0.11.2-1`.
