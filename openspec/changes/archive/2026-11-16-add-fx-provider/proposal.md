## Why

Paseo 0.16.0 bundles a new plugin provider, `fx` ("Vercel Labs' tiny, open, native coding agent", run as `fx acp`; `dist/server/builtin-plugins/fx-provider/server/provider.ts`). The `providers` option must list exactly the pinned Paseo's providers minus the excluded ones, so with the 0.16.0 pin `check-providers.sh` fails until the add-on either offers fx or excludes it:

```
Paseo 0.16.0 plugin providers:      antigravity fx hoplite muse
add-on schema providers:            antigravity claude codex copilot muse omp opencode pi
ERROR: the providers option in paseo/config.yaml does not match Paseo 0.16.0's providers
```

fx can run inside the add-on, so it is supported like Muse Code and Antigravity rather than excluded like Hoplite:

- It is open source (Apache-2.0, Vercel Labs), not a sponsored or paid cloud service. It sends model requests to the provider the user signs in to (Vercel AI Gateway account or API key, a ChatGPT subscription, or Grok).
- It is not on npm. Its documented installer (`curl -fsSL https://fx.sh/setup.sh | bash`) is a bash script that downloads `releases.fx.sh/<version>/fx-linux-<x86_64|aarch64>.tar.gz` into `$FX_INSTALL_DIR` (default `~/.local/bin`). Both release binaries are statically linked ELF executables (checked with `file` for v0.0.17), so they run on the Alpine (musl) images.
- Checked in the add-on image (Alpine 3.24, x86_64): the real installer with `FX_INSTALL_DIR=/data/agents/bin/fx` installs fx 0.0.17, `fx --version` prints `0.0.17`, and `fx acp` answers an ACP `initialize` request (without a sign-in it answers with "fx needs access to Vercel AI Gateway. Run fx login ... or set AI_GATEWAY_API_KEY"). With the install directory already on `PATH` (the hook puts it there before installing) the installer does not touch shell profile files. fx keeps its state and credentials in `~/.fx` (`/data/home/.fx`, persistent) and updates itself (`fx upgrade`, background updates).
- Paseo registers fx with `requiresConfiguration: true` (like Hoplite): it only registers the provider once `agents.providers.fx` exists. The add-on's hook already writes `agents.providers.<id>.enabled` for every supported provider on every start, so with fx in `ALL_PROVIDERS` the override always exists: enabled when fx is selected and its CLI runs, disabled otherwise (`provider-registry.js`: an override registers the plugin provider; `enabled` decides whether it is offered). The Paseo 0.16.0 provider catalog's "fx" entry (`bundledProvider`, `hostFeature: fxProvider`) is then redundant inside the add-on: the add-on option is the place to select it, and the add-on overrides catalog toggles on the next start like any other provider toggle.

## What Changes

- `paseo/rootfs/etc/paseo-ha/init.d/20-providers.sh`: add `fx` to `ALL_PROVIDERS` as a script (vendor-installed) provider: binary `fx`, directory `/data/agents/bin/fx`, installer `https://fx.sh/setup.sh` run with `bash` and `FX_INSTALL_DIR=/data/agents/bin/fx`. Header comments name nine providers and the configuration-required case. No new mechanism: install, `--version` check, stamp, uninstall, PATH and enable flag use the existing script-provider path.
- `paseo/config.yaml`: `fx` added to the `providers` enum (`list(...|antigravity|fx)`) and to the add-on description; default stays `[pi]`.
- `paseo/translations/en.yaml`: the `providers` description names fx and says it comes from its vendor's installer.
- `paseo/DOCS.md`: options row, intro, "Agent providers" (three bundled plugin providers; fx is configured by the add-on instead of the provider catalog), provider table row (installer URL, `fx login` / `AI_GATEWAY_API_KEY`), "update themselves" bullet, login steps (`fx login`), credentials path `~/.fx`, troubleshooting rows, and the known limitation that fx (like Muse Code and Antigravity) gets no Home Assistant setup (HA skill, instructions, HA MCP server) from the add-on.
- `paseo/tests/providers/run.sh`: the stub vendor installer also handles `FX_INSTALL_DIR`; every "all providers" assertion includes `fx`; new checks: fx installed into its own directory and stamped at the version its CLI reports, enabled, named in the `Providers:` line, its directory on the daemon PATH, not reinstalled while it runs, removed on deselection with `~/.fx` kept, and its override written (disabled) when not selected.
- `.github/scripts/check-providers.sh`: comment only (fx is a bundled plugin provider from 0.16.0); the check itself is unchanged and now passes for 0.16.0.
- Repo docs (exempt from Rule 1, updated for consistency): root `README.md`, `paseo/README.md` (also lists Muse Code and Antigravity, which it was missing), `SECURITY.md`, the bug report template's provider list.
- Spec delta for `agent-providers`: the "Provider selection option" requirement names `fx`, and says a supported plugin provider that Paseo only registers once configured is registered through the add-on's per-provider override; "Paseo providers follow the selection" lists fx among the disabled providers.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `agent-providers`: MODIFIED requirements "Provider selection option" and "Paseo providers follow the selection".

## Impact

- `paseo/rootfs/etc/paseo-ha/init.d/20-providers.sh` and `paseo/config.yaml` (shipped; released with the version bump of the `bump-paseo-0-16-0` change in the same PR).
- `paseo/translations/en.yaml`, `paseo/DOCS.md`, `paseo/README.md`, `paseo/tests/providers/run.sh`, `.github/scripts/check-providers.sh` (not shipped), plus the exempt repo docs above.
- Users who select `fx` get a ~4-9 MB download into `/data/agents/bin/fx` on the next start and sign in with `fx login` in a Paseo terminal or `AI_GATEWAY_API_KEY` in `env_vars`. Users who do not select it see no change (nothing is downloaded; Paseo lists fx as disabled).
