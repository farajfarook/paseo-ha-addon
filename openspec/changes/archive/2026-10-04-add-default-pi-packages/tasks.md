# Tasks

## 1. Default list and hook

- [x] 1.1 Add `paseo/rootfs/opt/paseo-ha/pi-packages.default` with a header comment explaining the format (one Pi source per line, pin versions, `#` comments) and the five pinned sources from design D3a (`@juicesharp/rpiv-todo@2.12.0`, `@juicesharp/rpiv-ask-user-question@2.12.0`, `pi-subagents@0.75.0`, `pi-provider-litellm@3.3.0`, `pi-web-access@0.35.0`); verify the file is copied into the image (`docker run --rm paseo-ha-test cat /opt/paseo-ha/pi-packages.default`)
- [x] 1.2 Add `paseo/rootfs/etc/paseo-ha/init.d/36-pi-packages.sh`: parse the default list, compute the package identity (npm name without version; git host/path without ref; normalise `https://` URLs) and read/write the ledger `/data/paseo-ha/pi-packages.offered`. Verify with `bash -n` and shellcheck (Lint workflow)
- [x] 1.3 In the hook, implement the offer logic (design D2): skip identities already in the ledger; record without installing when `pi list` already has the same identity; otherwise `timeout 300 pi install <source>` with `PI_SKIP_VERSION_CHECK=1`, recording only on success. Verify against a local package source in a container
- [x] 1.4 Implement failure handling and logging (D4/D5): a warning with the source plus a tail of the output on failure; skip installs when `PI_OFFLINE` is set; always exit 0; log one final `Pi packages: ...` line from `pi list`. Verify by pointing a default at a non-existent npm package and checking that the add-on still starts and logs the warning

## 2. Tests

- [x] 2.1 Extend `paseo/tests/agent-config/run.sh` with a test-only default list (bind-mount over `/opt/paseo-ha/pi-packages.default`) that points at a local git or npm-tarball package fixture under `paseo/tests/agent-config/`, so no network is needed. Verify that on first start `pi list` shows it and the ledger contains its identity
- [x] 2.2 Add scenarios: restart does not reinstall (no install log line); `pi remove` and then restart → still absent; user `pi install` of a second fixture survives restart; adding a new default to the list → installed on the next start while the removed one stays absent; a version-only change does not reinstall; a broken source → warning, add-on ready, identity not in the ledger. Verify `paseo/tests/agent-config/run.sh` passes locally
- [x] 2.3 Simulate an image update by recreating the container (new `docker run` with the same `/data`) rather than restarting it, and check that user-installed and default packages are still listed and removed defaults stay absent. Verify that the test step passes

## 3. Documentation and release

- [x] 3.1 Add a "Pi packages" section to `paseo/DOCS.md`. It covers: defaults are installed once; how to manage packages with `pi install`/`pi remove`/`pi list`/`pi config`/`pi update --extensions` from a Paseo terminal; removed defaults stay removed; how to restore a default; deleting `/data/paseo-ha/pi-packages.offered` resets; offline behaviour. Also include a table of the five defaults: what each one adds in Paseo, and how to configure it (LiteLLM via `/login litellm` or `LITELLM_BASE_URL`/`LITELLM_API_KEY` in `env_vars`; web-access keys in `env_vars` or `web-search.json`; no YouTube/video without `yt-dlp`/`ffmpeg`). Add `/data/home/.pi/agent/npm` and the ledger to the `/data` row. Verify that `paseo/tests/docs/run.sh` passes
- [x] 3.2 Add a short note to `paseo/rootfs/opt/paseo-ha/config-seed/README.md` that Pi packages are managed with `pi install`/`pi remove`, not through files in `/config`. Verify that the seeded README in a fresh container contains it
- [x] 3.3 Bump `version` in `paseo/config.yaml` and add a matching `paseo/CHANGELOG.md` entry that lists the default packages. Verify `.github/scripts/check-version.sh v<version>` and that the Lint workflow passes

## 4. Integration

- [x] 4.0 On a real start with network access, verify that all five defaults install on both amd64 and aarch64 (Alpine/musl) and that Pi loads them without errors (`pi list`, plus a Pi session in Paseo that shows the todo panel and a structured question)
- [x] 4.1 Build the amd64 image and run `paseo/tests/smoke/run.sh` and `paseo/tests/agent-config/run.sh`. Then manually install the add-on on a test HA instance, update it to a locally built newer tag, and confirm in the Paseo terminal that `pi list` keeps the user's changes
