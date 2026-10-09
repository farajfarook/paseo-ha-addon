# Spec Delta

## MODIFIED Requirements

### Requirement: Provider selection option
The add-on SHALL expose one multi-select `providers` option on its Configuration tab. Its values are exactly the agent provider IDs of the pinned Paseo: its built-in providers `claude`, `codex`, `copilot`, `opencode`, `pi` and `omp` (Oh My Pi), plus the providers its bundled plugins register, `muse` (Muse Code) and `antigravity` (Antigravity). The default SHALL be `[pi]`.

#### Scenario: Fresh install
- **WHEN** the add-on is installed and started without changing its configuration
- **THEN** the `providers` option holds only `pi`, and Pi is the only provider Paseo offers

#### Scenario: Same list as Paseo
- **WHEN** the user opens the add-on Configuration tab
- **THEN** the `providers` option offers every provider the pinned Paseo can run and no others, and CI fails when the option and the pinned Paseo's provider list disagree

#### Scenario: Plugin provider offered
- **WHEN** the pinned Paseo registers a provider from one of its bundled plugins
- **THEN** that provider appears in the `providers` option like a built-in one

#### Scenario: Invalid value rejected
- **WHEN** the user saves a `providers` value that is not one of the known IDs
- **THEN** Home Assistant rejects the configuration before the add-on starts

### Requirement: Installed CLIs follow the selection
On each start, the add-on SHALL install the CLI of every selected provider, Pi included, into persistent storage and SHALL uninstall the CLI of every deselected provider it had installed. No provider CLI SHALL be part of the add-on image. Installing SHALL use the provider's distribution channel: the npm registry for providers published to npm, and the vendor's installer for the providers that are not. If the selection is unchanged and every selected provider is already at the version it would install, nothing SHALL be downloaded again.

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

#### Scenario: Deselect a vendor-installed provider
- **WHEN** the user removes `muse` from `providers` and restarts the add-on
- **THEN** every file the Muse Code installer put in persistent storage is removed, the `muse` command no longer exists in the container, and its login is kept

### Requirement: Paseo providers follow the selection
On each start, before the daemon serves clients, the add-on SHALL turn on in Paseo every selected provider whose CLI is usable, and SHALL turn off every other supported provider. The add-on's selection SHALL override changes made in Paseo's settings.

#### Scenario: Enabled providers match the selection
- **WHEN** `providers` is `[pi, claude]` and both CLIs are usable
- **THEN** Paseo offers Pi and Claude and marks Codex, Copilot, OpenCode, Oh My Pi, Muse Code and Antigravity as disabled

#### Scenario: Plugin provider enabled
- **WHEN** `providers` is `[muse]` and the `muse` CLI is usable
- **THEN** Paseo offers Muse Code, using the same per-provider enable setting as a built-in provider

#### Scenario: All providers deselected
- **WHEN** `providers` is empty and the add-on starts
- **THEN** Paseo starts and marks every supported provider as disabled

#### Scenario: Toggle in Paseo is overridden
- **WHEN** the user enables a deselected provider in Paseo's settings and then restarts the add-on
- **THEN** that provider is disabled again

### Requirement: Latest stable versions
On each start, the add-on SHALL look up the latest stable release of each selected npm-published provider's packages in the npm registry and SHALL install it when it differs from the installed version. A release marked as a prerelease SHALL NOT be installed. A maintainer-set hold for a provider SHALL take precedence over the lookup.

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

### Requirement: Failed installs never block startup
If a selected provider's CLI cannot be installed, cannot be downloaded, or does not run on the host architecture, the add-on SHALL log the failure, SHALL turn that provider off in Paseo, SHALL keep starting, and SHALL retry the install on the next start.

#### Scenario: Install fails
- **WHEN** `omp` is selected but its install fails (no network or unsupported platform)
- **THEN** the add-on log shows the failure, Paseo starts with Oh My Pi disabled, the other selected providers still work, and the next start tries the install again

#### Scenario: Vendor installer unreachable
- **WHEN** `antigravity` is selected, its CLI is not installed and the vendor's installer cannot be downloaded
- **THEN** the add-on log shows the failure, Paseo starts with Antigravity disabled, and the next start tries the install again

## ADDED Requirements

### Requirement: Vendor-installed providers
The add-on SHALL install a selected provider whose CLI is not published to npm with the vendor's own installer, into a directory of its own under persistent storage that is on the agents' PATH. It SHALL NOT look such a provider up in the npm registry, and SHALL NOT download anything for one whose CLI already answers its version check. It SHALL record and log the version that CLI reports. Upgrade of such a provider is the CLI's own responsibility.

#### Scenario: Install on selection
- **WHEN** the user adds `muse` to `providers` and restarts the add-on
- **THEN** the Muse Code installer runs into `/data/agents/bin/muse`, `muse --version` succeeds there, and the `Providers:` log line names the reported version

#### Scenario: Already installed
- **WHEN** the add-on restarts with a provider whose CLI already answers its version check, even after that CLI has updated itself
- **THEN** nothing is downloaded for it and the log line names the version the CLI now reports

#### Scenario: Nothing downloaded when not selected
- **WHEN** the add-on starts with `providers` set to `[pi]`
- **THEN** no vendor installer is fetched and no second provider directory is created

#### Scenario: Installer times out or is refused
- **WHEN** the vendor's installer fails, times out, or its CLI does not run afterwards
- **THEN** the add-on log shows the failure, Paseo starts with that provider disabled, and the next start tries again

#### Scenario: Installer exits non-zero after installing
- **WHEN** the vendor's installer exits non-zero but its CLI answers its version check afterwards
- **THEN** the add-on treats the provider as installed and enabled, logs the exit code, and does not reinstall it on the next start

### Requirement: Removing a vendor-installed provider
Deselecting a vendor-installed provider SHALL remove its whole directory from persistent storage, and SHALL NOT delete its login, credentials or configuration.

#### Scenario: Uninstall keeps the login
- **WHEN** the user deselects `muse`, restarts, then selects it again and restarts
- **THEN** the provider directory is removed and recreated, and Muse Code is still logged in

