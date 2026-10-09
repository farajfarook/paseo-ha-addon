# Proposal

## Why

The pinned Paseo is **0.10.3** and **0.11.1** is out. The ingress anchors the
add-on rewrites are unchanged between the two (`.github/scripts/paseo-anchors.sh
--diff 0.10.3 0.11.1` reports "anchors unchanged"), so the bump itself is safe.
0.11.0 also adds two providers, **Muse Code** (`muse`) and **Antigravity**
(`agy`), which Paseo registers from its bundled plugins and which its own
release notes advertise. The add-on's `providers` option cannot offer them
today: neither CLI is published to npm, so the hook that installs and enables
providers has no way to install them.

## What Changes

- **Bump the pinned Paseo to 0.11.1** (add-on `0.11.1-1`).
- **ADDED: Muse Code and Antigravity as selectable providers.** Both CLIs come
  from vendor installer scripts, not npm:
  - Muse Code (Meta): `curl -fsSL https://dev.meta.ai/install.sh | sh`, honouring
    `MUSE_INSTALL_DIR`. It installs a self-updating `muse` launcher plus a
    statically linked payload (~336 MB).
  - Antigravity (Google): `curl -fsSL https://antigravity.google/cli/install.sh | bash --dir <dir>`.
    It installs a self-updating `agy` binary and has a musl build for both
    supported architectures.
- **ADDED: a second install path in the providers hook** for CLIs that are not
  npm packages. Each such provider gets its own directory under persistent
  storage (`/data/agents/bin/<id>`) which is put on the agents' PATH. The
  installer is downloaded and run once; a provider whose CLI already answers
  `--version` is never reinstalled, and the version it reports is recorded and
  logged. Deselecting removes that whole directory. No npm registry lookup
  applies to these providers: their CLIs update themselves.
- **The `providers` option and its Paseo enable flags cover the eight providers**
  (the six npm ones plus the two plugin ones). Paseo resolves plugin providers
  through the same `agents.providers.<id>.enabled` overrides the hook already
  writes, so the enable/disable half needs no new mechanism.
- **The CI gate `.github/scripts/check-providers.sh` learns about plugin
  providers.** It currently requires the schema to equal the static
  `AGENT_PROVIDER_DEFINITIONS` of the pinned Paseo exactly, which would reject
  the two new IDs. It becomes: the schema equals Paseo's built-in providers plus
  the providers its bundled plugins register.
- Tests: `paseo/tests/providers/run.sh` covers the new provider IDs, the
  script-installer path (install, never-reinstall, uninstall, offline, failure)
  and the eight enable flags, using a stub installer through a test seam so CI
  downloads nothing.
- Docs, `CHANGELOG.md` and the version bump.

## Capabilities

### New Capabilities
<!-- None: the new behaviour belongs to the existing agent-providers capability. -->

### Modified Capabilities
- `agent-providers`: the `providers` option covers Paseo's built-in providers
  *and* the providers its bundled plugins register; a second install path for
  CLIs that are not npm packages; version, upgrade and uninstall rules for those
  providers; the enable flags cover all eight.

## Impact

- `paseo/rootfs/etc/paseo-ha/init.d/20-providers.sh` (the install/enable hook,
  including the daemon PATH for the new provider directories).
- `paseo/config.yaml` (`PASEO_VERSION`-adjacent version, `providers` schema enum),
  `paseo/translations/en.yaml`, `paseo/DOCS.md`, `paseo/CHANGELOG.md`,
  `paseo/build.yaml` + `paseo/Dockerfile` (Paseo pin).
- `.github/scripts/check-providers.sh` (CI gate), `paseo/tests/providers/run.sh`.
- **Not in scope** (documented as known limitations, follow-up OpenSpec change):
  Home Assistant guidance (`35-instructions.sh`) and the HA MCP wiring
  (`45-ha-mcp.sh`) are per-CLI and do not know Muse Code or Antigravity, so
  agents on those two providers do not get the bundled HA skill, instructions or
  MCP tools yet. Paseo passes a system prompt to these providers instead of
  reading an instructions file, so wiring them needs its own design.
- New outbound network use on start, only for a user who selects the new
  providers: `dev.meta.ai` (installer + `lookaside.facebook.com` artifacts) and
  `antigravity.google` / `storage.googleapis.com`. Persistent storage grows by
  the size of those CLIs (Muse Code is ~336 MB).
