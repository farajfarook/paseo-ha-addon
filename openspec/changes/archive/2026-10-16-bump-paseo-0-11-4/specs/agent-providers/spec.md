## MODIFIED Requirements

### Requirement: Provider selection option
The add-on SHALL expose one multi-select `providers` option on its Configuration tab. Its values are exactly the agent provider IDs of the pinned Paseo: its built-in providers `claude`, `codex`, `copilot`, `opencode`, `pi` and `omp` (Oh My Pi), plus the providers its bundled plugins register, `muse` (Muse Code) and `antigravity` (Antigravity). Providers the owner deliberately excludes SHALL NOT be offered: `hoplite` (Hoplite, a sponsored plugin provider bundled from Paseo 0.11.3). An excluded provider SHALL be a plugin provider that Paseo only registers once it is configured, and the add-on SHALL never install its CLI or write its per-provider override. The default SHALL be `[pi]`.

#### Scenario: Fresh install
- **WHEN** the add-on is installed and started without changing its configuration
- **THEN** the `providers` option holds only `pi`, and Pi is the only provider Paseo offers

#### Scenario: Same list as Paseo
- **WHEN** the user opens the add-on Configuration tab
- **THEN** the `providers` option offers every provider the pinned Paseo can run except the excluded ones, and no others, and CI fails when the option and the pinned Paseo's provider list (minus the excluded providers) disagree

#### Scenario: Plugin provider offered
- **WHEN** the pinned Paseo registers a provider from one of its bundled plugins and that provider is not excluded
- **THEN** that provider appears in the `providers` option like a built-in one

#### Scenario: Excluded provider not offered
- **WHEN** the pinned Paseo bundles the Hoplite plugin provider and the add-on starts with any `providers` value
- **THEN** `hoplite` is not a value of the `providers` option, no Hoplite CLI is installed, and Paseo does not offer Hoplite

#### Scenario: Excluded provider would appear on its own
- **WHEN** a new pinned Paseo makes an excluded provider built in, or registers it without requiring configuration
- **THEN** CI fails the provider check, because Paseo would offer that provider without the add-on enabling it

#### Scenario: Invalid value rejected
- **WHEN** the user saves a `providers` value that is not one of the known IDs
- **THEN** Home Assistant rejects the configuration before the add-on starts
