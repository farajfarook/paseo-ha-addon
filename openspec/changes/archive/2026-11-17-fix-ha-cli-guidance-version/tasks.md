# Tasks

## 1. Guidance
- [x] 1.1 `ha-cli.md`: `ha apps` / deprecated `ha addons` alias described without a CLI major version
- [x] 1.2 `paseo/DOCS.md`: same wording in the `ha` CLI line of "What agents can do with Home Assistant"
- [x] 1.3 `ha-cli.md`: no longer points to `ha info` for the CLI version (it reports system information); says `ha` has no `--version` flag or `version` command

## 2. Verification
- [x] 2.1 In the built image (`ha` 6.0.0): `ha apps --help` and `ha addons --help` both work, `ha addons info <slug>` prints the deprecation warning, and `ha --version` is still not a flag
- [x] 2.2 docs test passes
