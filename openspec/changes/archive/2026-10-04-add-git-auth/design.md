# Design

## Context

- The runtime image already has `git` and `openssh-client`. `HOME=/data/home` and `XDG_CONFIG_HOME=/data/home/.config` are persistent, private, and part of backups (init-paseo.sh, design D6 of `add-paseo-ha-addon`). Agents and terminals run as root.
- `/homeassistant` and `/share` are mapped read-write, so keys the user keeps there are visible. Other add-ons' private `/data` (for example the SSH & Web Terminal add-on's `~/.ssh`) is not visible and is out of reach by design.
- Init hooks in `/etc/paseo-ha/init.d/*.sh` run in lexical order before the daemon, are non-fatal, and see the daemon env, including `env_vars` (`GH_TOKEN` etc.). `48-git-snapshot.sh` already writes `safe.directory` to the global gitconfig.
- The build stage already downloads a pinned static binary (the `ha` CLI) by `BUILD_ARCH`/`TARGETARCH`. gh ships static `linux_amd64` and `linux_arm64` tarballs with a `checksums.txt` per release.
- `fix-snapshot-ignore-ssh` keeps `/homeassistant/.ssh` out of git snapshots and should land first.

## Goals / Non-Goals

**Goals:**
- Zero-config for the common cases: a gh login or a key in `/homeassistant/.ssh` or `/share/.ssh` just works for agents.
- Never prompt inside an agent session (host keys, passphrases, credentials).
- Leave anything the user configured themselves (`~/.ssh/config`, git credential helpers) in charge.

**Non-Goals:**
- No reading of other add-ons' options or secrets through the Supervisor API (for example the Git pull add-on's `deployment_key`). The add-on has the access, but quietly harvesting another add-on's credentials is a trust violation.
- No new add-on option (such as `ssh_key_paths`). It can be added later if users keep keys elsewhere.
- No ssh-agent and no passphrase handling.
- No GitLab or Gitea CLIs. They work through SSH keys or HTTPS tokens the user sets up.
- No automatic `git config user.name/email`. That is documented: the user or agent sets it, or uses `gh` to fetch it.

## Decisions

### D1. Install gh as a pinned release binary in the build stage
Download `gh_${GH_CLI_VERSION}_linux_${amd64|arm64}.tar.gz`, verify it against the release's `checksums.txt`, and copy `bin/gh` to `/usr/local/bin/gh` in the runtime image, mirroring the `ha` CLI. The version is pinned with `ARG GH_CLI_VERSION` (current: 2.102.0).
- *Alternative: `apk add github-cli`.* Simpler, but the version follows the Alpine base image and can change silently between add-on builds. Rejected for reproducibility, which the "Pinned Paseo version" spirit asks for.
- *Alternative: install at runtime into `/data` like the providers.* It adds network to startup for no gain. gh is small (about 15 MB compressed) and stateless.

### D2. gh state stays in the default location
gh reads `$XDG_CONFIG_HOME/gh` (`/data/home/.config/gh`), which already persists. Inside the container there is no keyring, so `gh auth login` stores the token in `hosts.yml` (mode 600). Nothing to configure. `GH_TOKEN`/`GITHUB_TOKEN` from `env_vars` are already in every agent's environment, and gh uses them natively.

### D3. Credential helper: `gh auth setup-git` semantics, only when unset
On each start, if `git config --global --get-all credential.https://github.com.helper` is empty, the hook writes the same entries `gh auth setup-git` would write (an empty helper reset, then `!/usr/local/bin/gh auth git-credential`) for `https://github.com` and `https://gist.github.com`. It writes them directly, because `gh auth setup-git` refuses to run when the user is not logged in. The helper works with either a login or `GH_TOKEN`, and with neither it fails quietly, so git falls back to its normal behaviour. A user-set helper is never touched (spec: "User helper preserved").

### D4. SSH keys: a generated system ssh_config drop-in, not `~/.ssh/config`
The hook writes `/etc/ssh/ssh_config.d/paseo-ha.conf` from scratch on every start (it is outside `/data`, so it never goes stale across updates):

```
Host *
  IdentityFile ~/.ssh/id_rsa
  IdentityFile ~/.ssh/id_ecdsa
  IdentityFile ~/.ssh/id_ed25519
  IdentityFile /homeassistant/.ssh/id_ed25519      # one line per discovered key
  IdentitiesOnly no
  GlobalKnownHostsFile /opt/paseo-ha/ssh_known_hosts /homeassistant/.ssh/known_hosts ...
  UserKnownHostsFile ~/.ssh/known_hosts
  StrictHostKeyChecking accept-new
  BatchMode yes
```

- ssh reads `~/.ssh/config` before the system config, and for most options the first value wins, so a user's `~/.ssh/config` always takes precedence (spec: "User ssh config takes precedence"). `IdentityFile` accumulates, which is what we want: discovered keys become extra identities.
- The default `~/.ssh/id_*` lines are listed explicitly, because once any `IdentityFile` is set ssh stops adding the defaults.
- Alpine's `/etc/ssh/ssh_config` includes `/etc/ssh/ssh_config.d/*.conf`. The image build verifies this (`ssh -G localhost | grep identityfile`).
- `BatchMode yes` makes ssh fail instead of prompting for a password or passphrase inside an agent. Users who want an interactive prompt in a terminal can override it in `~/.ssh/config`.
- *Alternative: generate `~/.ssh/config`.* It would conflict with a file the user owns, which lives in persistent `/data`, so it would need merge markers. Rejected.
- *Alternative: copy or symlink keys into `~/.ssh`.* Copies go stale and leave key material in a second place, in every backup. Symlinks break when the source is removed. Rejected (spec: no copy).

### D5. Discovery rules
- Folders: `/homeassistant/.ssh` and `/share/.ssh`, one level deep only.
- A file is a candidate when its first line is a PEM/OpenSSH private-key header (`-----BEGIN ... PRIVATE KEY-----`), whatever its name. That catches `deploy_key`, `github`, etc., and skips `*.pub`, `known_hosts`, `config` and `authorized_keys`.
- Permissions: if a candidate is group- or other-readable, `chmod 600` it and log the path. This changes a user file, but it is the only change, it is safe for a root-only container, and without it ssh refuses the key. Logged so it is never silent.
- Passphrase check: `ssh-keygen -y -P '' -f <key>` succeeds only for unencrypted keys. Encrypted keys are skipped with a warning (agents run with `BatchMode yes` and cannot unlock them).
- Order: `/homeassistant/.ssh` before `/share/.ssh`, files sorted by name, so behaviour is deterministic. ssh offers at most `MaxAuthTries` (server default 6) keys per host. With more than five discovered keys the hook logs a hint to pin keys per host in `~/.ssh/config`.

### D6. Host keys
- `/opt/paseo-ha/ssh_known_hosts` ships with the published host keys for `github.com`, `gitlab.com` and `bitbucket.org` (all key types), copied from the providers' documentation pages and refreshed when the image is bumped.
- `known_hosts` files in the discovered folders are added to `GlobalKnownHostsFile`, read-only from ssh's point of view. New hosts go to `~/.ssh/known_hosts` in `/data`.
- `StrictHostKeyChecking accept-new` gives trust on first use without prompts, and still rejects changed keys (spec: "Changed host key").

### D7. Logging
One info line per start, for example `Git access: SSH keys /homeassistant/.ssh/id_ed25519, /share/.ssh/deploy; GitHub CLI signed in as <login>` (or `token from GH_TOKEN`, or `not signed in`). The login comes from `gh auth status` with a short timeout, and is skipped when offline. Separate warnings cover permission fixes and skipped keys. Key contents and tokens are never logged.

### D7a. `~/.ssh` is persistent through a link
OpenSSH resolves `~` (for `~/.ssh/config`, default identities, `known_hosts` and `ssh-keygen`'s default path) from the passwd entry, `/root`, not from `$HOME=/data/home`. `/root` is in the image, so anything written there would be lost on update. The hook links `/root/.ssh` to `/data/home/.ssh` on every start (moving anything already in a real `/root/.ssh` across first), and the generated drop-in uses absolute `/data/home/.ssh` paths.

### D8. Hook order
`47-git-auth.sh` runs after `45-ha-mcp.sh` and before `48-git-snapshot.sh`. Nothing in 48 depends on it, but keeping git setup together makes the log easier to read. The hook does no network work except the optional `gh auth status`, capped with `timeout 10`.

## Risks / Trade-offs

- [Any agent can push with the user's credentials, and the default gh login scopes reach every repo the user can access] → The docs and security section state this. They recommend a fine-grained PAT in `env_vars` (`GH_TOKEN`) or a per-repo deploy key instead of a full login.
- [Prompt injection could make an agent exfiltrate or push code] → Same trust model as the existing Core/Supervisor access. Documented, and no new mitigation.
- [`chmod 600` on a user's file surprises them] → It only removes group/other read on files that are already private keys, and it is logged per file. The alternative (copying keys) is worse.
- [`accept-new` trusts a spoofed host on first contact] → The bundled keys cover the big hosts. For others it is the same trust-on-first-use users accept interactively, and a changed key is still rejected.
- [Bundled host keys go stale if a provider rotates them] → Connections fail with a clear mismatch error. Refresh them with each gh pin bump, and the user can override in `~/.ssh/known_hosts`.
- [`BatchMode yes` blocks a user who wants to type a password in a terminal] → Documented override: `Host *` / `BatchMode no` in `~/.ssh/config`.
- [gh version drift (CLI flags, `auth git-credential`)] → Pinned. The test in tasks covers `gh --version` and that the credential helper responds.

## Migration Plan

- Existing installs: on the first start after the update, keys in `/homeassistant/.ssh` and `/share/.ssh` start being offered, and the credential helper is added if unset. Nothing is removed.
- Rollback: an older image has no gh binary and no ssh drop-in (it lives outside `/data`). The leftover helper in `/data/home/.gitconfig` points at a missing `/usr/local/bin/gh`, so git prints a helper error but still works. The rollback note in the CHANGELOG says to run `git config --global --unset-all credential.https://github.com.helper`.
