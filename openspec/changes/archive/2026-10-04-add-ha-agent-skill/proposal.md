## Why

Task 4b.5 of `add-paseo-ha-addon` (bundled Home Assistant guidance) was deferred so that change could be archived. The requirement "Bundled Home Assistant guidance" in the `ha-integration` spec is already in the main specs but isn't implemented yet.

## What Changes

- Write the bundled skill `/opt/paseo-ha/skills/home-assistant` (paths, config layout, API/CLI recipes, MCP note, required workflow, hard rules), plus `reference/*.md`.
- Write `/opt/paseo-ha/AGENTS.base.md`.
- Link both into the agents per D12/D14 of the archived `add-paseo-ha-addon` design, so add-on updates refresh them without overwriting user edits.

## Impact

- Affects `paseo/` image contents and the agent-config startup scripts.
- Implements the `ha-integration` requirement "Bundled Home Assistant guidance" from `add-paseo-ha-addon`.
