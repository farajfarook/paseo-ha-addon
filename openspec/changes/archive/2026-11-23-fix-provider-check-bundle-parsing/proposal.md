## Why

`check-providers.sh 0.17.3` fails with "provider definitions not found", although Paseo 0.17.3 has the same providers as 0.17.1. Two things moved in the web UI entry bundle that the script parses:

- The minifier swapped the array variable names. In 0.17.1 `AGENT_PROVIDER_DEFINITIONS` returns `l` and the dev-only list is `d`; in 0.17.3 it returns `d` and the dev-only list is `l`. The script hardcodes `l=[{id:` as the start and `,d=[{id:` as the end, so it finds no end.
- Paseo 0.17.2 added a `docsUrl:"…"` field to every provider definition, between `description` and `defaultModeId`. The entry regex only allowed `enabledByDefault` there, so even with the right array it would match no provider.

`lint.yaml` runs the script for the pinned release, so the 0.17.3 bump cannot pass CI without this fix. Nothing changed for the add-on: with the fixed parser, 0.17.3's built-in providers are `claude codex copilot omp opencode pi` and its plugin providers `antigravity fx goose hoplite muse`, as in 0.17.1.

## What Changes

- `.github/scripts/check-providers.sh` reads the variable that the `AGENT_PROVIDER_DEFINITIONS` getter returns, finds that array's declaration after the getter, and takes the literal up to its closing bracket (string literals skipped) instead of relying on the next `,d=[` declaration.
- Provider entries may carry any simple string or boolean fields between `description` and `defaultModeId` (`enabledByDefault`, `docsUrl`); mode entries still never match because they have no `defaultModeId`.
- Each way the lookup can fail (no getter, no array, unterminated array, no provider entries) exits with its own "provider definitions not found (…)" message.

Tooling only: no shipped file changes, so this change needs no version bump of its own (it ships in the same PR as the 0.17.3 bump).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. No spec describes how the CI script parses the bundle; the add-on's behaviour does not change (`skip_specs`).

## Impact

- `.github/scripts/check-providers.sh` (CI `lint.yaml` "Documentation and pins" job, README "Bumping Paseo", release runs).
