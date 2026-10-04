# Tasks

## 1. Image

- [x] 1.1 Remove the Pi install, `ARG PI_VERSION`, `PASEO_HA_PI_VERSION`, the `io.hass.pi.version` label and `pi --version` from `paseo/Dockerfile`, and `PI_VERSION` from `paseo/build.yaml`. Verify that the amd64 image builds, `paseo --version` runs in it, and `command -v pi` finds nothing
- [x] 1.2 Change `init-paseo.sh:154` to log the Paseo version only. Verify with `grep -rn PASEO_HA_PI_VERSION paseo` that nothing is left

## 2. Provider hook (design D1–D5)

- [x] 2.1 In `20-providers.sh`, replace `PROVIDER_SPECS` with package names (add `[pi]="@earendil-works/pi-coding-agent"`, installed with the same npm flags as the rest, no `--ignore-scripts`), and remove the `pi` special case from `provider_runs`. Verify that with `providers: [pi]` the hook installs Pi into `/data/agents` and `pi --version` runs in a Paseo terminal
- [x] 2.2 Resolve `<name>@latest` per selected package with `timeout 20 npm view … version`, reject prerelease versions, and build the desired `id=name@ver …` lines. Add the empty `PACKAGE_HOLD` map and use a held version instead of the lookup. Verify with `bash -n` and `shellcheck`
- [x] 2.3 On lookup failure, keep the stamped line when the CLI runs; otherwise skip the install and leave the provider disabled (D3). Verify with the test seam from 3.1 that a stamped provider stays enabled and an unstamped one is disabled
- [x] 2.4 Roll back a failed upgrade to the stamped version and record the failed spec in `/data/agents/.paseo-ha-providers.failed`; skip a recorded spec on later starts and clear it when `latest` moves (D4). Verify with the test seam from 3.1
- [x] 2.5 Log one summary line per start with each enabled provider's version and whether the update check ran (D7). Verify in the add-on log

## 3. Tests

- [x] 3.1 Add test seams to `20-providers.sh`: `PASEO_HA_TEST_LATEST="name=ver,…"` overrides the lookup result per package, `PASEO_HA_TEST_FAIL_SPEC="name@ver,…"` fails installs of those exact specs, `PASEO_HA_TEST_OFFLINE=1` makes every lookup fail, and `PASEO_HA_TEST_FAIL_INSTALL` keeps failing installs as it does now
- [x] 3.2 Rework `paseo/tests/providers/run.sh`: default `[pi]` installs Pi; deselecting Pi removes `pi`; same selection and same `latest` runs no `npm install`; a newer `latest` upgrades; an offline start keeps installed providers and disables uninstalled ones; a failing upgrade rolls back and is not retried; credentials survive deselect. Verify the script passes against the built image
- [x] 3.3 Guard `36-pi-packages.sh` with `ph_have pi` (D6) and add a check that with `providers: []` the hook exits 0, records nothing in `pi-packages.offered`, and that selecting Pi on the next start installs the defaults
- [x] 3.4 Update `paseo/tests/docs/run.sh` to stop requiring the Pi pin in the CHANGELOG, and adjust the smoke and agent-config tests for Pi being installed at runtime (both need network). Verify all three pass

## 4. Documentation and release

- [x] 4.1 Update `paseo/DOCS.md`: the providers table (Pi installed on start like the rest), how versions are chosen (latest stable on every start, rollback, hold), "Known limitations" (first start needs internet; a new agent release reaches users on their next restart). Update the `providers` text in `paseo/translations/en.yaml`. Verify `bash paseo/tests/docs/run.sh` passes
- [x] 4.2 Update the intros in `README.md` and `paseo/README.md` that describe Pi as bundled, and the "Bumping Paseo" steps in `README.md` that mention `PI_VERSION`. Verify with `grep -rni "bundled\|PI_VERSION" README.md paseo/README.md`
- [x] 4.3 Bump `version` in `paseo/config.yaml` and add a CHANGELOG entry: Pi is no longer in the image, all providers install their latest stable release on start, the first start after the update downloads Pi. Verify the docs and version checks pass
- [x] 4.4 Align the other specs: `add-paseo-ha-addon` was archived while this change was in progress, so its "Bundled Pi harness" requirement now lives in `openspec/specs/agent-runtime/spec.md`. Remove it with an `agent-runtime` delta in this change (`add-default-pi-packages`, also archived, is left as a historical record). Verify `openspec validate --all` passes

## 5. Integration

- [x] 5.1 On a real HA instance (amd64 and aarch64), update an existing install: Pi is downloaded on the first start, Pi logins and packages are kept, and the log shows the provider summary line. Restart again: no downloads (Marked done by the owner; not run by the agent. Image-level equivalents passed: providers test incl. offline and rollback, agent-config with a mock registry, smoke test, all on amd64.)
- [x] 5.2 Restart with the host's internet blocked: the add-on starts, installed providers keep working, and the log says the update check was skipped (Marked done by the owner; not run by the agent. Image-level equivalents passed: providers test incl. offline and rollback, agent-config with a mock registry, smoke test, all on amd64.)
