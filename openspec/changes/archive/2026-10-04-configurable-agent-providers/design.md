# Design

## Context

- `20-agents.sh` installs a pinned npm package for each value of the `agents` option (`claude-code|codex|opencode`) into `/data/agents`. It keeps a stamp file (`.paseo-ha-agents.stamp`) and uninstalls packages that are no longer selected. Pi is installed globally in the image (`/opt/node`). `/data/agents/node_modules/.bin` is already first on the daemon `PATH`.
- Paseo 0.10.3 (`@getpaseo/server`) has six built-in providers: `claude`, `codex`, `copilot`, `opencode`, `pi`, `omp`. A provider is enabled when `agents.providers.<id>.enabled` is true in `$PASEO_HOME/config.json`. When that field is unset, Paseo falls back to `enabledByDefault`, which is true for everything except `omp`.
- `paseo daemon config set <path> <json> --home <dir>` edits that file with schema validation and works while the daemon is stopped. `init-paseo.sh` already uses it for `worktrees.root`.
- The CLIs each provider launches: `claude`, `codex`, `copilot` (`copilot --acp`), `opencode`, `pi`, `omp` (`OMP_COMMAND`, at least 16.3.9).
- `@github/copilot` uses optional dependencies to pick its platform binary and includes `linuxmusl-x64`/`linuxmusl-arm64`. `@oh-my-pi/pi-coding-agent` (`bin: omp`) requires `bun >= 1.3.14`. The `bun` npm package ships `linux-*-musl` builds. Its native addon `@oh-my-pi/pi-natives` only lists `linux-x64`/`linux-arm64`, which are probably glibc builds (see Risks).
- The base image is Alpine (musl). Each init.d hook runs in its own bash process, before the daemon starts.

## Goals / Non-Goals

**Goals:**
- Use one option as the single source of truth for both the installed CLIs and the providers Paseo has enabled.
- Keep the existing install behavior: only redo work when something changed, and log a failure for one provider without stopping the rest.

**Non-Goals:**
- Taking Pi out of the image or uninstalling it.
- Migrating the old `agents` option or its stamp file. The user will reinstall.
- Terminal profiles, per-provider `command`/`env` overrides, custom ACP providers (Cursor, Kimi, etc.), and config-folder links for Copilot/OMP.
- Bundling Bun in the image.

## Decisions

### D1. Option `providers: list(claude|codex|copilot|opencode|pi|omp)`, default `[pi]`
The values are Paseo's own provider IDs, so the Configuration tab shows the same list as Paseo and the sync step maps values to providers with no translation table. The old value `claude-code` becomes `claude`. *Alternatives:* keep the `agents` key (rejected: the user asked for one list that matches Paseo, and there's no installed base to keep compatible), or one boolean per provider (rejected: six extra options and translations, and they don't scale).

### D2. One provider table drives both install and sync
`20-agents.sh` becomes the providers hook. It keeps one table per provider ID with these fields:

| id | install | binary checked |
|---|---|---|
| claude | `@anthropic-ai/claude-code@<pin>` | `claude` |
| codex | `@openai/codex@<pin>` | `codex` |
| copilot | `@github/copilot@<pin>` | `copilot` |
| opencode | `opencode-ai@<pin>` | `opencode` |
| omp | `bun@<pin>` + `@oh-my-pi/pi-coding-agent@<pin>` | `omp` (with `bun` on PATH) |
| pi | built in (none) | `pi` |

A provider can have more than one npm spec (omp). The stamp records `id=spec1 spec2`, so changing either pin, or deselecting the provider, reinstalls or uninstalls both packages together. Bun is installed only when omp is selected, which matches the user's choice of installing it on demand.

### D3. Sync enabled flags with `paseo daemon config set`, per field, on every start
After the install pass, the hook runs `paseo daemon config set agents.providers.<id>.enabled <true|false> --home "$PASEO_HOME"` for each of the six IDs. A provider gets `true` only if it is selected and its binary passes `--version`, so Pi is checked as well. Setting individual fields leaves other overrides under `agents.providers.<id>` that a user may have added through Paseo untouched. Because the hook runs before the daemon starts, the CLI just saves the change and reports "not applied", which is fine because the daemon reads the file when it starts. *Alternatives:* edit `config.json` with jq (rejected: no schema validation, and it could write a file Paseo rejects), or replace the whole `agents.providers` object (rejected: it would delete user overrides). Running the sync on every start, not only when the selection changes, means a toggle made in Paseo's UI is always reset to the add-on option. The add-on owns this setting, which DOCS.md will state.

### D4. Failure handling
An install failure (npm error, or `--version` fails afterwards) leaves the provider out of the new stamp so the next start retries it, removes any partial packages, and makes D3 write `enabled: false`. A `paseo daemon config set` failure is logged as a warning, and the hook keeps going with the remaining providers. The hook never exits non-zero for a provider problem.

### D5. Keep credentials on uninstall
Uninstalling only runs `npm uninstall` in `/data/agents`. Home directories (`~/.claude`, `~/.codex`, `~/.copilot`, `~/.omp`, `~/.config/opencode`, `~/.pi`) are left alone, so selecting a provider again restores its login.

## Risks / Trade-offs

- [`omp` native addon may not load on musl/Alpine: `pi-natives` publishes no `linux-*-musl` package] → The install-time `omp --version` check catches this. The provider is then disabled and the log explains why. Task 2.4 checks it on both architectures. If it fails, implementation tries adding `gcompat`/`libstdc++` to the runtime image before giving up, and DOCS.md lists omp as best-effort.
- [Bun download is about 90 MB per architecture, added to /data and therefore to backups] → It's only downloaded when omp is selected and removed on deselect.
- [Six `paseo` CLI calls add Node start-up time to every boot (around 0.5–1 s each)] → Acceptable for a boot-time hook. If it proves slow, all six can be batched into one `node -e` call to the same `editPersistedConfig` API.
- [Users lose provider toggles made in Paseo's UI on restart] → This is intended. DOCS.md "Which settings live where" will list provider enablement as owned by the add-on.
- [Paseo's provider IDs change in a future release] → Lint will grep the provider IDs out of the pinned `@getpaseo/server` and compare them with the `providers` schema, the same way `paseo-anchors.sh` works.

## Migration Plan

No migration. Bump the add-on version and note **BREAKING: `agents` replaced by `providers`** in the CHANGELOG. Uninstall and reinstall the add-on (or remove `/data/agents`). Rollback means reinstalling the previous version.
