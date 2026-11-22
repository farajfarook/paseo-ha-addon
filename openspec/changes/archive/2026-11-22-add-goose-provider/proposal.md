## Why

Paseo 0.17.0 bundles a new plugin provider, `goose` (`dist/server/builtin-plugins/goose-provider/server/provider.ts`: `id: "goose"`, `command: ["goose", "acp"]`, `requiresConfiguration: true`; the plugin requires Paseo >= 0.17.0). The `providers` option must list exactly the pinned Paseo's providers minus the excluded ones, so with the 0.17.1 pin `check-providers.sh` fails until the add-on either offers goose or excludes it:

```
Paseo 0.17.1 plugin providers:      antigravity fx goose hoplite muse
add-on schema providers:            antigravity claude codex copilot fx muse omp opencode pi
ERROR: the providers option in paseo/config.yaml does not match Paseo 0.17.1's providers
```

goose can run inside the add-on, so it is supported like fx, Muse Code and Antigravity rather than excluded like Hoplite:

- It is open source (Apache-2.0; `block/goose`, now `aaif-goose/goose` under the Agentic AI Foundation), not a sponsored or paid service. It sends model requests to the model provider the user configures (OpenAI, Anthropic, OpenRouter, Ollama, ...).
- Its npm package `@aaif/goose-acp` only resolves `@aaif/goose-binary-linux-<arch>`, a glibc binary: installed in the add-on image it fails with `spawn .../bin/goose ENOENT` (no glibc loader on Alpine). So it cannot be an npm provider.
- Its documented installer (`curl -fsSL https://github.com/aaif-goose/goose/releases/download/stable/download_cli.sh | bash`) is a bash script that picks the `goose-<arch>-unknown-linux-musl.tar.bz2` release asset when bash reports a musl `OSTYPE` (Alpine: `linux-musl`), and installs into `$GOOSE_BIN_DIR`. `CONFIGURE=false` skips its interactive `goose configure` step. Both x86_64 and aarch64 musl builds are published.
- Checked in the add-on image (Paseo 0.17.1, Alpine, x86_64): the real installer with `GOOSE_BIN_DIR=/data/agents/bin/goose CONFIGURE=false` installs goose 1.60.2 (~160 MB binary, ~16 s); `goose --version` prints ` 1.60.2` (leading space); `goose acp` answers an ACP `initialize`, and `session/new` succeeds once a model provider is configured (without one: "Configuration value not found: GOOSE_PROVIDER"). goose keeps its configuration and sessions under `~/.config/goose`, `~/.local/share/goose` and `~/.local/state/goose` (`/data/home`, persistent); the musl build has no system keyring.
- The musl build has no `goose update` command (`goose --help` lists none), so unlike Muse Code, Antigravity and fx it cannot update itself. Running the installer again into the same directory replaces the binary (it renames the old one out of the way first); the hook records whatever version the CLI reports on the next start. That is documented as the way to update goose, which keeps the add-on's existing script-provider mechanism unchanged.
- The installer downloads its archive into the current working directory. The hook ran installers in whatever directory the init process had (`/`), which would leave a partial ~160 MB download there on a failure, so every vendor installer now runs in a scratch directory that is removed afterwards.
- Paseo registers goose with `requiresConfiguration: true` (like fx and Hoplite): it only registers the provider once `agents.providers.goose` exists. The add-on's hook writes `agents.providers.<id>.enabled` for every supported provider on every start, so with goose in `ALL_PROVIDERS` the override always exists: enabled when goose is selected and its CLI runs, disabled otherwise. Paseo 0.17.0 also migrates a legacy hand-written `goose` entry with `extends: "acp"` to the built-in plugin (`persisted-config.js`, `normalizeAgentProviders`); the add-on only merges the `enabled` flag into whatever entry exists, so that migration is unaffected.

## What Changes

- `paseo/rootfs/etc/paseo-ha/init.d/20-providers.sh`: add `goose` to `ALL_PROVIDERS` as a script (vendor-installed) provider: binary `goose`, directory `/data/agents/bin/goose`, installer `https://github.com/aaif-goose/goose/releases/download/stable/download_cli.sh` run with `bash` and `GOOSE_BIN_DIR=/data/agents/bin/goose CONFIGURE=false`. Every vendor installer runs in a scratch working directory (`mktemp -d`, removed afterwards). `provider_version` takes the first non-blank line of `--version` and trims surrounding blanks, so goose is stamped and logged as `goose 1.60.2`. Header comments: ten providers, goose's npm package is glibc-only, goose's musl build does not update itself.
- `paseo/config.yaml`: `goose` added to the `providers` enum (`list(...|fx|goose)`) and to the add-on description; default stays `[pi]`.
- `paseo/translations/en.yaml`: the `providers` description names goose, its ~160 MB download and that it is updated by running its installer again.
- `paseo/DOCS.md`: intro, options row, "Agent providers" (four bundled plugin providers; fx and goose are configured by the add-on), provider table row (installer URL, `goose configure` or `GOOSE_PROVIDER`/`GOOSE_MODEL`/API key in `env_vars`), a "Which versions are installed" bullet saying goose does not update itself and giving the installer command that updates it, login steps (`goose configure`), troubleshooting rows, and the known limitation that goose (like Muse Code, Antigravity and fx) gets no Home Assistant setup from the add-on.
- `paseo/tests/providers/run.sh`: the stub vendor installer handles `GOOSE_BIN_DIR`, refuses to run for goose unless `CONFIGURE=false`, prints goose's version with a leading space and drops a file into its working directory; every "all providers" assertion includes `goose`; new checks: goose installed into its own directory, stamped and named in the `Providers:` line as `1.60.2`, its directory on the daemon PATH, nothing left behind from an installer's working directory, enabled, not reinstalled while it runs, removed on deselection.
- `.github/scripts/check-providers.sh`: comment only (goose is a bundled plugin provider from 0.17.0); the check itself is unchanged and now passes for 0.17.1.
- `paseo/README.md` and the root `README.md` list goose, say goose is updated by running its installer again, and qualify the Home Assistant claims: only Pi, Claude, Codex and OpenCode get the HA MCP server, and Muse Code, Antigravity, fx and goose start without the bundled HA skill and MCP tools (as DOCS.md's known limitations already say). `SECURITY.md` and the bug report template's provider list name goose (exempt from Rule 1, updated for consistency).
- Spec delta for `agent-providers`: "Provider selection option" names `goose` and lists it with fx as registered through the per-provider override; "Paseo providers follow the selection" lists goose among the disabled providers; "Vendor-installed providers" covers a CLI whose npm build cannot run on the image, the trimmed version, the scratch working directory, no prompts, and updating goose by running its installer again.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `agent-providers`: MODIFIED requirements "Provider selection option", "Paseo providers follow the selection" and "Vendor-installed providers".

## Impact

- `paseo/rootfs/etc/paseo-ha/init.d/20-providers.sh` and `paseo/config.yaml` (shipped; released with the version bump of the `bump-paseo-0-17-1` change in the same PR).
- `paseo/translations/en.yaml`, `paseo/DOCS.md`, `paseo/README.md`, `paseo/tests/providers/run.sh`, `.github/scripts/check-providers.sh` (not shipped), plus the exempt repo docs above.
- Users who select `goose` get a ~160 MB download into `/data/agents/bin/goose` on the next start and configure a model provider with `goose configure` in a Paseo terminal, or `GOOSE_PROVIDER`, `GOOSE_MODEL` and the provider's API key in `env_vars`. Users who do not select it see no change (nothing is downloaded; Paseo lists goose as disabled). Muse Code, Antigravity and fx installers now run in a scratch directory; their install directories and behaviour are unchanged.
