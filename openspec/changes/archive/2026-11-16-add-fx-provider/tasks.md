# Tasks

## 1. Investigation
- [x] 1.1 Confirm the cause of the provider-check failure: Paseo 0.16.0 bundles `fx-provider` (`id: "fx"`, `command: ["fx", "acp"]`, `requiresConfiguration: true`), and `check-providers.sh 0.16.0` reports `fx` as a plugin provider missing from the option
- [x] 1.2 Run the real vendor installer in the add-on image with `FX_INSTALL_DIR=/data/agents/bin/fx`; `fx --version` succeeds; `fx acp` answers an ACP `initialize`; both release binaries (x86_64, aarch64) are statically linked; the installer leaves shell profiles alone when the directory is on `PATH`
- [x] 1.3 Confirm in Paseo 0.16.0 (`provider-registry.js`) that a configuration-required plugin provider is registered once `agents.providers.<id>` exists, so the add-on's enable flag registers fx (enabled or disabled)

## 2. Providers hook and option
- [x] 2.1 `20-providers.sh`: add `fx` to `ALL_PROVIDERS`, `PROVIDER_BIN`, `PROVIDER_KIND` (script), `PROVIDER_BIN_DIR`, `SCRIPT_URL`, `SCRIPT_SHELL` and `SCRIPT_ENV` (`FX_INSTALL_DIR`); update the header comments (nine providers, configuration-required plugin providers)
- [x] 2.2 `paseo/config.yaml`: add `fx` to the `providers` enum and the add-on description
- [x] 2.3 `paseo/translations/en.yaml`: name fx in the `providers` description
- [x] 2.4 `.github/scripts/check-providers.sh`: comment names fx; the check passes for 0.16.0 and still fails for 0.15.4 (which has no fx) with the extended option

## 3. Documentation
- [x] 3.1 `paseo/DOCS.md`: options row, intro, Agent providers section and table, update/login/credentials text, troubleshooting rows, known limitation (no HA setup for fx)
- [x] 3.2 `paseo/README.md`, root `README.md`, `SECURITY.md`, bug report template: list fx

## 4. Tests
- [x] 4.1 `paseo/tests/providers/run.sh`: stub installer handles `FX_INSTALL_DIR`; all-provider assertions include fx; fx install, stamp, enable, summary line, PATH, no reinstall, removal on deselection with `~/.fx` kept, disabled override written while not selected
- [x] 4.2 shellcheck and `bash -n` on the hook and the test; providers suite passes on the built image
- [x] 4.3 Live check on the built image: with `providers: [pi, fx]` the real installer runs, the start log names fx, and `paseo provider ls` lists fx; with `[pi]` it lists fx as disabled and nothing is downloaded
