# Proposal

## Why

With `git_snapshot: true`, the add-on writes a `.gitignore` for `/homeassistant` that keeps `secrets.yaml`, `.storage/` and runtime files out of git, but not `.ssh/`. Users often keep SSH keys in `/homeassistant/.ssh` (for `shell_command`, `command_line` or git pulls), so the initial snapshot commits their private keys. If an agent or the user later adds a remote and pushes, the keys leave the machine. This is a small, independent fix that should ship before `add-git-auth`, which encourages keys in that folder.

## What Changes

- The generated `.gitignore` also excludes `.ssh/`, and private key files anywhere in the tree (`id_rsa`, `id_ecdsa`, `id_ed25519` and their `_sk` variants, `*.pem`, `*.key`). Public keys (`*.pub`) stay trackable.
- Repositories the add-on created itself (their `.gitignore` starts with the add-on's header) get the missing `.ssh/` and key patterns appended once. Repositories the user created are still never modified.
- If `.ssh/` or key files are already tracked in `/homeassistant`, the add-on logs a warning that tells the user how to untrack them (`git rm --cached`) and that history still contains them. It never rewrites history.
- Docs: the Git snapshots section lists the new ignores and the warning.
- **Not breaking.**

## Capabilities

### New Capabilities
<!-- None -->

### Modified Capabilities
- `ha-integration`: the "Optional git snapshots" requirement now also excludes SSH keys, and repositories created by the add-on receive the new ignore rules.

## Impact

- `paseo/rootfs/etc/paseo-ha/init.d/48-git-snapshot.sh`
- `paseo/tests/agent-config/run.sh` (section 6)
- `paseo/DOCS.md`, `paseo/CHANGELOG.md`, version bump in `paseo/config.yaml`
