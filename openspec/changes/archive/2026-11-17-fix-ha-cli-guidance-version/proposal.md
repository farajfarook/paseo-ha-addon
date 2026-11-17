## Why

The Home Assistant guidance the add-on ships to agents (`paseo/rootfs/opt/paseo-ha/skills/home-assistant/reference/ha-cli.md`) says "The bundled `ha` CLI 5.x renamed `ha addons` to `ha apps` ... Both forms below work on 5.x", and DOCS.md says "in `ha` CLI 5.x `ha addons` is its deprecated alias". The `bump-paseo-0-16-1` change in the same PR bundles `ha` 6.0.0, so both sentences would name the wrong major version and leave an agent unsure whether the `ha addons` examples still work. They do: in 6.0.0 `apps` still has the aliases `addons`, `addon`, `add-on`, `add-ons` and `ad`, and using one prints "The use of 'addons' is deprecated, please use 'apps' instead!" (checked in `cmd/apps.go` at tag 6.0.0 and in the built image).

## What Changes

- `ha-cli.md`: describe `ha apps` as the current command and `ha addons` as its deprecated alias without naming a CLI major version, and say both forms work on the bundled CLI, so the sentence stays true across pin bumps. The same paragraph told agents to "use `ha info`" for the CLI version, but `ha info` returns Home Assistant system information (`/info`), not the version of the local `ha` binary, and `ha` 6.0.0 has neither a `--version` flag nor a `version` command (both checked in the built image). It now says so instead of pointing to `ha info` (CodeRabbit finding on PR #44).
- `paseo/DOCS.md` ("What agents can do with Home Assistant"): the same, "`ha addons` still works as its deprecated alias".

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None (`skip_specs`). The `ha-integration` requirement that the bundled guidance covers how to use the `ha` CLI is unchanged; this keeps the guidance accurate for the bundled version.

## Impact

- `paseo/rootfs/opt/paseo-ha/skills/home-assistant/reference/ha-cli.md` (shipped; released with the version bump of `bump-paseo-0-16-1` in the same PR; the bundled skill is symlinked into each agent's skills directory on start, so agents read the new text after the update).
- `paseo/DOCS.md` (documentation).
