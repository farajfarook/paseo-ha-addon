## Why

Task 6.4 of `add-paseo-plugin-providers` (the browser-based ingress suite against the Paseo 0.11.1 image) needs a browser behind the mock ingress and was not run before that change was archived. The ingress anchors are unchanged between 0.10.3 and 0.11.1 and the smoke suite's curl-level ingress checks pass, so this change only tracks the browser run.

## What Changes

- Run `paseo/tests/ingress/run.sh` against the 0.11.1 image. No code or spec changes are planned. If the run finds a defect, the fix goes in its own change.

## Capabilities

### New Capabilities
<!-- None -->

### Modified Capabilities
<!-- None: verification only (skip_specs). -->

## Impact

- None on code.
