# agent-providers Specification

## Purpose
Lets users pick the Paseo agent providers they want in one add-on option. The add-on then keeps the installed agent CLIs and Paseo's enabled providers in line with that choice.

## Requirements

### Requirement: Provider selection option
The add-on SHALL expose one multi-select `providers` option on its Configuration tab. Its values are exactly Paseo's agent provider IDs: `claude`, `codex`, `copilot`, `opencode`, `pi` and `omp` (Oh My Pi). The default SHALL be `[pi]`.

#### Scenario: Fresh install
- **WHEN** the add-on is installed and started without changing its configuration
- **THEN** the `providers` option holds only `pi`, and Pi is the only provider Paseo offers

#### Scenario: Same list as Paseo
- **WHEN** the user opens the add-on Configuration tab
- **THEN** the `providers` option offers the same six providers Paseo supports and no others

#### Scenario: Invalid value rejected
- **WHEN** the user saves a `providers` value that is not one of the six IDs
- **THEN** Home Assistant rejects the configuration before the add-on starts

### Requirement: Installed CLIs follow the selection
On each start, the add-on SHALL install the CLI of every selected provider into persistent storage and SHALL uninstall the CLI of every deselected provider it had installed. If the selection and pinned versions have not changed, nothing SHALL be downloaded again.

#### Scenario: Select a provider
- **WHEN** the user adds `copilot` to `providers` and restarts the add-on
- **THEN** the Copilot CLI is installed and runnable inside the add-on

#### Scenario: Deselect a provider
- **WHEN** the user removes `codex` from `providers` and restarts the add-on
- **THEN** the Codex CLI is uninstalled from persistent storage

#### Scenario: Unchanged selection
- **WHEN** the add-on restarts with the same `providers` value and pinned versions
- **THEN** no provider CLI is downloaded again

#### Scenario: Oh My Pi runtime
- **WHEN** the user selects `omp`
- **THEN** the Oh My Pi CLI and the runtime it needs are installed, and both are removed when `omp` is deselected

### Requirement: Built-in Pi
Pi SHALL stay in the add-on image whether or not it is selected, so selecting it needs no download and deselecting it uninstalls nothing.

#### Scenario: Pi deselected
- **WHEN** the user removes `pi` from `providers` and restarts
- **THEN** the `pi` command still exists in the container, but Paseo does not offer Pi as a provider

### Requirement: Paseo providers follow the selection
On each start, before the daemon serves clients, the add-on SHALL turn on in Paseo every selected provider whose CLI is usable, and SHALL turn off every other supported provider. The add-on's selection SHALL override changes made in Paseo's settings.

#### Scenario: Enabled providers match the selection
- **WHEN** `providers` is `[pi, claude]` and both CLIs are usable
- **THEN** Paseo offers Pi and Claude and marks Codex, Copilot, OpenCode and Oh My Pi as disabled

#### Scenario: All providers deselected
- **WHEN** `providers` is empty and the add-on starts
- **THEN** Paseo starts and marks all six providers as disabled

#### Scenario: Toggle in Paseo is overridden
- **WHEN** the user enables a deselected provider in Paseo's settings and then restarts the add-on
- **THEN** that provider is disabled again

### Requirement: Failed installs never block startup
If a selected provider's CLI cannot be installed or does not run on the host architecture, the add-on SHALL log the failure, SHALL turn that provider off in Paseo, SHALL keep starting, and SHALL retry the install on the next start.

#### Scenario: Install fails
- **WHEN** `omp` is selected but its install fails (no network or unsupported platform)
- **THEN** the add-on log shows the failure, Paseo starts with Oh My Pi disabled, the other selected providers still work, and the next start tries the install again

### Requirement: Credentials survive deselection
Deselecting a provider SHALL NOT delete its login, credentials or configuration from persistent storage.

#### Scenario: Re-select a provider
- **WHEN** the user deselects `claude`, restarts, then selects it again and restarts
- **THEN** Claude is reinstalled and is still logged in
