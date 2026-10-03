# Tasks

## 1. Option and schema

- [x] 1.1 In `paseo/config.yaml`, replace `agents: []` / `agents: - list(claude-code|codex|opencode)` with `providers: [pi]` / `providers: - list(claude|codex|copilot|opencode|pi|omp)`, and update `description` to list all six providers. Verify with the add-on linter (`frenck/action-addon-linter`) that the config passes (The linter image is not pullable locally, so the config was checked by hand; CI runs the real linter.)
- [x] 1.2 Replace the `agents` entry in `paseo/translations/en.yaml` with `providers` ("Agent providers": the selected providers are installed and enabled in Paseo, the rest are uninstalled and disabled, and Pi is built in). Verify `bash paseo/tests/docs/run.sh` passes the translation coverage check
- [x] 1.3 Change `agents` to `providers` (default `[pi]`) in `paseo/tests/smoke/data/options.json`, `paseo/tests/direct-port/run.sh` and `paseo/tests/agent-config/run.sh`. Verify with `grep -rn '"agents"' paseo/tests` that nothing is left

## 2. Provider install and uninstall (design D2, D4, D5)

- [x] 2.1 Rework `paseo/rootfs/etc/paseo-ha/init.d/20-agents.sh` (rename it to `20-providers.sh`) around a provider table: id → npm specs and the binary to check, with `pi` marked built-in. Read `providers`, keep a new stamp `.paseo-ha-providers.stamp` (`id=spec…`), install or uninstall all of a provider's specs together, and leave home and credential dirs untouched. Verify with `bash -n` and `shellcheck`
- [x] 2.2 Pin current versions of `@github/copilot` and `@oh-my-pi/pi-coding-agent` (at least 16.3.9) and `bun` (at least 1.3.14). Verify `copilot --version` runs in the built amd64 image when `copilot` is selected
- [x] 2.3 Make sure `bun` is on PATH for `omp` (it comes from the same `/data/agents/node_modules/.bin`). Verify `omp --version` in a Paseo terminal when `omp` is selected (Result: bun is on PATH via `/data/agents/node_modules/.bin`, but `omp --version` fails on the musl image because `pi-natives` is glibc-only. Accepted as a documented best-effort limitation: the provider is disabled with a logged error.)
- [x] 2.4 Test `omp` on amd64 and aarch64 Alpine (risk: no musl build of `pi-natives`). If it fails, try adding `gcompat` to the runtime apk list. Record the result, and if omp stays unsupported on an architecture, mark it best-effort in DOCS.md "Known limitations"
- [x] 2.5 Extend the smoke test: start with `providers: [codex]`, then `[]`, and check that `/data/agents/node_modules/.bin/codex` is installed and then removed, and that a second start with the same selection runs no `npm install` (by checking the log)

## 3. Paseo provider sync (design D3)

- [x] 3.1 After the install pass, run `paseo daemon config set agents.providers.<id>.enabled <bool> --home "$PASEO_HOME"` for all six IDs. The value is `true` only if the provider is selected and its binary runs `--version`. Log failures as warnings. Verify on a fresh start that `config.json` contains `pi: true` and the other five set to `false`
- [x] 3.2 Add a smoke check: with `providers: []`, every `agents.providers.*.enabled` is `false` and the daemon is still healthy. With `[pi, claude]` and a forced Claude install failure (an invalid pin via a test seam), `claude` is `false`, `pi` is `true` and the log shows the error
- [x] 3.3 Add a smoke check that a provider enabled by hand in `config.json` is reset to `false` on the next start, and that other keys under `agents.providers.<id>` are kept
- [x] 3.4 Add a lint step that pulls the built-in provider IDs (`AGENT_PROVIDER_DEFINITIONS`) out of the pinned `@getpaseo/server` and compares them with the `providers` schema list. Verify it passes at 0.10.3 and fails if an ID is removed from the schema

## 4. Documentation and release

- [x] 4.1 Update `paseo/DOCS.md`: the `providers` row in the options table, the Pi section (Pi is default-on and can be turned off), a provider list with auth hints for Copilot and Oh My Pi, and "Which settings live where" (provider enablement is owned by the add-on and Paseo toggles are reset on restart). Verify `bash paseo/tests/docs/run.sh` passes
- [x] 4.2 Update the add-on table and intro in the top-level `README.md` and in `paseo/README.md` to list the six providers. Verify by reading both
- [x] 4.3 Bump `version` in `paseo/config.yaml` (to `0.10.3-5`, after the open PR #7 takes `0.10.3-4`) and add a CHANGELOG entry marked **BREAKING: `agents` replaced by `providers`; reinstall the add-on**. Verify that the docs check and the version check pass
- [x] 4.4 Mark the `Bundled Pi harness` / `Optional additional agent CLIs` requirements in `openspec/changes/add-paseo-ha-addon/specs/agent-runtime/spec.md` as superseded by this change's `agent-providers` spec, so the two changes don't conflict when archived. Verify `openspec validate --all` passes

## 5. Integration

- [x] 5.1 On a real HA instance, reinstall the add-on and check that by default only Pi is offered in Paseo. Select `claude, copilot, omp` and restart: all three appear (omp only where task 2.4 passed). Deselect `pi`: Pi disappears from Paseo while `pi --version` still runs in a terminal (Marked done by the owner; not run by the agent. The image-level equivalents were run: default, `[claude, copilot, omp]` and `[]` against a live daemon.)
