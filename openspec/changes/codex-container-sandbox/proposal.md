# Codex execution in the Home Assistant container

Codex 0.164.0 uses procps-compatible `ps` to identify its shared app-server.
BusyBox ps does not implement the required arguments. Docker's default AppArmor
profile separately denies the mount operations required by Codex's bundled
Bubblewrap, including inside an unprivileged user namespace.

Ship procps in the runtime image and an enforcing add-on-specific AppArmor
profile. Allow namespace mount setup only in a child profile entered by the
native Codex executables, retaining the container capability bounding set and
the default proc/sys protections. Document supported workspace-write/network
settings and the mandatory deployment validation. Do not disable isolation or
add SYS_ADMIN to the container.

Scope: paseo/Dockerfile, paseo/apparmor.txt, paseo/config.yaml,
paseo/CHANGELOG.md, paseo/DOCS.md, and a sandbox integration test.

This is a prepared, unreleased change. Host deployment requires a maintenance
window and validation; it is not installed by copying files inside the running
container.
