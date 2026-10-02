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
