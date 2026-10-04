# git-auth Specification

## Purpose
Lets agents running in the add-on authenticate to git remotes and GitHub, using the GitHub CLI login or SSH keys the user already has, with credentials that persist and are never logged.

## Requirements

### Requirement: GitHub CLI is available
The add-on image SHALL include a pinned GitHub CLI (`gh`) on the `PATH` of terminals and agents, on every supported architecture.

#### Scenario: gh in a Paseo terminal
- **WHEN** the user runs `gh --version` in a Paseo terminal
- **THEN** it prints the pinned version

### Requirement: GitHub login persists
A GitHub CLI login made from a Paseo terminal SHALL persist across add-on restarts, updates and host reboots, and SHALL be included in Home Assistant backups of the add-on.

#### Scenario: Login survives an update
- **WHEN** the user runs `gh auth login` and later updates the add-on
- **THEN** `gh auth status` still reports the same account without a new login

### Requirement: git uses the GitHub CLI for GitHub over HTTPS
On each start, when no credential helper is configured for `https://github.com` in the add-on's global git configuration, the add-on SHALL configure the GitHub CLI as the credential helper for `https://github.com` and `https://gist.github.com`. A helper the user configured SHALL be left unchanged.

#### Scenario: Push after gh login
- **WHEN** the user is signed in with `gh auth login` and an agent pushes to an `https://github.com/...` remote
- **THEN** the push authenticates with the gh login and does not prompt

#### Scenario: Token from env_vars
- **WHEN** the user adds `GH_TOKEN` (or `GITHUB_TOKEN`) through `env_vars` and never runs `gh auth login`
- **THEN** `gh` commands and git over HTTPS to GitHub authenticate with that token

#### Scenario: User helper preserved
- **WHEN** the user has set their own `credential.https://github.com.helper`
- **THEN** the add-on does not change it on start

### Requirement: Existing SSH keys are used automatically
On each start, the add-on SHALL make `ssh` and `git` offer the unencrypted private keys found in `/homeassistant/.ssh` and `/share/.ssh`, in addition to keys in the add-on's own `~/.ssh`. Keys SHALL be used from where they are and SHALL NOT be copied.

#### Scenario: Key in the HA config folder
- **WHEN** `/homeassistant/.ssh/id_ed25519` exists and the add-on starts
- **THEN** `ssh` in a Paseo terminal offers that key to remote hosts, and no copy of it exists under `/data`

#### Scenario: Key removed
- **WHEN** a previously discovered key is deleted and the add-on restarts
- **THEN** `ssh` no longer references it

#### Scenario: Add-on's own key
- **WHEN** the user creates a key with `ssh-keygen` in a Paseo terminal
- **THEN** it is stored under `/data/home/.ssh`, persists across restarts, and is offered by `ssh`

#### Scenario: User ssh config takes precedence
- **WHEN** the user's `~/.ssh/config` sets an `IdentityFile` for a host
- **THEN** that setting applies, and the discovered keys are offered only as additional identities

### Requirement: Discovered keys are made usable
When a discovered private key is readable by group or others, the add-on SHALL restrict its permissions to owner-only so that `ssh` accepts it, and SHALL log which file it changed. Passphrase-protected keys SHALL be skipped with a warning, because agents cannot enter a passphrase.

#### Scenario: Key copied in through Samba
- **WHEN** `/share/.ssh/id_rsa` has mode `644`
- **THEN** after start its mode is `600`, the start log names the file, and `ssh` uses it

#### Scenario: Passphrase-protected key
- **WHEN** a discovered key needs a passphrase
- **THEN** it is not offered, and the start log warns that it was skipped and why

### Requirement: Host keys never block agents
`ssh` in the add-on SHALL trust `known_hosts` files in the discovered key folders and bundled host keys for GitHub, GitLab and Bitbucket. It SHALL accept an unknown host's key on first connection and remember it persistently. It SHALL refuse a host whose key changed.

#### Scenario: First clone from GitHub
- **WHEN** an agent clones `git@github.com:owner/repo.git` on a fresh install
- **THEN** no host-key prompt appears and the bundled GitHub key is used to verify the host

#### Scenario: Self-hosted Gitea
- **WHEN** an agent first connects to an SSH host with no known key
- **THEN** the key is accepted without a prompt and stored under `/data/home/.ssh/known_hosts`

#### Scenario: Changed host key
- **WHEN** a host presents a key that differs from the recorded one
- **THEN** the connection fails with ssh's host-key mismatch error

### Requirement: Git access is visible and secrets are never logged
Each start SHALL log the paths of the SSH keys in use and whether the GitHub CLI is signed in (or has a token). Key contents, tokens and passphrases SHALL never be logged.

#### Scenario: Start log
- **WHEN** the add-on starts with one discovered key and a gh login
- **THEN** the log has a line naming the key path and stating that gh is signed in, and contains no key material or token

### Requirement: Git access is documented with its trust trade-off
The documentation SHALL describe each way to give agents git access (GitHub CLI login, token in `env_vars`, existing SSH keys, a new key made in a Paseo terminal) and how to set a git identity. The security section SHALL state that any agent session can use these credentials to read and push to every repository they reach, and SHALL recommend narrowly scoped credentials.

#### Scenario: Documentation tab
- **WHEN** the user opens the add-on documentation
- **THEN** a "Git access" section covers each route, and the security section lists git credentials with the scoped-credential recommendation
