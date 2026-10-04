## 1. Bundled HA guidance

- [ ] 1.1 Write the bundled skill `/opt/paseo-ha/skills/home-assistant` (paths, layout, API/CLI recipes, workflow, hard rules) and `AGENTS.base.md`, linked per D12/D14 (see the archived `add-paseo-ha-addon` design.md)
- [ ] 1.2 Verify by asking Pi to "add an automation that turns on <test light> at sunset": it edits the right file, runs check_config, reloads automations, verifies via the API, and doesn't print `secrets.yaml`
