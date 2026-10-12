## Why

The direct-port test fails intermittently on a fresh 0.11.x image: `A) ingress WS -> 503 (want 101)`. A just-started Paseo 0.11.x daemon answers `/api/health` before its WebSocket listener binds, so the first `/ws` upgrade after a start can get a 503. The smoke test already retries for this (PR #16); the direct-port test sends one upgrade only. It failed this way on `main` after the 0.11.2-1 merge (Builder run 38254314005) and in a local run, and passed on re-run both times.

## What Changes

- `paseo/tests/direct-port/run.sh`: retry the ingress `/ws` upgrade up to 10 times, one second apart, until it gets 101 (same loop as the smoke test). The pass/fail check and the later wrong-bearer check are unchanged.

Test-only. No shipped file changes, so no add-on version bump (AGENTS.md Rule 3).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. The add-on's behaviour does not change; only a test's timing tolerance does (`skip_specs`).

## Impact

- `paseo/tests/direct-port/run.sh` (CI "Smoke test (amd64)" job, local release runs).
