# Tasks

## 1. Ignore rules

- [x] 1.1 In `paseo/rootfs/etc/paseo-ha/init.d/48-git-snapshot.sh`, add `.ssh/`, `id_rsa`, `id_ecdsa`, `id_ed25519`, `id_ecdsa_sk`, `id_ed25519_sk`, `*.pem` and `*.key` to the generated `.gitignore` (keep `*.pub` trackable). Verify with `bash -n`, shellcheck, and a fresh container where `/homeassistant/.ssh/id_ed25519` exists: `git ls-files` lists nothing under `.ssh/`
- [x] 1.2 When the repository's `.gitignore` starts with the add-on header line (`# Written by the Paseo add-on (git_snapshot)`) and lacks `.ssh/`, append the SSH block once (under a `# Added by the Paseo add-on: SSH keys` comment). Leave any other `.gitignore` alone. Verify that a second restart does not append again and a user-written `.gitignore` is byte-identical after restart
- [x] 1.3 When `/homeassistant` is a repository (any origin) and `git ls-files` matches `.ssh/` or the key patterns, log one warning naming up to five files and suggesting `git rm -r --cached .ssh` plus a note that history still contains them. Verify by committing a fake key in a test repo and checking the start log, and that the repo's HEAD is unchanged

## 2. Tests and docs

- [x] 2.1 Extend section 6 of `paseo/tests/agent-config/run.sh` with: a fake `.ssh/id_ed25519` and `.ssh/id_ed25519.pub` in the fixture HA dir before enabling snapshots → private key not tracked; an old-style add-on `.gitignore` (without `.ssh/`) → rules appended once; a user `.gitignore` → unchanged; a tracked key → warning logged. Verify the script passes against a locally built image
- [x] 2.2 Update the "Git snapshots and rollback" section of `paseo/DOCS.md` (new ignores, append-once behaviour for add-on repos, tracked-key warning and how to untrack). Bump `version` in `paseo/config.yaml` with a `paseo/CHANGELOG.md` entry. Verify `paseo/tests/docs/run.sh` passes
