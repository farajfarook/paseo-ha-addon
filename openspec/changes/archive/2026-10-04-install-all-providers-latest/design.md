# Design

## Context

- `paseo/Dockerfile` installs Pi into `/opt/node` at build time (`npm install -g --ignore-scripts @earendil-works/pi-coding-agent@${PI_VERSION}`). `PI_VERSION` is set in `build.yaml` and as a Dockerfile ARG, exported as `PASEO_HA_PI_VERSION`, written to the `io.hass.pi.version` label and printed by `init-paseo.sh:154`. `paseo/tests/docs/run.sh` requires the CHANGELOG to name the Pi pin.
- `20-providers.sh` holds a `PROVIDER_SPECS` map of pinned npm specs for the five other providers (`pi` is empty, meaning built in). It installs selected providers into `/data/agents` and records `id=spec…` lines in `/data/agents/.paseo-ha-providers.stamp`. A provider is reinstalled only when its stamped specs differ from the desired ones or its CLI stops answering `--version`. `/data/agents/node_modules/.bin` is first on the daemon `PATH`.
- Hooks run in sorted order, each in its own bash process, before the daemon starts. Hooks that use the `pi` binary run after `20-providers.sh`: `36-pi-packages.sh` (`pi install` of default packages; it does not check that `pi` exists) and `45-ha-mcp.sh` (already guarded with `ph_have pi`).
- Pi's state lives under `/data/home/.pi/agent` (`PI_CODING_AGENT_DIR`), not next to the binary, so moving the binary does not touch logins, settings or packages.
- Paseo itself stays pinned in the image. Its web UI is patched for Ingress against anchors of the pinned release, so it can't float.

## Goals / Non-Goals

**Goals:**
- One install path for all six providers. Pi has no special handling beyond its default selection.
- Each start brings every selected provider to its latest stable npm release.
- Never block or break startup because of the registry or a bad release.

**Non-Goals:**
- Floating Paseo, the `ha` CLI or the default Pi packages. They keep their pins.
- A user-facing option to pin or hold a provider version. Possible follow-up.
- An offline fallback copy of Pi in the image. Decided against: a fresh install without network starts with no agent (see Risks).
- Lockfiles for the agents' transitive dependencies.

## Decisions

### D1. Pi is an ordinary provider
Remove the Pi install from the Dockerfile and add `[pi]="@earendil-works/pi-coding-agent"` to the provider table. Deselecting Pi uninstalls it from `/data/agents`, like every other provider. The `pi` binary check in `provider_runs` uses `${BIN_DIR}/pi` like the rest, so the special case goes away. Pi is installed with the same npm flags as the rest, without the `--ignore-scripts` the image used. Pi itself has no install scripts. Three dependencies do (`esbuild` fetches its platform binary, `protobufjs` and `@google/genai` run no-op or setup scripts), and an install of Pi 1.0.2 with scripts enabled in the 0.10.3-3 amd64 image completed, `pi --version` and `pi --mode rpc` worked, and `pi install npm:pi-web-access` succeeded.

*Alternative:* keep Pi in the image as a fallback and prefer a newer copy in `/data/agents`. Rejected by the owner: it keeps Pi special and the image larger.

### D2. Resolve `latest` on every start
The table stores package names only. For each selected provider, the hook runs `npm view <name>@latest version` with a short timeout (`timeout 20`, `--fetch-retries=0`) and builds the desired spec `<name>@<resolved>`. Oh My Pi resolves both `bun` and `@oh-my-pi/pi-coding-agent`. The resolved specs go through the existing stamp comparison, so an unchanged `latest` downloads nothing. The stamp format (`id=name@ver …`) does not change, so stamps written by the current release are read as-is and only providers with a newer release are reinstalled.

"Stable" means npm's `latest` dist-tag. A resolved version that has a prerelease suffix (contains `-`) is treated as a failed lookup, because some publishers move `latest` to a release candidate.

*Alternatives:* first install only, or at most daily. Rejected by the owner in favour of always current.

### D3. Lookup failure keeps what is installed
If the lookup fails or times out:
- a provider in the stamp whose CLI runs keeps its stamped version, and the log says the update check was skipped;
- a provider not yet installed is not installed, is disabled in Paseo, and is retried on the next start.

### D4. A broken upgrade rolls back
When the resolved version differs from the stamped one, the hook installs the new version and runs `--version`. If that fails, it reinstalls the stamped version, runs `--version` again and keeps the old stamp line. The failed spec is written to `/data/agents/.paseo-ha-providers.failed`, and that exact version is not tried again on later starts. A newer `latest` clears the entry. Without this, a bad release would be downloaded and rolled back on every start.

### D5. Maintainer hold
The script keeps an empty-by-default `PACKAGE_HOLD` map (`[<npm package name>]="<exact version>"`), keyed by package so Oh My Pi and Bun can be held separately. A held package skips the lookup and installs the held version. It's the escape hatch when a new agent release breaks with the pinned Paseo: a maintainer ships a hold in a patch release instead of rolling back the whole model.

### D6. Pi-dependent hooks need the binary
`36-pi-packages.sh` starts with `ph_have pi || { ph_log_info "Pi is not installed; skipping default Pi packages"; exit 0; }`. Nothing is recorded in the offered-defaults ledger in that case, so the defaults are offered once Pi is installed. `45-ha-mcp.sh` already checks `ph_have pi`.

### D7. Versions in logs and docs
The image no longer knows a Pi version. `init-paseo.sh` logs the Paseo version only. `20-providers.sh` logs the installed version of each provider (it already does after an install) and adds one summary line on every start, e.g. `Providers: pi 1.2.0, claude 2.2.1 (update check skipped: registry unreachable)`. The docs check stops requiring the Pi pin in the CHANGELOG.

## Risks / Trade-offs

- [A fresh install without registry access has no agent] → Logged clearly. Paseo starts with every provider disabled, and the next start retries. DOCS.md "Known limitations" says that the first start needs internet.
- [A new agent release breaks with the pinned Paseo (protocol or flag changes), and every user gets it on their next restart] → D4 only catches a CLI that fails `--version`, not a runtime incompatibility. Mitigations: the D5 hold, and a follow-up CI job that installs `latest` of each provider against the pinned Paseo on a schedule. The trade-off is accepted for freshness.
- [Each start makes one registry request per selected provider (two for omp)] → Roughly 1–2 s each with a 20 s cap. They can run in parallel if this proves slow.
- [Restarts are no longer reproducible: two restarts a day apart can run different agent versions] → The start-up summary line records what ran, so it can be reported in issues.
- [Pi's dependency install scripts now run (they were skipped in the image), and aarch64 has not been tested] → Verified on amd64. Task 5.1 covers aarch64 on real hardware; if a script fails there, the install fails its `--version` check and is logged like any other provider.
- [Image tests that relied on Pi being in the image (`pi --version` in the Dockerfile, the providers test "Pi disabled but still runnable")] → Updated in tasks 3.x.

## Migration Plan

No user action. On the first start after the update:
- the image has no Pi, so the stamp has no `pi` line and Pi is installed into `/data/agents` if selected;
- other providers are compared with `latest` and upgraded if newer.

Pi's data under `/data/home/.pi` is untouched. Rollback: reinstall the previous add-on version. Its image brings Pi back, and its pinned specs differ from the stamp, so it reinstalls its own pins.
