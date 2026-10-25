# Design

Keep Paseo's native `codex app-server` launch. No daemon workaround is needed:
installing procps fixes the CLI process identity query.

The top AppArmor profile retains Docker-like mount denial. Executing the native
Codex binary in the persistent npm install or managed daemon package enters a
local codex profile. Only that profile allows mount, remount, pivot_root and
umount. These are AppArmor allowances, not new Linux capabilities: the container
still lacks CAP_SYS_ADMIN in its initial user namespace. Bubblewrap must create
an unprivileged user namespace before these operations can succeed. Its final
command drops capabilities and uses the Codex filesystem policy and seccomp.

Retain proc/sys write protections and an enforcing profile. Do not change
container seccomp, protection mode, namespace sysctls, or mapped host files.
Mount permissions are broader within the Codex child profile; a compromised
Codex process can construct its own user-namespace mounts. Host validation must
check the capability bounding set, confinement, negative file-write tests, and
the actual Bubblewrap command before release.

Codex configuration remains in /data/home/.codex/config.toml. Set supported
sandbox_mode, approval_policy and sandbox_workspace_write.network_access there;
Paseo reads them and already supports equivalent provider options. Do not widen
writable roots for caches: use workspace-local package caches.
