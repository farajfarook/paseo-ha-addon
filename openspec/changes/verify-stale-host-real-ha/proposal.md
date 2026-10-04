## Why

Task 4.1 of `heal-stale-host-after-reinstall` (an end-to-end check on a real Home Assistant instance) needs a real HA host and a reinstall of the add-on, so it was carried over here and `heal-stale-host-after-reinstall` could be archived. Its requirements are already in the main specs and covered by `paseo/tests/smoke/run.sh` and `paseo/tests/ingress/run.sh`. This change only tracks the manual verification.

## What Changes

- Verify the stable server ID and the panel's stale-host heal on a real HA host. No code or spec changes are planned. If the check finds a defect, the fix goes in its own change.

## Capabilities

### New Capabilities
<!-- None -->

### Modified Capabilities
<!-- None: verification only (skip_specs). -->

## Impact

- None on code. Uses a real HA instance and a browser that has opened the panel before.
