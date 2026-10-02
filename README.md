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
(`ghcr.io/farajfarook/{arch}-addon-paseo:<version>`). The
[Publish](.github/workflows/publish.yaml) workflow builds and pushes those images
when a `v<version>` tag is pushed.

1. On a branch, bump `version` in `paseo/config.yaml` (for example `0.10.3-2`, or
   `0.10.4-1` for a new Paseo release) and add a matching entry at the top of
   `paseo/CHANGELOG.md`. Wait for the Lint and Builder checks to pass.
2. Merge to `main`.
3. Tag the merge commit right away and push the tag:

   ```bash
   git checkout main && git pull
   git tag v0.10.3-2
   git push origin v0.10.3-2
   ```

4. The Publish workflow first checks that the tag (minus `v`) equals
   `paseo/config.yaml` `version` and stops before building if it doesn't. It then
   pushes `ghcr.io/farajfarook/{amd64,aarch64,armv7}-addon-paseo:<version>` and
   `:latest`. amd64 and aarch64 take minutes; armv7 builds under QEMU and is
   much slower. Users see the update once the images exist.
5. To re-run a publish for an existing tag, use **Actions → Publish → Run
   workflow** and enter the tag (for example `v0.10.3-2`).

Check a tag locally before pushing it:

```bash
.github/scripts/check-version.sh v0.10.3-2   # prints the version, or fails on mismatch
```

**First release only:** GHCR creates new packages as private. After the first
publish, open each of the three packages (`amd64-addon-paseo`,
`aarch64-addon-paseo`, `armv7-addon-paseo`) under the repository's Packages, go
to **Package settings → Change visibility** and set it to **Public**. The
Supervisor pulls anonymously. Confirm with
`docker logout ghcr.io && docker pull ghcr.io/farajfarook/amd64-addon-paseo:<version>`.

Rules:

- Never push a `v*` tag for a version that isn't in `paseo/config.yaml` on
  `main`. The guard fails and nothing is published.
- Never merge a version bump without tagging it straight away. Until its
  images exist, users who see the new version get "image not found" when they
  update.
