# Design

## Context

- `20-providers.sh` is the only place that installs agent CLIs. It is npm-only:
  `PROVIDER_PKGS[id]` is a space-separated npm spec list installed with
  `npm install --prefix /data/agents`, `PROVIDER_BIN[id]` is the binary that
  proves the provider works, and `/data/agents/node_modules/.bin` is put on the
  daemon PATH by `init-paseo.sh` before the hooks run.
- The stamp `/data/agents/.paseo-ha-providers.stamp` holds `id=<specs...>` per
  provider and is compared with the resolved specs to decide whether to install.
  `/data/agents/.paseo-ha-providers.failed` blacks lists an exact spec that
  failed its check. Both are parsed as npm specs (`npm_pkg_name`, `npm_uninstall`).
- Paseo 0.11.1 ships Muse Code and Antigravity as **bundled plugins**
  (`dist/server/builtin-plugins/muse-provider`, `antigravity-provider`), loaded
  by `BuiltinPluginLoader` with no enable step of its own. Their registrations
  are `{ id: "muse", command: ["muse"] }` and
  `{ id: "antigravity", command: ["agy"] }`, and a plugin provider resolves
  through `resolveRegisteredProvider`, i.e. the same
  `agents.providers.<id>.enabled` override the hook already writes. They are not
  in `BUILTIN_PROVIDER_IDS` or in the web bundle's `AGENT_PROVIDER_DEFINITIONS`,
  which is what `.github/scripts/check-providers.sh` reads.
- Neither CLI is on npm. Vendor installers, verified by hand on a Debian host on
  2026-10-09 (each installed into an empty directory, then its CLI run):
  - `https://dev.meta.ai/install.sh` writes `$MUSE_INSTALL_DIR/muse` (a 32 KB
    launcher; default `~/.local/bin`) plus the payload `muse-bin-<version>`
    (336 MB, statically linked ELF), `.muse-version` and
    `.muse-release-info.json` next to it, and appends a PATH line to `~/.bashrc`,
    `~/.zshrc`, `~/.profile` and `~/.config/fish/conf.d/muse.fish`. It is a bash
    script despite the documentation's `| sh` (it uses `[[`, so Alpine's busybox
    `sh` refuses to install). `muse --version` prints
    `Muse Code 1.4.4 (1.4.4-R5419.1)` - one line, with spaces.
  - `https://antigravity.google/cli/install.sh` downloads a per-platform manifest
    (including `linux_amd64_musl` and `linux_arm64_musl`, 1.3.2 at the time of
    writing), verifies a SHA-512 and installs a single 211 MB `agy` binary into
    `--dir` (its success message still names the default `~/.local/bin`, which is a
    cosmetic vendor bug: the binary goes where `--dir` says). It exits 0 without
    downloading when `agy` already exists. `agy --version` prints `1.3.2`.
- `HOME` is `/data/home` and persistent, so logins (`~/.config/muse/auth.json`,
  Antigravity's own config) and caches survive updates, as they must.

## Goals / Non-Goals

**Goals:**
- The `providers` option offers every provider the pinned Paseo can run, and the
  add-on installs, enables and removes each one the user selects.
- One install path per provider kind, so an npm provider and a vendor-installer
  provider follow the same enable/disable, logging, failure and retry rules.

**Non-Goals:**
- Tracking the vendor's latest version ourselves. Their CLIs self-update; the
  add-on only installs them and reports what they report.
- Rolling back a bad vendor-installer release. There is no previous artifact
  cached to roll back to, unlike the npm path.
- HA guidance, the HA skill and HA MCP wiring for the two new providers (see
  proposal.md — Impact).
- Any behaviour when neither provider is selected: nothing is downloaded, PATH
  entries point at empty directories.

## Decisions

### D1: Per-provider install directory under `agents/bin`, not one shared bin dir
Script providers install into `/data/agents/bin/<id>`, and the hook puts the
directory of each *selected* script provider on the daemon PATH with
`ph_env_prepend_path`. Hooks run before the daemon starts and their `ph_env_set`
writes go into the daemon env file that `paseo/run` sources, so the first start
already has the directory. Doing it from the hook keeps the provider IDs in the
one file that owns them, instead of repeating them in `init-paseo.sh`.
- Muse Code writes a launcher, a payload and four dotfiles into its install
  directory; Antigravity writes one binary. A per-provider directory makes
  deselection an exact `rm -rf` of files we own, without enumerating vendor
  internals that can change between releases, and without one vendor's cleanup
  touching the other's files.
- Rejected: one shared `/data/agents/bin` with a hard-coded file list per
  provider (breaks when the vendor adds a file), and installing into
  `~/.local/bin` (two providers in one directory with no way to remove just
  one; also that directory is not on the daemon PATH today).

### D2: A provider is either npm-installed or script-installed
`PROVIDER_KIND[id]` defaults to `npm`. The script providers carry
`SCRIPT_URL[id]`, `SCRIPT_SHELL[id]` (the vendor's shell), `SCRIPT_ARGS[id]` and
optionally `SCRIPT_ENV[id]` (the install-directory variable the vendor honours).
The hook downloads the installer to a temp file with `curl -fsSL` and runs it
with the provider's shell and arguments.
- The whole second path stays data-driven next to `PROVIDER_PKGS`, so adding a
  third vendor-installed provider is three map entries and a docs row.
- Downloading first rather than piping into the shell gives one clear failure
  point for "the installer could not be fetched" and avoids depending on
  `pipefail` inside a `curl | sh` pipeline.
- Rejected: `eval`-ing a per-provider command string (injection risk and opaque
  quoting), and special-casing each provider in a `case` (the maps already
  describe them).
- The vendor's documented shell is not always the shell that works: Muse Code's
  page says `| sh`, but the script uses `[[` and Alpine's `/bin/sh` is busybox.
  `SCRIPT_SHELL` therefore records the shell each installer actually needs
  (`bash` for both), and a wrong choice shows up as a failed install on start
  rather than as a silent no-op.

### D3: Install once, then trust the CLI's own version, and record it
For a script provider the hook does not compare a desired version with the
stamped one. Each start it checks `<bin> --version`:
- runs → the stamp records `bin@<reported version>` and nothing is downloaded
  (the CLI's updater owns upgrades);
- missing or failing → run the installer once, re-check, then stamp or report
  failure.
- Rationale: neither vendor offers a "latest version" query we can trust, and
  Antigravity's installer no-ops when the binary exists, so a
  "reinstall when the version differs" rule would download nothing and still
  churn. A self-updated version appearing in the stamp and in the `Providers:`
  log line is accurate rather than aspirational.
- `.paseo-ha-providers.failed` is not written for script providers: it exists to
  avoid re-downloading one broken npm version, and there is no version to blame
  here. Retry-next-start (the existing requirement) still applies.
- The stamp still carries `<bin>@<version>`, so a reported version with spaces
  (Muse Code's `Muse Code 1.4.4 (1.4.4-R5419.1)`) is stored verbatim. Nothing
  parses a script provider's stamp - it is only read back to know a CLI was
  installed - and the `Providers:` line takes the version from the run itself
  (`NEW_VERSION`), not from the stamp, so no npm-spec parsing applies to it.
- "The CLI answers its version check" is the success criterion, not the
  installer's exit code. A vendor whose last step fails after the binary is in
  place would otherwise be reinstalled on every start, and a provider whose
  `--version` prints nothing at all is treated as not working (the version is what
  the log and the stamp report). A failed install removes its directory again, so
  a partial 336 MB download does not sit in `/data` until the next start.

### D4: The CI provider gate accepts bundled plugin providers
`check-providers.sh` keeps comparing the schema with Paseo's provider IDs, but
that set becomes the `AGENT_PROVIDER_DEFINITIONS` ids **plus** the providers
registered by the bundled plugins in
`dist/server/builtin-plugins/*-provider`. The plugin set is read from each
plugin's `provider.ts` registration (`id: "<id>"` returned by
`create*Provider`), which is the same source of truth Paseo uses.
- Rejected: hard-coding `muse antigravity` in the CI script (drifts from the
  pinned Paseo), and loosening the check to a subset assertion (it would stop
  catching a schema value that Paseo cannot run).
- The script fails when it finds no plugin providers at all, so a layout change
  upstream is a loud failure rather than a silently smaller comparison. Note the
  check is only meaningful from Paseo 0.11.0, where the plugins exist; older
  pins are not used with this schema.

### D5: Keep the change non-breaking for existing installs
The option gains two values and its default stays `[pi]`. An existing
configuration keeps exactly the providers it selected; the npm providers'
behaviour, stamp format and rollback rules are untouched, and `muse`/
`antigravity` are written into the stamp and the Paseo config only when
selected.

## Risks / Trade-offs

- [Muse Code is ~336 MB inside `/data`, and `rm -rf` on deselection has no
  confirmation] → The size is stated in DOCS.md and the CHANGELOG; the directory
  is namespaced under `/data/agents/bin/muse` so it can be removed by hand.
- [Alpine/musl: a vendor could publish a glibc-only Linux artifact] → Both
  artifacts verified for this change: Muse Code's payload is a statically linked
  ELF (no libc dependency at all), and Antigravity publishes `linux_amd64_musl`
  and `linux_arm64_musl` builds, which its installer detects by checking for
  `/lib/libc.musl-*.so.1`. A CLI that does not run fails `--version`, is logged,
  stays disabled in Paseo and is retried next start.
- [The vendor installers edit shell profiles in the persistent home] (Muse Code
  appends a PATH line to `~/.bashrc`, `~/.zshrc`, `~/.profile` and the fish
  config) → Accepted and documented: the add-on sets PATH itself and does not
  need those lines; they point at a directory that is removed on deselection, and
  a stale line there is harmless.
- [Vendor installer scripts change shape (flag renamed, directory ignored)] →
  The install is only accepted after `<bin> --version` succeeds from the
  directory we chose, so a silently wrong install leaves the provider disabled
  instead of pointing PATH at nothing.
- [First start after selecting a new provider takes as long as the download,
  and can exhaust the 600 s install cap] → The installer runs under the existing
  `INSTALL_TIMEOUT` with the same message as the npm path; a timeout is a
  failure, so the provider is disabled and retried from a clean directory next
  start.
- [A vendor installer could leave its temp/staging files in `$HOME`] → Out of
  our control; they are inside `/data/home` (persistent) and are not counted as
  provider files, so a later reinstall reuses them.

## Migration Plan

1. Merge the change (the version bump is the release).
2. A user updates the add-on: Paseo moves to 0.11.1, no provider is reinstalled
   and no option changes.
3. A user who wants Muse Code or Antigravity selects it in the add-on
   Configuration tab and restarts: the first start downloads and installs it,
   later starts report its version.
4. Rollback: install the previous add-on version. That hook does not know the two
   new ids: it logs "Unknown provider 'muse' in providers option; ignoring" and
   then, because the id is in the stamp, logs a failed uninstall for it on every
   start. Harmless (the CLIs stay installed and their directories stay in
   `/data`), and it stops once the change is reinstalled or the directories are
   removed by hand.

## Open Questions

- None that change the specs or the task breakdown. HA guidance and MCP wiring
  for the two providers are a documented follow-up (proposal.md — Impact).
