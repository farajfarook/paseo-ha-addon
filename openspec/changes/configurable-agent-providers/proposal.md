# Proposal

## Why

Paseo 0.10.3 supports six agent providers: Claude, Codex, Copilot, OpenCode, Pi and Oh My Pi. The add-on only lets users install three of them (`claude-code`, `codex`, `opencode`), always offers Pi, and never touches Paseo's provider enable/disable switches. As a result, the add-on's Configuration tab and Paseo's provider list don't match. Some providers can't be installed, Pi can't be turned off, and a provider without a CLI can still appear in Paseo.

## What Changes

- **BREAKING**: Replace the `agents` option with a `providers` option. It's a multi-select of Paseo's six provider IDs: `claude`, `codex`, `copilot`, `opencode`, `pi`, `omp`. The default is `[pi]`. There's no migration from `agents`: this is a pre-release add-on with a single user, who will reinstall.
- Install and uninstall each provider's CLI on start so the installed set matches the selection:
  - Claude, Codex, Copilot and OpenCode install from pinned npm packages into `/data/agents`.
  - Oh My Pi (`omp`) installs together with a pinned Bun runtime, which it needs. Bun is installed only when `omp` is selected.
  - Pi stays built into the image. Deselecting Pi doesn't uninstall it.
- On every start, set Paseo's `agents.providers.<id>.enabled` for all six providers: `true` if selected and its CLI is usable, `false` otherwise. Pi is enabled by default and can be turned off.
- If a selected provider fails to install, it's disabled in Paseo and the failure is logged. Startup continues.
- Update the option translations, DOCS.md and CHANGELOG to describe the new option and the version bump.

## Capabilities

### New Capabilities
- `agent-providers`: which Paseo agent providers the add-on offers. Covers the provider selection option, installing and uninstalling CLIs to match it, and keeping Paseo's provider enable/disable state in sync with it.

### Modified Capabilities
<!-- None in openspec/specs/. The in-flight change `add-paseo-ha-addon` (agent-runtime spec) describes the
     old "Bundled Pi harness" and "Optional additional agent CLIs" requirements; its spec is aligned in tasks. -->

## Impact

- `paseo/config.yaml`: `options`/`schema` (`agents` → `providers`), version bump.
- `paseo/translations/en.yaml`, `paseo/DOCS.md`, `paseo/CHANGELOG.md`, top-level `README.md` (add-on description).
- `paseo/rootfs/etc/paseo-ha/init.d/20-agents.sh`: reworked into provider install and uninstall, plus a step that syncs Paseo's provider enabled flags.
- Persisted Paseo config `/data/home/.paseo/config.json` (`agents.providers.*.enabled`) becomes owned by the add-on. Toggles made in Paseo's Settings screen are overwritten on the next start.
- New runtime downloads: `@github/copilot` (has musl builds), `@oh-my-pi/pi-coding-agent` and `bun` (musl builds). Images and the Dockerfile are unchanged.
- `openspec/changes/add-paseo-ha-addon/specs/agent-runtime/spec.md`: requirements that this change supersedes.
