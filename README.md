# Paseo Home Assistant Add-on

Run [Paseo](https://paseo.sh) — a self-hosted daemon and web UI for coding agents
(Pi, Claude Code, Codex, OpenCode) — directly on your Home Assistant box, opened
from the HA sidebar and authenticated by Home Assistant. Agents start inside your
Home Assistant configuration with live API access, bundled guidance and optional
git snapshots, so configuring Home Assistant with agents is easy and safe.

## Installation

[![Open your Home Assistant instance and show the add add-on repository dialog with this repository URL pre-filled.](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Ffarajfarook%2Fpaseo-ha-addon)

Or add the repository manually:

1. In Home Assistant go to **Settings → Add-ons → Add-on Store**.
2. Open the **⋮** menu → **Repositories** and add:

   ```
   https://github.com/farajfarook/paseo-ha-addon
   ```

3. Install **Paseo**, start it and enable **Show in sidebar**.

See [`paseo/DOCS.md`](paseo/DOCS.md) for configuration and the security model.

## Add-ons

| Add-on | Description |
|---|---|
| [Paseo](paseo/) | Paseo daemon + web UI with Pi bundled and optional Claude Code / Codex / OpenCode |

## License

Apache-2.0, matching upstream Paseo. See [LICENSE](LICENSE).

## Releasing

Home Assistant installs the pre-built image whose tag equals `version` in
[`paseo/config.yaml`](paseo/config.yaml) on `main`
(`ghcr.io/farajfarook/{arch}-addon-paseo:<version>`). The version is
`<paseo>-<rev>`: the pinned Paseo release plus an add-on revision that resets to
`1` on every Paseo bump. Releasing is automatic once a bump reaches `main`:

1. On a branch, bump `version` in `paseo/config.yaml` (for example `0.10.3-2`, or
   `0.10.4-1` for a new Paseo release) and add a matching `## <version>` entry at
   the top of `paseo/CHANGELOG.md`. Lint warns on a PR that changes shipped files
   without a bump and fails if the changelog entry is missing. Wait for the Lint
   and Builder checks to pass.
2. Merge to `main`. The [Tag release](.github/workflows/tag.yaml) workflow sees the
   new version, creates the `v<version>` tag (skipping if it exists) and starts
   Publish.
3. [Publish](.github/workflows/publish.yaml) checks that the tag (minus `v`) equals
   `paseo/config.yaml` `version`, then pushes
   `ghcr.io/farajfarook/{amd64,aarch64}-addon-paseo:<version>` and `:latest`.
   Both take a few minutes.
4. When every image exists, Publish creates the GitHub Release with the
   `CHANGELOG.md` section for that version as its notes
   (`.github/scripts/release-notes.sh`).
5. To re-run a publish for an existing tag (or add a missing Release), use
   **Actions → Publish → Run workflow** and enter the tag (for example `v0.10.3-2`).
   Pushing a `v*` tag by hand also works.

Check a tag locally before pushing it:

```bash
.github/scripts/check-version.sh v0.10.3-2   # prints the version, or fails on mismatch
```

**First release only:** GHCR creates new packages as private. After the first
publish, open each of the two packages (`amd64-addon-paseo` and
`aarch64-addon-paseo`) under the repository's Packages, go
to **Package settings → Change visibility** and set it to **Public**. The
Supervisor pulls anonymously. Confirm with
`docker logout ghcr.io && docker pull ghcr.io/farajfarook/amd64-addon-paseo:<version>`.

Rules:

- Never push a `v*` tag for a version that isn't in `paseo/config.yaml` on
  `main`. The guard fails and nothing is published.
- Merging a version bump is the release. Until the images exist, users who see the
  new version get "image not found" when they update, so watch the Publish run.

## Bumping Paseo

The add-on does not fork Paseo. Its ingress adapter rewrites what the upstream web UI
emits, so it depends on Paseo internals: root-absolute asset paths, the hard-coded `/ws`
WebSocket path, the `window.__PASEO_INITIAL_DAEMON_CONNECTION__` hint and the
`paseo.bearer.<token>` subprotocol. A version bump that moves one of those silently breaks
the sidebar panel. Check them **before** raising the pin.

1. **Check the anchors of the candidate release** against the pinned one:

   ```bash
   ./.github/scripts/paseo-anchors.sh --diff <current> <candidate>   # e.g. --diff 0.10.3 0.11.0
   ```

   It downloads `@getpaseo/server` and `@getpaseo/protocol` for both versions and diffs a
   report of every fact the adapter relies on. Non-zero exit means an anchor moved. Use
   `.github/scripts/paseo-anchors.sh --installed` to print the report for the tree already
   installed.

2. **Diff the upstream sources** for the same files, plus the exported app shell, to see
   *why* something moved (paths are the same when only behaviour changed):

   ```bash
   BASE=https://raw.githubusercontent.com/getpaseo/paseo
   for tag in v0.10.2 v0.10.3; do           # the two versions you are comparing
     for f in packages/server/src/server/web-ui.ts \
              packages/protocol/src/daemon-endpoints.ts; do
       curl -fsSL -o "/tmp/$(basename "$f").$(tr . _ <<<"$tag")" "$BASE/$tag/$f"
     done
   done
   diff -u /tmp/web-ui.ts.v0_10_2 /tmp/web-ui.ts.v0_10_3
   diff -u /tmp/daemon-endpoints.ts.v0_10_2 /tmp/daemon-endpoints.ts.v0_10_3
   ```

   In the published package the exported `web-ui/index.html` and the bundle carry the same
   asset paths, and their file names are content-hashed - that is normal and is not an
   anchor change (the anchors report ignores hashes).

3. **If an anchor moved**, update the adapter before anything else:
   - `paseo/rootfs/opt/paseo-ha/nginx/paseo.conf.tpl` - the `sub_filter` list of
     root-absolute strings and the shim injection point.
   - `paseo/rootfs/opt/paseo-ha/www/shim.js` - the hint global, the `/ws` rewrite, the
     `/api/`, `/mcp/`, `/public/` fetch prefixes and the history/location mapping.
   - `paseo/rootfs/opt/paseo-ha/nginx/render.js` - the bearer header and WS subprotocol
     used for the direct-port password (design D4).
   - Record the new Paseo version's facts in `openspec/changes/.../design.md` D3.

4. **Re-pin and document**: `PASEO_VERSION` in `paseo/Dockerfile` and `paseo/build.yaml`
   (both must match), `PI_VERSION`/`HA_CLI_VERSION` if they move with it, the add-on
   `version` in `paseo/config.yaml`, and a new `paseo/CHANGELOG.md` entry naming the Paseo
   version.

5. **Prove it works**: build amd64 and run the suites - `paseo/tests/smoke/run.sh` (curl
   level through the ingress adapter), `paseo/tests/agent-config/run.sh` and, when the
   adapter changed, `paseo/tests/ingress/run.sh` (browser behind a mock ingress). CI runs
   the same smoke test on every PR; **a bump is not done until that job passes.**

Baseline for the pinned release: `paseo-anchors.sh --diff 0.10.2 0.10.3` and
`--diff 0.10.3 0.11.0-beta.3` both report no anchor change, and `web-ui.ts` /
`daemon-endpoints.ts` are byte-identical between `v0.10.2`, `v0.10.3` and
`v0.11.0-beta.3`.
