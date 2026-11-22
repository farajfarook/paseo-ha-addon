# Tasks

## 1. Investigation
- [x] 1.1 Confirm the cause of the provider-check failure: Paseo 0.17.0 bundles `goose-provider` (`id: "goose"`, `command: ["goose", "acp"]`, `requiresConfiguration: true`), and `check-providers.sh 0.17.1` reports `goose` as a plugin provider missing from the option
- [x] 1.2 Rule out npm: `@aaif/goose-acp` installs in the add-on image but its `@aaif/goose-binary-linux-x64` is a glibc binary (`spawn ... ENOENT` on Alpine)
- [x] 1.3 Run the real vendor installer in the add-on image with `GOOSE_BIN_DIR=/data/agents/bin/goose CONFIGURE=false`: it picks the musl build, `goose --version` succeeds, `goose acp` answers `initialize`, and `session/new` works once `GOOSE_PROVIDER`/`GOOSE_MODEL`/an API key are set; the musl build has no `goose update`; running the installer again replaces the binary

## 2. Providers hook and option
- [x] 2.1 `20-providers.sh`: add `goose` to `ALL_PROVIDERS`, `PROVIDER_BIN`, `PROVIDER_KIND` (script), `PROVIDER_BIN_DIR`, `SCRIPT_URL`, `SCRIPT_SHELL` and `SCRIPT_ENV` (`GOOSE_BIN_DIR`, `CONFIGURE=false`); update the header comments (ten providers, glibc-only npm package, no self-update)
- [x] 2.2 `20-providers.sh`: run every vendor installer in a scratch working directory that is removed afterwards
- [x] 2.3 `20-providers.sh`: `provider_version` returns the first non-blank line of `--version` without surrounding blanks
- [x] 2.4 `paseo/config.yaml`: add `goose` to the `providers` enum and the add-on description
- [x] 2.5 `paseo/translations/en.yaml`: name goose in the `providers` description
- [x] 2.6 `.github/scripts/check-providers.sh`: comment names goose; the check passes for 0.17.1 and still fails for 0.16.2 (which has no goose) with the extended option

## 3. Documentation
- [x] 3.1 `paseo/DOCS.md`: intro, options row, Agent providers section and table, "Which versions are installed" (goose does not update itself; the installer command that updates it), login steps, troubleshooting rows, known limitation (no HA setup for goose)
- [x] 3.2 `paseo/README.md`, root `README.md`, `SECURITY.md`, bug report template: list goose

## 4. Tests
- [x] 4.1 `paseo/tests/providers/run.sh`: stub installer handles `GOOSE_BIN_DIR` and requires `CONFIGURE=false`; all-provider assertions include goose; goose install, trimmed stamp and summary version, PATH, nothing left in the installer's working directory, enable, no reinstall, removal on deselection
- [x] 4.2 shellcheck and `bash -n` on the hook and the test; providers suite passes on the built image
- [x] 4.3 Live check on the built image: with `providers: [pi, goose]` the real installer runs, the start log says `Providers: pi 1.6.0, goose 1.60.2`, `paseo provider ls` lists goose enabled (status `available` once `GOOSE_PROVIDER`, `GOOSE_MODEL` and an API key are in `env_vars`), a restart downloads nothing, and the documented installer command updates goose in place
