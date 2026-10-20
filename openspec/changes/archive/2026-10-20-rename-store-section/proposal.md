## Why

The app store shows a section heading per repository, taken from `name` in `repository.yaml`. Ours read "Paseo Home Assistant Add-ons". Home Assistant renamed add-ons to apps in 2026.2, and a forum moderator pointed out the stale wording on the launch thread. Faraj picked the new name.

## What Changes

- `repository.yaml` `name`: "Paseo Home Assistant Add-ons" becomes **"Paseo for Home Assistant"**.
- `paseo/DOCS.md` Installation step 2 names the same section.

The Supervisor derives the repository id (`b498db88`) from the repository URL, not from `name`, so existing installs, the app slug `b498db88_paseo` and the ingress path are unaffected. Repository metadata and documentation only; neither file is a shipped file, so no add-on version bump (AGENTS.md Rule 3).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. The add-on's behaviour does not change; only the store section heading does (`skip_specs`).

## Impact

- `repository.yaml` (`name`).
- `paseo/DOCS.md` (Installation step 2).
