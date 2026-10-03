# Spec Delta

## Purpose

Defines the environment in which the Paseo daemon and its coding agents run inside the add-on: daemon lifecycle, bundled Pi harness, optional extra agents, persistence, file access and user options.

## ADDED Requirements

### Requirement: Daemon lifecycle and health
The add-on SHALL start the Paseo daemon with the bundled web UI enabled when the add-on starts, restart it if it exits unexpectedly, and report unhealthy to the Supervisor when the daemon health endpoint fails.

#### Scenario: Normal start
- **WHEN** the add-on starts
- **THEN** the daemon is running and its health endpoint returns success within 60 seconds

#### Scenario: Daemon crash
- **WHEN** the daemon process exits unexpectedly
- **THEN** it is restarted automatically, or the add-on stops so the Supervisor watchdog can restart it

#### Scenario: Logs
- **WHEN** the user opens the add-on Log tab
- **THEN** daemon log output is visible there

### Requirement: Bundled Pi harness
> **Superseded** by the `configurable-agent-providers` change (capability `agent-providers`): Pi is still built into the image, but it is now one of six selectable providers and can be turned off with the `providers` option.

The add-on image SHALL include the Pi coding agent CLI so that Pi is available as a Paseo provider immediately after installation, with no extra install step.

#### Scenario: Pi available out of the box
- **WHEN** the user opens Paseo for the first time after installation
- **THEN** Pi is listed as an available provider

#### Scenario: Pi authentication persists
- **WHEN** the user authenticates Pi (via environment variable option or its login flow) and later restarts or updates the add-on
- **THEN** Pi remains authenticated

### Requirement: Optional additional agent CLIs
> **Superseded** by the `configurable-agent-providers` change (capability `agent-providers`): the `agents` option is replaced by `providers` (Claude, Codex, Copilot, OpenCode, Pi, Oh My Pi), and Paseo's provider enable flags now follow it.

Users SHALL be able to select additional agent CLIs (at least Claude Code, Codex and OpenCode) through add-on options; selected agents SHALL be installed and available as Paseo providers.

#### Scenario: Enable an extra agent
- **WHEN** the user adds "claude-code" to the agents option and restarts the add-on
- **THEN** Claude Code is listed as an available provider in Paseo

#### Scenario: Install survives restart
- **WHEN** the add-on restarts with an unchanged agents option
- **THEN** previously installed agents are available without being downloaded again

#### Scenario: Agent install failure
- **WHEN** an agent CLI fails to install (e.g. no network or unsupported architecture)
- **THEN** the failure is logged, the add-on and Paseo still start, and other agents remain available

#### Scenario: Remove an agent
- **WHEN** the user removes an agent from the agents option and restarts
- **THEN** that agent is no longer offered as a provider

### Requirement: Persistent state
Paseo daemon state and all agent configuration and credentials SHALL persist across add-on restarts, updates and host reboots, and SHALL be included in Home Assistant backups of the add-on.

#### Scenario: Restart keeps sessions and settings
- **WHEN** the add-on is restarted or updated
- **THEN** Paseo projects, settings and agent logins are unchanged

#### Scenario: Backup and restore
- **WHEN** the user restores a Home Assistant backup containing the add-on
- **THEN** Paseo state and agent credentials are restored

### Requirement: Workspace option
The add-on SHALL expose a workspace option for the directory agents start in by default. It SHALL default to the Home Assistant configuration directory.

#### Scenario: Default workspace
- **WHEN** the add-on runs with default options
- **THEN** new terminals and agent sessions start in the Home Assistant configuration directory

#### Scenario: Custom workspace
- **WHEN** the user sets the workspace option to another mapped path (e.g. under `/share`)
- **THEN** the directory is created if missing and agents start there

### Requirement: Editable agent configuration
The add-on SHALL provide a user-editable agent-configuration folder, reachable from File Editor and Samba, for skills, shared instructions and per-agent definitions. All agents SHALL pick up its contents on start. Credentials, sessions and Paseo's own state SHALL NOT be stored there.

#### Scenario: Folder is created on first start
- **WHEN** the add-on starts for the first time
- **THEN** the add-on's config folder contains a `skills/` directory, an `AGENTS.md` file and per-agent subfolders with a short README explaining each

#### Scenario: User skill visible to all agents
- **WHEN** the user adds `skills/my-skill/SKILL.md` to the folder and restarts the add-on
- **THEN** Pi, Claude Code, Codex and OpenCode sessions all list `my-skill` as an available skill

#### Scenario: Shared instructions
- **WHEN** the user edits `AGENTS.md` in the folder
- **THEN** new agent sessions receive those instructions

#### Scenario: Secrets stay private
- **WHEN** the user logs into an agent or Paseo saves its state
- **THEN** no credential, session or key-pair file is written to the editable folder

#### Scenario: Paseo-managed skills do not pollute the folder
- **WHEN** Paseo installs or updates its own bundled skills
- **THEN** those skills are not written into the user's editable `skills/` folder and user skills are never deleted by Paseo

### Requirement: Voice and dictation options
The add-on SHALL expose options to enable dictation and voice mode and to choose the speech provider (`local` or `openai`). Both features SHALL be disabled by default.

#### Scenario: Default install has no speech models
- **WHEN** the add-on starts with default options
- **THEN** dictation and voice mode are unavailable in the Paseo UI and no local speech models are downloaded

#### Scenario: Enable local dictation
- **WHEN** the user enables dictation with the `local` speech provider and restarts
- **THEN** the dictation control is available in the Paseo UI and the required local models are downloaded into persistent storage once

#### Scenario: OpenAI speech
- **WHEN** the user enables voice mode with the `openai` speech provider and supplies `OPENAI_API_KEY` via the environment options
- **THEN** voice mode uses OpenAI for speech and no local speech models are downloaded

#### Scenario: Local speech unsupported on platform
- **WHEN** the user enables local speech on a platform where the local speech engine cannot load
- **THEN** the daemon still starts, the Paseo UI remains usable, and the add-on log explains that local speech is unavailable

### Requirement: Worktrees location option
The add-on SHALL expose an option for the directory where Paseo creates git worktrees. By default, worktrees SHALL be created under the add-on's persistent storage.

#### Scenario: Default location
- **WHEN** the worktrees option is left empty
- **THEN** new worktrees are created in the add-on's persistent storage and survive restarts

#### Scenario: Custom location under /share
- **WHEN** the user sets the worktrees option to a path under `/share` and restarts
- **THEN** the directory is created if missing, new worktrees are created there, and existing worktrees remain usable

### Requirement: Relay option
The add-on SHALL expose an optional relay setting. When it is set, it SHALL force Paseo's encrypted relay on or off. When it is unset, the relay state SHALL remain controlled from Paseo's own UI and persist across restarts.

#### Scenario: Relay left to Paseo
- **WHEN** the relay option is unset and the user enables relay via Paseo's "Pair device" screen
- **THEN** relay stays enabled after the add-on restarts

#### Scenario: Relay forced on
- **WHEN** the user sets the relay option to on and restarts
- **THEN** the daemon connects to the Paseo relay and a phone can be paired from the Paseo UI in the HA panel without mapping any port

#### Scenario: Relay forced off
- **WHEN** the user sets the relay option to off and restarts
- **THEN** the daemon makes no relay connection, even if relay was previously enabled in Paseo

### Requirement: Settings owned by Paseo remain editable
The add-on SHALL NOT lock Paseo settings that Paseo's own Settings screen can edit at runtime, such as MCP injection, browser tools, providers, profiles, plugins and system prompt. Changes made there SHALL persist across add-on restarts.

#### Scenario: Change a setting in Paseo UI
- **WHEN** the user changes a runtime setting (e.g. auto-archive after merge) in Paseo's Settings screen and restarts the add-on
- **THEN** the setting keeps the user's value and the Paseo UI does not report it as overridden

### Requirement: Agent environment options
The add-on SHALL let users supply environment variables (e.g. provider API keys) to the daemon and agents through add-on options, and SHALL NOT print their values to the log.

#### Scenario: API key via options
- **WHEN** the user sets an environment variable option such as an API key and restarts
- **THEN** agents launched by Paseo see that variable and its value does not appear in the add-on log
