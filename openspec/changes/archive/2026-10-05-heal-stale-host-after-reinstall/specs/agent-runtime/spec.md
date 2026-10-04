# Spec Delta

## ADDED Requirements

### Requirement: Stable daemon identity
The daemon SHALL keep the same server ID across restarts and add-on updates. When the Home Assistant instance UUID is readable, it SHALL also get the same server ID back after a reinstall of the same add-on on the same instance. An existing server ID SHALL never be changed by the add-on.

#### Scenario: Restart and update
- **WHEN** the add-on is restarted or updated
- **THEN** the daemon reports the same server ID as before

#### Scenario: Reinstall
- **WHEN** the add-on is uninstalled and installed again on the same Home Assistant instance, its data was wiped, and the instance UUID is readable on both installs
- **THEN** the daemon reports the same server ID it reported after the earlier install, as long as that install also started with fresh data under this behaviour

#### Scenario: Existing installation
- **WHEN** an installation that already has a server ID is updated to a release with this behaviour
- **THEN** its server ID is kept unchanged

#### Scenario: No Home Assistant instance ID
- **WHEN** the Home Assistant instance UUID cannot be read on a fresh start
- **THEN** the add-on still starts, and the daemon uses a new random server ID that it keeps across restarts and updates, but not across a later reinstall
