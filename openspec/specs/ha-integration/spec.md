# ha-integration Specification

## Purpose
Defines what Paseo agents can see and do in Home Assistant, so that configuring HA with agents works out of the box and stays safe: file access, the default HA project, live API access, MCP tools, bundled HA guidance and rollback.

## Requirements

### Requirement: Home Assistant file access
Agents SHALL have read-write access to the Home Assistant configuration, all add-on configuration folders and `/share`, and read-only access to SSL certificates, media and backups. Paths SHALL be stable and documented.

#### Scenario: Edit HA configuration
- **WHEN** an agent edits `configuration.yaml`, `automations.yaml` or a file under `packages/` or `custom_components/` in the HA config folder
- **THEN** the change is written to the live Home Assistant configuration

#### Scenario: Edit another add-on's config
- **WHEN** an agent edits a file in another add-on's config folder (e.g. Zigbee2MQTT or Mosquitto) under `/addon_configs`
- **THEN** the change is written to that add-on's configuration

#### Scenario: Read-only folders
- **WHEN** an agent tries to write to the SSL, media or backup folders
- **THEN** the write fails with a read-only error and the files are unchanged

### Requirement: Default Home Assistant project
On start, the add-on SHALL ensure a Paseo project named "Home Assistant" exists for the HA configuration directory, so the user can start an agent on their HA config without any setup.

#### Scenario: First open
- **WHEN** the user opens Paseo from the sidebar for the first time
- **THEN** a "Home Assistant" project pointing at the HA configuration directory is already listed

#### Scenario: Idempotent across restarts
- **WHEN** the add-on restarts
- **THEN** exactly one "Home Assistant" project exists, and a user-renamed project for the same path is not duplicated or renamed back

### Requirement: Live Home Assistant API access
Agents SHALL be able to call the Home Assistant Core REST and WebSocket APIs without the user creating a token. Agents SHALL be able to check the configuration, reload integrations, read entity states, and call services.

#### Scenario: Check configuration
- **WHEN** an agent requests a configuration check after editing YAML
- **THEN** it receives HA's validation result, including errors with file and line information when available

#### Scenario: Reload automations
- **WHEN** an agent reloads automations after changing `automations.yaml`
- **THEN** Home Assistant applies the new automations without a restart

#### Scenario: Read states
- **WHEN** an agent queries entity states
- **THEN** it receives the current states of the Home Assistant entities

### Requirement: Supervisor access and ha CLI
Agents SHALL have the `ha` command-line tool with Supervisor `manager`-level access, so they can read Core and add-on logs, restart Home Assistant Core, create backups, and inspect or restart add-ons.

#### Scenario: Read Core logs
- **WHEN** an agent runs `ha core logs` from a Paseo terminal or tool call
- **THEN** it receives recent Home Assistant Core log output

#### Scenario: Restart Core
- **WHEN** an agent runs `ha core restart` after a change that requires a restart
- **THEN** Home Assistant Core restarts, while the Paseo add-on and its session keep running

#### Scenario: Create backup
- **WHEN** an agent runs `ha backups new` before a risky change
- **THEN** a Home Assistant backup is created

### Requirement: Home Assistant MCP tools
When the Home Assistant "Model Context Protocol Server" integration is enabled, agents with MCP support SHALL have HA's MCP tools available without manual configuration. When it is not enabled, agents SHALL start normally without errors.

#### Scenario: MCP integration enabled
- **WHEN** the user has enabled HA's MCP Server integration and starts a Claude Code, Codex or OpenCode session
- **THEN** the session lists Home Assistant MCP tools (e.g. controlling exposed entities)

#### Scenario: MCP integration not enabled
- **WHEN** the MCP Server integration is not set up
- **THEN** agent sessions start normally and the add-on log notes how to enable HA's MCP Server integration

### Requirement: Bundled Home Assistant guidance
The add-on SHALL provide every agent with built-in Home Assistant guidance. The guidance SHALL cover where files live, how to use the API and `ha` CLI, the safe edit workflow, and hard rules. The bundled guidance SHALL be updated by add-on updates without overwriting user edits.

#### Scenario: Agent knows the workflow
- **WHEN** a user asks any bundled agent to "add an automation that turns on the porch light at sunset"
- **THEN** the agent's available instructions direct it to edit the right file, run a configuration check, reload, and verify via logs/states

#### Scenario: Hard rules
- **WHEN** an agent works in the HA configuration
- **THEN** its instructions forbid printing the contents of `secrets.yaml` and editing files under `.storage` while Home Assistant is running

#### Scenario: User override preserved
- **WHEN** the user has edited their own shared instructions and the add-on is updated
- **THEN** the user's edits are kept and the bundled HA guidance is updated separately

### Requirement: Optional git snapshots
The add-on SHALL offer an option, off by default, that keeps the Home Assistant configuration under git. Agents SHALL then be instructed to commit before and after each change so users can review and roll back.

#### Scenario: Option off by default
- **WHEN** the add-on runs with default options
- **THEN** the add-on creates no git repository in the HA configuration directory

#### Scenario: Enable snapshots
- **WHEN** the user enables git snapshots and restarts
- **THEN** the HA configuration directory is a git repository whose ignore rules exclude `secrets.yaml`, `.storage/`, databases, logs and other runtime files, and an initial commit exists

#### Scenario: Existing repository respected
- **WHEN** the HA configuration directory is already a git repository
- **THEN** the add-on does not reinitialise it or change its ignore rules

#### Scenario: Roll back an agent change
- **WHEN** snapshots are enabled and an agent's change breaks the configuration
- **THEN** the user (or agent) can restore the previous state by reverting the agent's commit

### Requirement: Home Assistant trust model is explicit
The documentation SHALL state that agents run with full read-write access to the HA configuration and add-on configs, and with Core API and Supervisor `manager` access. It SHALL recommend backups or git snapshots before significant changes.

#### Scenario: Documentation warns
- **WHEN** the user reads the add-on documentation
- **THEN** a security section lists every granted permission and the recommended safeguards
