# Spec Delta

## MODIFIED Requirements

### Requirement: Installed CLIs follow the selection
On each start, the add-on SHALL install the CLI of every selected provider, Pi included, into persistent storage and SHALL uninstall the CLI of every deselected provider it had installed. No provider CLI SHALL be part of the add-on image. If the selection is unchanged and every selected provider is already at the version it would install, nothing SHALL be downloaded again.

#### Scenario: Select a provider
- **WHEN** the user adds `copilot` to `providers` and restarts the add-on
- **THEN** the Copilot CLI is installed and runnable inside the add-on

#### Scenario: Deselect a provider
- **WHEN** the user removes `codex` from `providers` and restarts the add-on
- **THEN** the Codex CLI is uninstalled from persistent storage

#### Scenario: Deselect Pi
- **WHEN** the user removes `pi` from `providers` and restarts the add-on
- **THEN** the `pi` command no longer exists in the container and Paseo does not offer Pi

#### Scenario: Unchanged selection
- **WHEN** the add-on restarts with the same `providers` value and no selected provider has a newer stable release
- **THEN** no provider CLI is downloaded again

#### Scenario: Oh My Pi runtime
- **WHEN** the user selects `omp`
- **THEN** the Oh My Pi CLI and the runtime it needs are installed, and both are removed when `omp` is deselected

## ADDED Requirements

### Requirement: Latest stable versions
On each start, the add-on SHALL look up the latest stable release of each selected provider's packages in the npm registry and SHALL install it when it differs from the installed version. A release marked as a prerelease SHALL NOT be installed. A maintainer-set hold for a provider SHALL take precedence over the lookup.

#### Scenario: New release published
- **WHEN** Claude is selected and a newer stable version of its CLI has been published since the last start
- **THEN** the next start installs the newer version and the add-on log names it

#### Scenario: Prerelease on the latest tag
- **WHEN** the registry's latest version for a selected provider is a prerelease
- **THEN** the add-on keeps the installed version and logs that the update was skipped

#### Scenario: Registry unreachable
- **WHEN** the add-on starts without access to the npm registry and Pi is already installed
- **THEN** Pi keeps its installed version, Paseo offers it, and the log says the update check was skipped

#### Scenario: Registry unreachable on a fresh install
- **WHEN** a new installation starts with the default `providers` value and no access to the npm registry
- **THEN** the add-on starts, Paseo marks Pi as disabled, the log explains why, and the next start tries again

### Requirement: Broken upgrades roll back
If a newer version of a provider installs but its CLI does not run, the add-on SHALL restore the previously installed version, SHALL keep that provider enabled, and SHALL NOT try the same failed version again on later starts.

#### Scenario: Upgrade fails its check
- **WHEN** the latest Codex release installs but `codex --version` fails
- **THEN** the previous Codex version is reinstalled and stays enabled, the log names the failed version, and the next start does not download that version again

#### Scenario: Fixed release follows
- **WHEN** a later stable Codex release is published after a failed one
- **THEN** the next start installs the later release

### Requirement: Pi-dependent setup waits for Pi
Setup steps that need the Pi CLI (installing default Pi packages and adding the Home Assistant MCP server to Pi) SHALL be skipped while Pi is not installed, and SHALL run on the first start after Pi is installed.

#### Scenario: Pi not installed
- **WHEN** `pi` is not selected, or its install failed
- **THEN** the add-on starts without errors from the Pi package or Pi MCP steps, and no default Pi package is recorded as offered

#### Scenario: Pi installed later
- **WHEN** Pi is installed on a later start
- **THEN** that start installs the default Pi packages

## REMOVED Requirements

### Requirement: Built-in Pi
**Reason**: Pi is installed at runtime like every other provider so it can follow the latest stable release and be uninstalled when deselected.
**Migration**: None needed. The first start after the update installs Pi into persistent storage when it is selected. Pi's logins, settings and packages are kept.
