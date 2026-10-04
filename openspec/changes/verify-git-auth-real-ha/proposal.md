## Why

Task 4.2 of `add-git-auth` (an end-to-end check on a real Home Assistant instance) needs a real HA host and a GitHub login, so it was carried over here and `add-git-auth` could be archived. The `git-auth` requirements are already in the main specs and covered by `paseo/tests/agent-config/run.sh`. This change only tracks the manual verification.

## What Changes

- Verify `git-auth` on real HA hosts (amd64 and aarch64). No code or spec changes are planned. If the check finds a defect, the fix goes in its own change.

## Capabilities

### New Capabilities
<!-- None -->

### Modified Capabilities
<!-- None: verification only (skip_specs). -->

## Impact

- None on code. Uses a test HA instance and a GitHub account.
