# Discover an existing standalone OMP installation

The providers hook only checks its managed npm bin directory. OMP installed at
$HOME/.local/bin/omp works when invoked directly but is disabled at startup and
cannot be resolved from the daemon PATH. Reuse a working standalone OMP before
attempting an npm installation, expose its directory to the daemon, and retain
npm fallback when that binary is missing or unusable. Do not install, update or
remove the user's standalone executable.

Scope: paseo/rootfs/etc/paseo-ha/init.d/20-providers.sh,
paseo/tests/providers/standalone-omp.sh, paseo/DOCS.md, paseo/CHANGELOG.md,
and .github/workflows/lint.yaml (run the isolated regression in CI).
The existing PR's 0.13.0-2 version bump covers this change.
