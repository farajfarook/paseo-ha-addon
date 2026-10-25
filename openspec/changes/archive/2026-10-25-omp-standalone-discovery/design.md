# Design

For selected OMP only, probe $HOME/.local/bin/omp with the existing version-check
timeout. If it answers, use that bin directory for the enable check, prepend it
to the persisted daemon PATH, and report its version. Skip npm lookup/install.
Preserve an existing npm stamp so deselection can still remove managed npm
packages; never record a standalone executable as an npm spec. When standalone
OMP is missing or fails its version check, keep the current npm path unchanged.
Deselecting OMP disables the provider without deleting user-managed files.

Tests run the actual hook against temporary directories and fake npm/Paseo
commands. No live options, provider configuration or services are touched.
