# Spec Delta

## ADDED Requirements

### Requirement: Panel recovers from a changed daemon identity
When the browser remembers the panel's daemon under a server ID that differs from the running daemon's, the sidebar panel SHALL drop that stale host before the UI starts and connect to the running daemon without any user action. It SHALL NOT remove hosts that point at other endpoints.

#### Scenario: Reinstall with a new server ID
- **WHEN** the browser has used the panel before, and the daemon now reports a different server ID (for example after a reinstall that wiped its data or a restore from an older backup)
- **THEN** opening the panel connects to the running daemon and shows its sessions, and the panel does not stay on "Reconnecting to host"

#### Scenario: Deep link into the stale host
- **WHEN** the panel opens on a page under the stale server ID, or the remembered last workspace belongs to it
- **THEN** the UI opens at its start page for the running daemon instead of the stale page

#### Scenario: Other hosts are kept
- **WHEN** the browser also remembers hosts reached through other endpoints (relay or another daemon)
- **THEN** those hosts are left unchanged

#### Scenario: Same daemon
- **WHEN** the remembered server ID matches the running daemon's
- **THEN** the browser's host list, routes and cached sessions are left untouched
