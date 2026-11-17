# Tasks

## 1. Guidance
- [x] 1.1 `ha-cli.md`: `ha apps` / deprecated `ha addons` alias described without a CLI major version
- [x] 1.2 `paseo/DOCS.md`: same wording in the `ha` CLI line of "What agents can do with Home Assistant"

## 2. Verification
- [x] 2.1 In the built image (`ha` 6.0.0): `ha apps --help` and `ha addons --help` both work, `ha addons info <slug>` prints the deprecation warning, and `ha --version` is still not a flag
- [x] 2.2 docs test passes
