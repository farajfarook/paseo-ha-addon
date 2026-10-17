## Why

The repository has no `SECURITY.md`, no `CONTRIBUTING.md` and no issue templates. Bug reports arrive without versions or logs, there is no private channel for vulnerability reports (an add-on that hands root and a Supervisor token to agents will get them), and GitHub's community profile marks the repo incomplete.

## What Changes

- `SECURITY.md`: private reporting via GitHub advisories, what is in scope here versus upstream (Paseo, agent CLIs, Supervisor), and a note that root/manager access is a documented property, not a vulnerability.
- `CONTRIBUTING.md`: non-code ways to help, the AGENTS.md rules in brief, the pre-PR checks, where providers live.
- `.github/ISSUE_TEMPLATE/`: `bug_report.yml` (versions, providers, access path, log), `provider_or_feature.yml`, and `config.yml` pointing questions to Discussions, Paseo bugs upstream and security reports to advisories.
- `AGENTS.md` Rule 1: add `CONTRIBUTING.md`, `SECURITY.md` and `.github/ISSUE_TEMPLATE/**` to the exempt list so future edits to community files need no OpenSpec change. Per AGENTS.md this takes effect after merge; this change is the OpenSpec record for the files it adds.

No shipped file changes, so no version bump.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None (repository metadata only).

## Impact

- `SECURITY.md`, `CONTRIBUTING.md`, `.github/ISSUE_TEMPLATE/{config.yml,bug_report.yml,provider_or_feature.yml}`, `AGENTS.md`.
