# Tasks

## 1. Paseo 0.11.1 (proposal)

- [x] 1.1 Raise the pin to `0.11.1` in `paseo/build.yaml` (`PASEO_VERSION`) and in both `ARG PASEO_VERSION=` lines of `paseo/Dockerfile`, and set `version: "0.11.1-1"` in `paseo/config.yaml`. Verify `bash paseo/tests/docs/run.sh` passes its pin checks
- [x] 1.2 Re-check the ingress anchors of the new pin: `.github/scripts/paseo-anchors.sh --diff 0.10.3 0.11.1` (already known clean) and `.github/scripts/paseo-anchors.sh --check 0.11.1`
- [x] 1.3 Add the `## 0.11.1-1` entry at the top of `paseo/CHANGELOG.md`, naming the bundled Paseo **0.11.1** and Pi **1.1.0** and the two new providers. Verify `bash paseo/tests/docs/run.sh` accepts it

- [x] 1.4 Make the smoke test's `/ws` upgrade check retry for up to 10 s (`paseo/tests/smoke/run.sh`): a just-started 0.11.1 daemon answers `/api/health` before its WebSocket listener binds, so exactly one upgrade right after start gets a 503 (measured: 000 x7, 503 x1, then 101). Verified: the smoke suite passed twice in a row against the built image
- [x] 1.5 Fix the two log-hygiene checks in `paseo/tests/agent-config/run.sh` to stream `docker logs` into grep instead of passing the whole log as one argument: with 0.11.1's per-plugin start logs the log exceeds the kernel's 128 KB single-argument limit (`Argument list too long`), which made the checks fail although no key or token was logged

## 2. Script-installer path in the providers hook (design D1, D2, D3)

- [x] 2.1 In `paseo/rootfs/etc/paseo-ha/init.d/20-providers.sh`, add the two provider IDs to `ALL_PROVIDERS`, a `PROVIDER_KIND` map defaulting to `npm`, and the per-provider script maps: `SCRIPT_URL`, `SCRIPT_SHELL`, `SCRIPT_ARGS`, `SCRIPT_ENV` and `PROVIDER_BIN_DIR` (`muse` → `muse`/`$MUSE_INSTALL_DIR`, `antigravity` → `agy`/`--dir`). Update the header comment. Verify `bash -n` and `shellcheck`
- [x] 2.2 Resolve provider binaries through their own directory: a `provider_bin` helper used by `provider_runs` and by the version that goes into the `Providers:` log line, so an npm provider keeps using `/data/agents/node_modules/.bin` and a script provider uses `/data/agents/bin/<id>`
- [x] 2.3 Add the script install path: download the vendor installer with `curl -fsSL` (with the test seam) to a temp file, run it with the provider's shell, arguments and install-directory variable under the existing `INSTALL_TIMEOUT`, then require `<bin> --version` to succeed. Record `bin@<reported version>` in the stamp; never reinstall a provider whose CLI already runs; do not write `.paseo-ha-providers.failed` for script providers; clean `agents/bin/<id>` before an install attempt so a partial download cannot linger
- [x] 2.4 Make uninstall kind-aware: `npm_uninstall` for npm providers, `rm -rf` of the provider's directory for script providers, keeping the existing "retry next start when it fails" behaviour. Make the `npm_pkg_name` spec-splitting calls unreachable for script providers
- [x] 2.5 Add `PASEO_HA_TEST_SCRIPT_URL` as a documented test seam next to the existing ones, accepting a local file path so tests can use a stub installer without network access
- [x] 2.6 Put the directory of each selected script provider on the daemon PATH from the hook (`ph_env_prepend_path`, next to the existing npm bin dir), so a selected provider works from the first start without adding provider IDs to `init-paseo.sh`. Verify `bash -n` and `shellcheck` on the hook

## 3. Option, translations and documentation

- [x] 3.1 Extend the `providers` enum in `paseo/config.yaml` to `list(claude|codex|copilot|opencode|pi|omp|muse|antigravity)` with the default unchanged, and update the `providers` name/description in `paseo/translations/en.yaml`
- [x] 3.2 Update the `providers` row in `paseo/DOCS.md`: the eight providers, which come from npm and which from their vendor installer, that Muse Code is a ~336 MB download and Antigravity needs an `agy` sign-in, and that selecting one downloads it on the next start. Add to "Known limitations" that agents on Muse Code and Antigravity do not get the bundled Home Assistant skill, instructions or MCP tools yet. Verify `bash paseo/tests/docs/run.sh` passes

## 4. CI provider gate (design D4)

- [x] 4.1 Extend `.github/scripts/check-providers.sh` to read the providers registered by Paseo's bundled plugins (`dist/server/builtin-plugins/*-provider`) from their `provider.ts` registration and to add them to the built-in ID list before comparing with the schema; fail with a clear message when no plugin providers are found or the plugin layout is unrecognised. Verify `shellcheck .github/scripts/check-providers.sh`, that it passes for `0.11.1` with the extended schema, and that it still fails for a schema that is missing one of the eight
- [x] 4.2 Keep the `<capability>` comment and the README/AGENTS wording in step with the widened check (it is no longer "exactly Paseo's built-in providers")

## 5. Tests (design D5 and the test seams)

- [x] 5.1 Extend `paseo/tests/providers/run.sh`: a stub installer written into the container and served through `PASEO_HA_TEST_SCRIPT_URL` that installs a fake `muse`/`agy` reporting a fixed version. Cover install on selection (files in the provider directory, `muse` runnable), the stamp carrying the reported version, no re-download on an unchanged selection, the "already running after a self-update" case, uninstall on deselection (directory gone, `$HOME` login file kept), a failing installer (`PASEO_HA_TEST_FAIL_INSTALL`), and a stub whose CLI does not run
- [x] 5.2 Update the existing assertions for eight providers: every `expect_enabled` list and the "all disabled" case name `muse=false antigravity=false` too, and the "no vendor installer is fetched" case asserts nothing was created under `/data/agents/bin`
- [x] 5.3 Verify against the built image: `docker build -t paseo-smoke:ci paseo && paseo/tests/providers/run.sh paseo-smoke:ci` (needs network for npm), plus `paseo/tests/smoke/run.sh paseo-smoke:ci`. Result: image builds with Paseo 0.11.1; providers suite 120 PASS / 0 FAIL; smoke suite passes

## 6. Verification

- [x] 6.1 `bash paseo/tests/docs/run.sh`, `shellcheck paseo/rootfs/etc/paseo-ha/init.d/*.sh .github/scripts/*.sh`, `bash -n` on the touched hooks
- [x] 6.2 Check the real vendor installers once by hand on a Linux host, in a throwaway directory, and record the observed versions: Muse Code's static artifact and Antigravity's musl artifact for `amd64`, and `muse --version` / `agy --version` succeeding from the directory the hook would pass. (Not run in CI: it would download ~336 MB per run). Result: `Muse Code 1.4.4 (1.4.4-R5419.1)` (payload statically linked, installer needs bash) and `agy` `1.3.2` (installed into `--dir`); the `linux_amd64_musl` manifest serves 1.3.2
- [x] 6.3 Confirm the direct-port and agent-config suites still pass, since the hook and PATH changes are shared with every provider. Result: direct-port passes; agent-config passes after task 1.5 (its earlier failures were the argument-size test bug and a mock registry left over from an aborted parallel run)
- [ ] 6.4 Deferred to `verify-paseo-011-ingress-browser`: run the browser-based `paseo/tests/ingress/run.sh` against the 0.11.1 image. The ingress anchors are unchanged and the smoke suite's curl-level ingress checks pass
