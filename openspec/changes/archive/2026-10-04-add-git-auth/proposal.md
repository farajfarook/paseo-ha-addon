# Proposal

## Why

Agents in the add-on can run `git`, but they have no way to authenticate to a remote. A user who wants an agent to clone a repo, push their HA config to GitHub, or open a pull request has to work out SSH by hand inside the container. Many HA users already have keys in `/homeassistant/.ssh` or `/share/.ssh`, and Paseo ignores them. GitHub is the most common remote, and the `gh` CLI also gives agents PRs, issues and CI status, which is a big upgrade for a coding-agent add-on.

## What Changes

- **GitHub CLI in the image.** A pinned `gh` binary is installed. Users sign in once from a Paseo terminal with `gh auth login` (device code flow, works through ingress). The login is stored under `/data/home` and survives restarts, updates and backups.
- **git uses gh for GitHub over HTTPS.** On each start, if the user has not configured their own credential helper for `github.com`, the add-on sets gh as git's credential helper for `https://github.com` and `https://gist.github.com`. A `GH_TOKEN` or `GITHUB_TOKEN` added through `env_vars` works the same way, with no interactive login.
- **Existing SSH keys are used automatically.** On each start, the add-on finds private keys in `/homeassistant/.ssh` and `/share/.ssh` and makes `ssh` (and so `git`) offer them, alongside keys in the add-on's own `~/.ssh`. Keys are referenced where they are, not copied. Keys whose permissions are too open for `ssh` are tightened to `600` in place, and this is logged. Passphrase-protected keys are skipped with a warning.
- **Host keys.** `known_hosts` files next to discovered keys are trusted. GitHub, GitLab and Bitbucket host keys are bundled. Any other host is accepted on first use and remembered under `/data/home/.ssh/known_hosts`, so non-interactive agents never hang on a host-key prompt.
- **Logging.** Each start logs one line with the SSH key paths in use (never their contents) and whether gh is signed in.
- **Docs.** A new "Git access" section covers the three routes (gh login, existing keys, `ssh-keygen` in a Paseo terminal), setting a git identity, and the security trade-off: any agent can push with these credentials. The security section lists it.
- No new add-on option. **Not breaking.**

## Capabilities

### New Capabilities
- `git-auth`: how agents authenticate to git remotes and GitHub: the bundled GitHub CLI and its persistent login, the git credential helper, discovery of existing SSH keys and host keys, and the related logging and documentation.

### Modified Capabilities
<!-- None. The SSH-ignore fix for git_snapshot is a separate change: fix-snapshot-ignore-ssh. -->

## Impact

- `paseo/Dockerfile`: download and verify a pinned `gh` release in the build stage. `build.yaml` and the lint pin check gain `GH_CLI_VERSION` if pins are checked there.
- New init hook `paseo/rootfs/etc/paseo-ha/init.d/47-git-auth.sh`.
- New image files: `/opt/paseo-ha/ssh_known_hosts` (bundled host keys). The generated `/etc/ssh/ssh_config.d/paseo-ha.conf` is rebuilt on every start, outside `/data`.
- Writes to `/data/home/.gitconfig` (credential helper, only when unset) and to the permissions of key files under `/homeassistant/.ssh` and `/share/.ssh`.
- Tests: new section in `paseo/tests/agent-config/run.sh`. No network needed.
- Docs: `paseo/DOCS.md`, `paseo/CHANGELOG.md`, version bump in `paseo/config.yaml`.
- Depends on `fix-snapshot-ignore-ssh` landing first, so that encouraging keys in `/homeassistant/.ssh` cannot leak them into a git snapshot.
