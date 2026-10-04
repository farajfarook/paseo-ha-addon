# Spec Delta

## Purpose

Defines how the Paseo web UI is exposed inside Home Assistant: as a sidebar web application served through HA Ingress, authenticated by Home Assistant, plus an optional direct port.

## ADDED Requirements

### Requirement: Sidebar panel
The add-on SHALL register a Home Assistant sidebar panel titled "Paseo" that opens the Paseo web UI embedded in the Home Assistant frontend.

#### Scenario: Panel appears after start
- **WHEN** the add-on is started with "Show in sidebar" enabled
- **THEN** a "Paseo" entry with a Paseo-representative icon appears in the HA side menu

#### Scenario: Open Paseo from the side menu
- **WHEN** the user clicks the "Paseo" sidebar entry
- **THEN** the Paseo web UI loads inside Home Assistant without any extra login, host-pairing or "Add Host" step

### Requirement: Fully functional UI under ingress
All Paseo web UI features, including live agent streams over WebSocket, API calls, static assets and client-side navigation, SHALL work when the UI is served under the Home Assistant ingress path prefix.

#### Scenario: Live agent output
- **WHEN** the user starts an agent session from the sidebar UI
- **THEN** agent output and terminal streams update in real time without the UI freezing or disconnecting

#### Scenario: Reload on a deep link
- **WHEN** the user reloads the browser while on a nested Paseo page inside the panel
- **THEN** the same page loads again inside the panel

#### Scenario: Access through HA over HTTPS
- **WHEN** Home Assistant is reached over HTTPS (e.g. Nabu Casa remote UI or a TLS reverse proxy)
- **THEN** the Paseo UI connects over a secure WebSocket and the browser reports no mixed-content errors

#### Scenario: Large prompt upload
- **WHEN** the user sends a prompt or attaches a file up to 100 MB
- **THEN** the request reaches the daemon without being rejected by the add-on

### Requirement: Home Assistant authentication on ingress
Access via the sidebar SHALL be authenticated solely by Home Assistant; the add-on SHALL NOT prompt for a Paseo password on the ingress path.

#### Scenario: Logged-in HA user
- **WHEN** a logged-in Home Assistant user with access to the panel opens Paseo
- **THEN** the UI is usable without entering a Paseo password

#### Scenario: Password configured for direct port
- **WHEN** a Paseo password is configured for direct port access
- **THEN** the ingress path still works without the user entering that password

### Requirement: Ingress-only network exposure by default
With default options, the Paseo web UI and daemon SHALL be reachable only through Home Assistant ingress; no host port SHALL be published and requests not originating from the HA ingress proxy SHALL be rejected.

#### Scenario: Default install
- **WHEN** the add-on runs with default options
- **THEN** connecting directly to the HA host on the Paseo port fails and only the sidebar panel serves Paseo

#### Scenario: Request from another container
- **WHEN** another container on the internal Supervisor network sends a request to the add-on's ingress port from an address other than the ingress proxy
- **THEN** the request is rejected

### Requirement: Optional password-protected direct port
The add-on SHALL allow users to map a host port for direct access (for the Paseo mobile/desktop apps or CLI); direct access SHALL require a Paseo password.

#### Scenario: Direct port with password
- **WHEN** the user sets a password and maps the direct port
- **THEN** Paseo clients connecting to `<ha-host>:<port>` must supply that password to use the API and WebSocket

#### Scenario: Direct port without password
- **WHEN** the user maps the direct port but leaves the password empty
- **THEN** the direct port refuses connections and the add-on log explains that a password is required

#### Scenario: Custom DNS name
- **WHEN** the user lists extra hostnames in the add-on options and connects to the direct port using one of them
- **THEN** the daemon accepts the request instead of returning "Host not allowed"
