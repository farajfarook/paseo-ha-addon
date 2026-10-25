## ADDED Requirements

### Requirement: Existing standalone OMP discovery
When OMP is selected and $HOME/.local/bin/omp successfully reports its version,
the add-on SHALL enable it and put its directory on the daemon PATH without
attempting to install or update OMP through npm.

#### Scenario: Restart with standalone OMP
- **WHEN** the providers hook runs repeatedly with a working standalone OMP
- **THEN** OMP remains enabled and resolvable from the generated daemon environment

#### Scenario: Standalone binary is unusable
- **WHEN** the standalone OMP is missing or its version check fails
- **THEN** the existing managed npm installation and fallback behavior apply

#### Scenario: Deselect OMP
- **WHEN** the user deselects a previously discovered standalone OMP
- **THEN** the provider is disabled and the standalone executable is retained
