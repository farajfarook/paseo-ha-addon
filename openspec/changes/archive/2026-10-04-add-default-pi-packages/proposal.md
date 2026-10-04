# Proposal

## Why

The add-on bundles Pi with no extensions. The maintainer wants a curated set of Pi packages from https://pi.dev/packages installed by default. Users must still be able to remove any of them, or add their own, and those choices have to survive restarts and add-on updates. Today nothing installs packages, and nothing tells the user that packages they install themselves already persist.

## What Changes

- Ship a maintainer-owned default list of Pi package sources in the image (`/opt/paseo-ha/pi-packages.default`, one source per line, `#` comments). The initial list has five packages: `@juicesharp/rpiv-todo` and `@juicesharp/rpiv-ask-user-question` (the todo panel and structured questions Paseo displays for Pi), `pi-subagents`, `pi-provider-litellm` and `pi-web-access`.
- On every start, an init hook installs each default the add-on has **never offered before** with `pi install` into the persistent Pi agent dir (`/data/home/.pi/agent`). Every source it offers is recorded in a ledger under `/data`, so it is offered only once.
- Pi's own `settings.json` (`packages`) is the single source of truth for what is installed. Users manage packages with the normal Pi commands from a Paseo terminal: `pi install <source>`, `pi remove <source>`, `pi list`, `pi config`.
  - A default the user removes stays removed after restarts and updates.
  - A package the user installs stays installed after restarts and updates.
  - A default that a later add-on release adds is installed once on the first start after the update.
- A failed install (for example offline) is not written to the ledger, so the next start tries again. It never blocks startup.
- Each start logs the installed Pi packages.
- Document the behaviour in `DOCS.md` and in the seeded `/config/README.md`.
- No new add-on option and no editable package list file. **Not breaking.**

## Capabilities

### New Capabilities
- `pi-packages`: default Pi packages, offered once per installation, and persistence of the user's own Pi package installs and removals across restarts and add-on updates.

### Modified Capabilities
<!-- None: there are no archived main specs yet (openspec/specs is empty). -->

## Impact

- New init hook `paseo/rootfs/etc/paseo-ha/init.d/` (runs after `30-agent-config.sh`, which sets up the Pi dir links).
- New file `paseo/rootfs/opt/paseo-ha/pi-packages.default`. The maintainer fills it.
- New ledger `/data/paseo-ha/pi-packages.offered`.
- Network access to npm/git on the first start after a release that adds defaults. Startup takes longer on those starts only.
- Docs: `paseo/DOCS.md`, `paseo/rootfs/opt/paseo-ha/config-seed/README.md`, `paseo/CHANGELOG.md`, version bump in `paseo/config.yaml`.
- Tests: `paseo/tests/agent-config/run.sh` gains package scenarios using a local package source, so no network is needed.
