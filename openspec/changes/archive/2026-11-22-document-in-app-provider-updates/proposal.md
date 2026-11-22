## Why

Paseo 0.17.0 adds "Update providers in Paseo" (getpaseo/paseo#9568, #9661): its provider settings show each provider's installed version and status, check for a newer release, and can run the CLI's own update command from the app (`dist/server/server/agent/providers/cli-installation.js`; `pi update --self`, `copilot update`, `opencode upgrade`, `omp update`). In the add-on these CLIs are not global npm installs: the providers hook installs them into `/data/agents/node_modules` and brings each to its latest stable npm release on every start. Checked in the add-on image: Pi's self-update refuses such an install ("pi cannot self-update this installation. Update @earendil-works/pi-coding-agent@<ver> using the package manager, wrapper, or source checkout that provides this installation."), because the install is not under `npm root -g`. Users who press the new update button need to know that a restart is the way to update an agent in the add-on.

## What Changes

- `paseo/DOCS.md`, "Which versions are installed": a bullet saying Paseo 0.17.0 and later can offer to update Pi, Copilot, OpenCode and Oh My Pi from the app, that in the add-on a restart does this (each start installs the latest stable npm release), and that Pi refuses the in-app update here because the add-on manages its install.

The add-on's behaviour is unchanged (the hook already installs the latest stable release on every start, `agent-providers` "Latest stable versions"), so there is no spec delta (`skip_specs`).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None (documentation only; `skip_specs`).

## Impact

- `paseo/DOCS.md` (not a shipped file; released with the version bump of `bump-paseo-0-17-1` in the same PR).
