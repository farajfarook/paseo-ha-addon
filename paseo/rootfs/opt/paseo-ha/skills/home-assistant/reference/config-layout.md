# Home Assistant config layout

All paths are inside the Paseo add-on container.

## `/homeassistant` (HA config directory, read-write, live)

| File / folder | What it is | How to apply changes |
|---|---|---|
| `configuration.yaml` | Main config; usually includes the files below | check, then reload the affected domain or restart Core (ask first) |
| `automations.yaml` | UI + YAML automations (a list; each item needs a unique `id`) | `automation.reload` |
| `scripts.yaml` | Scripts (a mapping keyed by script id) | `script.reload` |
| `scenes.yaml` | Scenes (a list with `id`) | `scene.reload` |
| `secrets.yaml` | Credentials referenced with `!secret name` | **never print values** |
| `packages/` | Feature bundles, enabled by `homeassistant: packages: !include_dir_named packages` | reload each domain inside, or restart if a package adds a new integration |
| `blueprints/automation/`, `blueprints/script/` | Blueprints | `automation.reload` / `script.reload` |
| `custom_components/` | Custom integrations (HACS installs here) | restart Core (ask first) |
| `themes/` | Frontend themes (if `frontend: themes: !include_dir_merge_named themes`) | `frontend.reload_themes` |
| `www/` | Files served at `/local/...` | none |
| `ui-lovelace.yaml`, `dashboards/` | YAML-mode dashboards (only if configured in YAML mode) | browser refresh |
| `.storage/` | UI-managed state: registries, config entries, storage-mode dashboards, helpers, auth | **never edit while Core runs**; use the WebSocket API |
| `home-assistant_v2.db*` | Recorder database | **never touch** |
| `home-assistant.log*` | Log files | read only; prefer `ha core logs` |
| `.HA_VERSION` | Installed Core version | read only |
| `.git/` | Present when the user enabled `git_snapshot` (or made a repo) | commit before/after changes |

### Includes to recognise

```yaml
automation: !include automations.yaml            # list file
automation manual: !include_dir_merge_list automations/
script: !include scripts.yaml
homeassistant:
  packages: !include_dir_named packages          # packages/<name>.yaml
sensor: !include_dir_merge_list sensors/
```

`automation:` sections from several places (e.g. `automation manual:`, packages) are merged.
Automations created in the UI are written to `automations.yaml` with a generated numeric `id`;
keep that format so the UI editor still works.

### Check which mode a dashboard uses

Storage-mode dashboards live in `.storage/lovelace*` and must be changed through the
WebSocket API (`lovelace/config`, `lovelace/config/save`). YAML-mode dashboards are declared
under `lovelace:` in `configuration.yaml`.

## Other folders

| Path | Access | Notes |
|---|---|---|
| `/addon_configs/<repo>_<slug>/` | rw | Other add-ons' config (e.g. `core_mosquitto`, `45df7312_zigbee2mqtt`). Ask before editing; most add-ons need `ha addons restart <slug>` to apply. |
| `/share` | rw | Shared between add-ons. |
| `/ssl` | ro | TLS certificates. |
| `/media` | ro | Media library. |
| `/backup` | ro | Backup archives. Create backups with `ha backups new`. |
| `/config` | rw | This add-on's agent config (user skills in `/config/skills`, shared `/config/AGENTS.md`). |

Find an add-on's slug with `ha addons` (installed add-ons) or `ha addons info <slug>`.
