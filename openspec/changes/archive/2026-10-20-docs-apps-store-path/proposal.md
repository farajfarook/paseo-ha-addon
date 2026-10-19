## Why

Home Assistant renamed add-ons to apps in 2026.2. The in-store documentation (`paseo/DOCS.md`) still told users to go to **Settings → Add-ons → Add-on Store**, a menu that no longer exists, and the first forum reply on the launch thread pointed this out ("your install does not work, as the listed links do not exist"). The root README was fixed in PR #26; this change does the same for the Documentation tab inside Home Assistant.

## What Changes

- `paseo/DOCS.md` Installation: a short note on the 2026.2 rename and why the repository keeps its name (the Supervisor derives the app id `b498db88_paseo` from the repository URL), then the current path **Settings → Apps → Install app → ⋮ → Repositories**, plus a pointer to the **Show app** My badge in the README.
- `paseo/DOCS.md`: "Update in the Add-on Store" and "Configuration in the Add-on Store" now point at the app's page under **Settings → Apps**.

Documentation only. `paseo/DOCS.md` is not a shipped file, so no add-on version bump (AGENTS.md Rule 3). The wider "add-on" wording in DOCS.md, the add-on name and the `paseo/README.md` title are left as they are; renaming them is a separate decision.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. The add-on's behaviour does not change; only instructions in the documentation do (`skip_specs`).

## Impact

- `paseo/DOCS.md` (Installation, updating, Options reference intro).
