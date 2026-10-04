# Spec Delta

## MODIFIED Requirements

### Requirement: Optional git snapshots
The add-on SHALL offer an option, off by default, that keeps the Home Assistant configuration under git. Agents SHALL then be instructed to commit before and after each change so users can review and roll back.

#### Scenario: Option off by default
- **WHEN** the add-on runs with default options
- **THEN** the add-on creates no git repository in the HA configuration directory

#### Scenario: Enable snapshots
- **WHEN** the user enables git snapshots and restarts
- **THEN** the HA configuration directory is a git repository whose ignore rules exclude `secrets.yaml`, `.storage/`, `.ssh/`, private SSH key files, databases, logs and other runtime files, and an initial commit exists

#### Scenario: SSH keys never enter the initial snapshot
- **WHEN** the HA configuration directory contains `.ssh/id_ed25519` and the user enables git snapshots
- **THEN** the initial commit does not contain any file under `.ssh/` or any private key file

#### Scenario: Add-on-created repository gains new ignore rules
- **WHEN** the repository was created by an earlier version of the add-on and its add-on-written `.gitignore` lacks the SSH rules
- **THEN** the add-on appends the missing rules once and leaves every other line and the history unchanged

#### Scenario: Existing repository respected
- **WHEN** the HA configuration directory is already a git repository that the add-on did not create
- **THEN** the add-on does not reinitialise it or change its ignore rules

#### Scenario: Tracked keys are reported
- **WHEN** files under `.ssh/` or private key files are already tracked in the HA configuration repository
- **THEN** the add-on logs a warning naming the files and how to untrack them, without changing the repository

#### Scenario: Roll back an agent change
- **WHEN** snapshots are enabled and an agent's change breaks the configuration
- **THEN** the user (or agent) can restore the previous state by reverting the agent's commit
