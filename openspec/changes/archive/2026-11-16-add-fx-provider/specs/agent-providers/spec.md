## MODIFIED Requirements

### Requirement: Provider selection option
The add-on SHALL expose one multi-select `providers` option on its Configuration tab. Its values are exactly the agent provider IDs of the pinned Paseo: its built-in providers `claude`, `codex`, `copilot`, `opencode`, `pi` and `omp` (Oh My Pi), plus the providers its bundled plugins register, `muse` (Muse Code), `antigravity` (Antigravity) and `fx` (fx, from Paseo 0.16.0). Providers the owner deliberately excludes SHALL NOT be offered: `hoplite` (Hoplite, a sponsored plugin provider bundled from Paseo 0.11.3). An excluded provider SHALL be a plugin provider that Paseo only registers once it is configured, and the add-on SHALL never install its CLI or write its per-provider override. A supported plugin provider that Paseo only registers once it is configured (`fx`) SHALL be registered through the same per-provider override the add-on writes for every supported provider, so it needs no setup in Paseo's own provider catalog. The default SHALL be `[pi]`.

#### Scenario: Fresh install
- **WHEN** the add-on is installed and started without changing its configuration
- **THEN** the `providers` option holds only `pi`, and Pi is the only provider Paseo offers

#### Scenario: Same list as Paseo
- **WHEN** the user opens the add-on Configuration tab
- **THEN** the `providers` option offers every provider the pinned Paseo can run except the excluded ones, and no others, and CI fails when the option and the pinned Paseo's provider list (minus the excluded providers) disagree

#### Scenario: Plugin provider offered
- **WHEN** the pinned Paseo registers a provider from one of its bundled plugins and that provider is not excluded
- **THEN** that provider appears in the `providers` option like a built-in one

#### Scenario: Plugin provider that needs configuration
- **WHEN** `providers` includes `fx`, the `fx` CLI is usable and the add-on starts
- **THEN** the add-on writes the `fx` per-provider override, Paseo registers and offers fx without the user adding it from Paseo's provider catalog, and when `fx` is not selected the override marks it disabled

#### Scenario: Excluded provider not offered
- **WHEN** the pinned Paseo bundles the Hoplite plugin provider and the add-on starts with any `providers` value
- **THEN** `hoplite` is not a value of the `providers` option, no Hoplite CLI is installed, and Paseo does not offer Hoplite

#### Scenario: Excluded provider would appear on its own
- **WHEN** a new pinned Paseo makes an excluded provider built in, or registers it without requiring configuration
- **THEN** CI fails the provider check, because Paseo would offer that provider without the add-on enabling it

#### Scenario: Invalid value rejected
- **WHEN** the user saves a `providers` value that is not one of the known IDs
- **THEN** Home Assistant rejects the configuration before the add-on starts

### Requirement: Paseo providers follow the selection
On each start, before the daemon serves clients, the add-on SHALL turn on in Paseo every selected provider whose CLI is usable, and SHALL turn off every other supported provider. The add-on's selection SHALL override changes made in Paseo's settings.

#### Scenario: Enabled providers match the selection
- **WHEN** `providers` is `[pi, claude]` and both CLIs are usable
- **THEN** Paseo offers Pi and Claude and marks Codex, Copilot, OpenCode, Oh My Pi, Muse Code, Antigravity and fx as disabled

#### Scenario: Plugin provider enabled
- **WHEN** `providers` is `[muse]` and the `muse` CLI is usable
- **THEN** Paseo offers Muse Code, using the same per-provider enable setting as a built-in provider

#### Scenario: All providers deselected
- **WHEN** `providers` is empty and the add-on starts
- **THEN** Paseo starts and marks every supported provider as disabled

#### Scenario: Toggle in Paseo is overridden
- **WHEN** the user enables a deselected provider in Paseo's settings and then restarts the add-on
- **THEN** that provider is disabled again
