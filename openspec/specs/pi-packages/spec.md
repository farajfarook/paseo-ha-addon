# pi-packages Specification

## Purpose
Gives Pi a maintainer-curated set of default packages (extensions, skills, prompts, themes) while letting each user add or remove Pi packages with Pi's own commands. Those choices persist across add-on restarts, updates and backup restores.

## Requirements

### Requirement: Default Pi packages are installed once
The add-on SHALL ship a list of default Pi package sources. On start it SHALL install each default that has never been offered on this installation into Pi's global (user) settings, then record that default as offered.

#### Scenario: First start installs defaults
- **WHEN** the add-on starts for the first time and the default list contains `npm:example-pkg`
- **THEN** `pi list` in a Paseo terminal shows `npm:example-pkg` and the package's resources load in new Pi sessions

#### Scenario: Restart does not reinstall
- **WHEN** the add-on restarts and every default has already been offered
- **THEN** no package install is attempted for the defaults

### Requirement: Removed defaults stay removed
A default package the user removes with `pi remove` SHALL NOT be reinstalled by the add-on on any later start, including after an add-on update.

#### Scenario: User removes a default
- **WHEN** the user runs `pi remove npm:example-pkg`, restarts the add-on, and then updates to a newer add-on version
- **THEN** `pi list` does not show `npm:example-pkg`

### Requirement: User-installed packages persist
Packages the user installs with `pi install` (global scope) SHALL remain installed and loaded after add-on restarts and add-on updates. The add-on SHALL NOT remove or change Pi packages it did not install.

#### Scenario: User package survives update
- **WHEN** the user runs `pi install npm:my-pkg` and the add-on is then updated to a new image version
- **THEN** `pi list` still shows `npm:my-pkg` and its resources load in new Pi sessions

### Requirement: New defaults in later releases reach existing installations
When an add-on update adds a source to the default list, the add-on SHALL install that source once on the first start after the update. This SHALL happen even if the user has removed other defaults.

#### Scenario: Release adds a default
- **WHEN** an installation that already offered `npm:a` updates to a release whose list is `npm:a`, `npm:b`
- **THEN** `npm:b` is installed on the next start and `npm:a` is left as the user has it

### Requirement: Default identity ignores version
A default SHALL count as offered by its package identity: npm package name, or git repository without ref. A later release that only changes the version or ref of an offered default SHALL NOT reinstall it or change the user's installed version.

#### Scenario: Pin bump in default list
- **WHEN** the default list changes `npm:a@1.0.0` to `npm:a@2.0.0` and `npm:a` was already offered
- **THEN** the add-on does not run an install for `npm:a`

### Requirement: Failed default installs are retried and non-fatal
If installing a default fails (no network, missing package, or an install error), the add-on SHALL log a warning naming the source, SHALL still start, and SHALL NOT record that default as offered. The next start then tries again.

#### Scenario: Offline first start
- **WHEN** the add-on starts without network access and a default has not been offered
- **THEN** the add-on starts normally, logs a warning for that default, and installs it on a later start that has network access

### Requirement: Package state is persistent and backed up
Pi package settings, installed package files and the offered-defaults record SHALL live in the add-on's private persistent storage. They SHALL survive restarts and image updates and SHALL be included in Home Assistant backups.

#### Scenario: Backup restore
- **WHEN** a Home Assistant backup containing the add-on is restored
- **THEN** the installed Pi packages and the record of which defaults were offered are restored, and removed defaults are not reinstalled

### Requirement: Installed packages are visible in the log
On each start the add-on SHALL log the Pi package sources configured in Pi's global settings.

#### Scenario: Start log
- **WHEN** the add-on starts with packages installed
- **THEN** the add-on log contains a line listing the installed Pi package sources
