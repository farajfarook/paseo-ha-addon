# Home Assistant Add-on: Paseo

![Supports aarch64 Architecture][aarch64-shield]
![Supports amd64 Architecture][amd64-shield]

Configure Home Assistant with coding agents.

[Paseo](https://paseo.sh) is a self-hosted daemon plus web UI for coding agents. This
add-on runs it on your Home Assistant machine and opens it from the HA sidebar, so an
agent can read and edit your Home Assistant configuration and check its work against the
live API instead of guessing.

Pick the agents you want in the `providers` option (Pi, Claude, Codex, Copilot, OpenCode,
Oh My Pi; Pi by default). On every start the add-on installs the latest stable release of
each selected CLI and enables it in Paseo. The first start needs internet access.

## Table of contents

- [Installation](#installation)
- [Using Paseo from the sidebar](#using-paseo-from-the-sidebar)
- [Options reference](#options-reference)
- [Which settings live where](#which-settings-live-where)
- [Voice and dictation](#voice-and-dictation)
- [Remote access: relay vs. direct port](#remote-access-relay-vs-direct-port)
- [Agent providers](#agent-providers)
- [Logging in agents](#logging-in-agents)
- [Pi packages](#pi-packages)
- [Folders and storage](#folders-and-storage)
- [Editable agent configuration](#editable-agent-configuration)
- [What agents can do with Home Assistant](#what-agents-can-do-with-home-assistant)
- [Home Assistant MCP tools](#home-assistant-mcp-tools)
- [Bundled guidance and the safe edit workflow](#bundled-guidance-and-the-safe-edit-workflow)
- [Git snapshots and rollback](#git-snapshots-and-rollback)
- [Security and trust model](#security-and-trust-model)
- [Supported architectures](#supported-architectures)
- [Troubleshooting](#troubleshooting)
- [Known limitations](#known-limitations)

## Installation

1. **Settings → Add-ons → Add-on Store**, then the **⋮** menu → **Repositories** and add:
   `https://github.com/farajfarook/paseo-ha-addon`
2. Pick **Paseo** from the `paseo-ha-addon` repository and press **Install**. The
   pre-built image for your architecture is pulled from GHCR; nothing is built on the
   device.
3. Open **Show in sidebar** and **Start**. Options can be left at their defaults.
4. The **Paseo** entry appears in the HA side menu once the daemon is healthy — usually
   well under a minute on amd64/aarch64.

Updating works like any other add-on: **Update** in the Add-on Store. `/data` (Paseo
state, agent logins, installed agents) survives updates and is included in HA backups.

## Using Paseo from the sidebar

Press **Paseo** in the side menu. The UI is served through Home Assistant Ingress, so it
uses your existing HA login — no host to add, no pairing code, no second password.

A **Home Assistant** project pointing at `/homeassistant` is created for you on first
start, so you can open a session immediately and ask something like:

> Add an automation that turns on the porch light at sunset, and make it stop after 23:00.

The agent edits `automations.yaml`, runs a configuration check, reloads automations,
verifies the entity state and reports the result — see
[bundled guidance](#bundled-guidance-and-the-safe-edit-workflow).

Terminals opened from Paseo run inside this container, with the same `HOME` and the same
environment the agents get, which is where you log agents in and run `ha` yourself.

## Options reference

Set these under **Configuration** in the Add-on Store. All of them take effect on the next
add-on start.

| Option | Type / default | Effect |
|---|---|---|
| `workspace` | string, `/homeassistant` | Directory new terminals and agent sessions start in. Created if missing. Set it to another mapped path (e.g. `/share/paseo`) to work somewhere else by default. |
| `git_snapshot` | boolean, `false` | Keep `/homeassistant` under git for review and rollback. See [Git snapshots](#git-snapshots-and-rollback). |
| `providers` | list of `claude`, `codex`, `copilot`, `opencode`, `pi`, `omp`; default `[pi]` | The agent providers to offer, using Paseo's own provider IDs (`omp` is Oh My Pi). Selected providers have the latest stable release of their CLI installed into `/data/agents` and are enabled in Paseo; every other provider is uninstalled and disabled. Pi is installed the same way as the others and is selected by default. Nothing is downloaded when the selection is unchanged and no newer release exists, and a failed install only disables that provider. See [Agent providers](#agent-providers). |
| `env_vars` | list of `{name, value}`, `[]` | Environment variables exported to the daemon and therefore to every agent — e.g. `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`. **Only the names are logged, never the values.** |
| `password` | string, empty | Password required for direct-port access. It is never asked for on the sidebar/ingress path. See [Relay vs. direct port](#remote-access-relay-vs-direct-port). |
| `hostnames` | list of strings, `[]` | Extra DNS names the daemon accepts on the direct port (`PASEO_HOSTNAMES`), e.g. `paseo.example.com`, when you reach HA through a proxy or a custom name. |
| `log_level` | `trace`/`debug`/`info`/`warn`/`error`, `info` | Paseo daemon console log level, visible in the add-on **Log** tab. |
| `dictation` | boolean, `false` | Enable speech-to-text dictation in Paseo. |
| `voice_mode` | boolean, `false` | Enable full voice conversations in Paseo. |
| `speech_provider` | `local` / `openai`, `local` | Which speech engine backs dictation/voice when they are enabled. `openai` requires `OPENAI_API_KEY` in `env_vars`. |
| `worktrees_root` | string, empty | Directory where Paseo creates git worktrees, e.g. `/share/paseo-worktrees`. Created if missing. Empty means Paseo's default inside persistent storage (`/data/home/.paseo/worktrees`). |
| `relay` | boolean, unset | Force Paseo's encrypted relay on or off. Unset leaves the relay under Paseo's own control. See below. |

Port **`6767/tcp`** is declared but not published: map it in the **Network** tab only if
you want direct access from your LAN.

## Which settings live where

The add-on owns a handful of Paseo settings and deliberately leaves the rest to Paseo.

**Fixed by the add-on** (not exposed, do not fight them): the daemon listen address and
web UI (`PASEO_LISTEN`, `PASEO_WEB_UI_ENABLED`), `PASEO_HOME`, trusted-proxy handling,
console log format, and the process environment (`HOME=/data/home`, the agent config
dirs). Anything listed in the options table above is applied as an environment variable on
every start.

**Owned by Paseo's Settings screen** (never set by this add-on, so they stay editable and
survive restarts): MCP injection into agents, browser tools, auto-archive after merge,
terminal and agent profiles, plugins, system prompt append, skills
handling, git limits, and the voice LLM provider/model.

Because environment variables lock a setting in Paseo (the UI reports it as an override),
the add-on only uses them for options that are add-on-owned or start-up-only. If you set
one of the Paseo-owned settings through `env_vars` yourself, Paseo will show it as
overridden — that is expected.

**Owned by the add-on:** which agent providers are enabled (`agents.providers.<id>.enabled`).
It is set from the `providers` option on every start, so enabling or disabling a provider in
Paseo's Settings only lasts until the next restart. Other per-provider settings you add in
Paseo (labels, models, commands) are kept.

**Advanced:** Paseo's own config file is `/data/home/.paseo/config.json`, merged under the
environment variables above. Edit it from a Paseo terminal (stop the add-on first, or
restart afterwards so your editor and the daemon agree):

```sh
cat /data/home/.paseo/config.json
```

It is not reachable from File Editor or Samba — `/data` is private to the add-on. Anything
you want to edit comfortably belongs in `/config`.

## Voice and dictation

Both features are **off by default** because enabling them with `speech_provider: local`
downloads roughly **0.6–1 GB** of sherpa-onnx models (Parakeet STT, Kokoro TTS) into
`/data/home/.paseo/models/local-speech` on first use. The download happens once and
survives restarts and updates, and is part of `/data` backups.

- Turn them on individually with `dictation` and `voice_mode`.
- On the Alpine-based images shipped here the local engine may not load (the prebuilt
  ONNX runtime binary is glibc-linked). In that case the add-on turns dictation and voice
  mode off, downloads no models, and logs a warning; the daemon still starts. Use
  `speech_provider: openai` with `OPENAI_API_KEY` in `env_vars` instead — then nothing is
  downloaded and speech runs on OpenAI's servers.
- Turn detection for voice mode always runs locally and stays tiny.

## Remote access: relay vs. direct port

By default the add-on is reachable **only** through HA ingress: no host port is published,
the daemon listens on loopback, and the ingress adapter answers only the HA ingress proxy.

Two ways to reach Paseo from a phone, tablet or the desktop app:

| | Relay (recommended) | Direct port |
|---|---|---|
| Setup | Paseo → **Pair device**; nothing to map | Map `6767/tcp` in the **Network** tab **and** set `password` |
| Authentication | Pairing code + Paseo password if you set one | Paseo password, always |
| Exposure | Outbound-only connection via Paseo's encrypted relay | A LAN port with the web UI and API behind it |
| Works from | Any network, no port forwarding | Only where the HA host is reachable |
| Control | Unset `relay` = Paseo decides; `true`/`false` forces it | Independent of relay |

Leave `relay` **unset** if you want the state to be yours to toggle inside Paseo (it
persists across restarts). Set it to `true`/`false` to lock it from the add-on options.

For the direct port, also add any public DNS name you use to `hostnames`, otherwise the
daemon rejects the request with "Host not allowed". Without a password the port stays
closed even when mapped — the add-on logs a warning and the daemon remains loopback-only.
The sidebar path never asks for the password: nginx authenticates to the daemon for you.

## Agent providers

The `providers` option lists the same six providers Paseo supports:

| ID | Agent | Installed from |
|---|---|---|
| `pi` | Pi | npm `@earendil-works/pi-coding-agent` (on by default) |
| `claude` | Claude Code | npm `@anthropic-ai/claude-code` |
| `codex` | Codex | npm `@openai/codex` |
| `copilot` | GitHub Copilot CLI | npm `@github/copilot` (sign in with `copilot login` in a terminal, or set `COPILOT_GITHUB_TOKEN` in `env_vars`) |
| `opencode` | OpenCode | npm `opencode-ai` |
| `omp` | Oh My Pi | npm `@oh-my-pi/pi-coding-agent` plus the Bun runtime it needs (best effort, see [Known limitations](#known-limitations)) |

On every start the add-on installs the selected providers, removes the deselected ones and
sets each provider's enabled flag in Paseo. A provider is enabled only if it is selected
**and** its CLI runs; if an install fails, the log shows why, Paseo starts with that
provider disabled, and the next start retries. Deselecting a provider keeps its login and
settings under `/data/home`, so selecting it again restores them. With an empty list Paseo
starts with every provider disabled.

### Which versions are installed

No agent CLI is part of the add-on image, and the add-on does not pin their versions:

- **Latest stable, on every start.** The add-on asks the npm registry for each selected
  package's `latest` release and installs it when it differs from the installed one. A
  prerelease on the `latest` tag is ignored. A restart therefore picks up new agent releases
  without an add-on update.
- **No registry, no change.** If the registry can't be reached, installed providers keep
  their version and the log says the update check was skipped. A provider that was never
  installed stays disabled until a start with network access.
- **Broken upgrades roll back.** If a new release installs but its CLI does not run, the
  previous version is put back and stays enabled. That exact release is recorded in
  `/data/agents/.paseo-ha-providers.failed` and not tried again; the next newer release is.
- **Maintainer hold.** If a new agent release breaks with the Paseo version this add-on
  ships, an add-on update can hold that package at a known good version until it is fixed.
- The start log has a `Providers: ...` line with each enabled provider's version.

## Logging in agents

Pi is selected by default, so it is offered as a provider once the first start has
installed it (until you remove it from `providers`). To authenticate:

1. Open Paseo from the sidebar and start a terminal session.
2. Run the agent's login flow, e.g. `pi` (then its auth command), `claude`, `codex login`,
   `copilot login` or `opencode auth login`.
3. Or skip interactive login entirely by putting the provider key in `env_vars` (for
   example `ANTHROPIC_API_KEY`).

Credentials are stored under `/data/home` (`~/.claude`, `~/.codex`, `~/.pi/agent`,
`~/.config`, `~/.local/...`), which is persistent, private to the add-on, and included in
HA backups. They are never written to the editable `/config` folder.

All agent CLIs come from the `providers` option: they are installed with npm into
`/data/agents` and put first on `PATH`. Expect the first start after a change to take a
while. Later starts only make a quick version check per provider and download nothing
unless a newer release is out.

## Pi packages

Pi is extended with [packages](https://pi.dev/packages) (extensions, skills, prompts, themes). The add-on installs these defaults the first time it starts:

| Package | What it adds | Setup |
|---|---|---|
| `@juicesharp/rpiv-todo` | A todo list the agent keeps up to date. Paseo shows it as a panel. | None. |
| `@juicesharp/rpiv-ask-user-question` | Structured multiple-choice questions instead of free-text guesses. Paseo shows them as dialogs. | None. |
| `pi-subagents` | Hands tasks to sub-agents. Paseo shows their activity. | None. |
| `pi-provider-litellm` | Use models through a LiteLLM proxy. | Run `/login litellm` in a Pi session, or add `LITELLM_BASE_URL` and `LITELLM_API_KEY` to `env_vars`. |
| `pi-web-access` | Web search and page fetching. | Works without a key. Add provider keys to `env_vars` or `/data/home/.pi/agent/web-search.json`. YouTube and video features need `yt-dlp` and `ffmpeg`, which the image does not include. |

Manage packages with Pi's own commands from a Paseo terminal. There is no add-on option and no file to edit:

```sh
pi list                          # what is installed
pi install npm:<package>         # add a package (or git:github.com/<user>/<repo>)
pi remove npm:<package>          # remove one, including a default
pi config                        # switch single extensions/skills on or off
pi install npm:<package>@<version>  # move a package to another version
pi update --extensions           # update packages that are not pinned to a version
```

- **Your changes persist.** Packages, their files and Pi's settings live in `/data`, so restarts, add-on updates and backup restores keep them.
- **A removed default stays removed.** The add-on offers each default once and records it in `/data/paseo-ha/pi-packages.offered`. To get one back, run `pi install` for it. To reset to the defaults, delete that file and restart: every default you removed is installed again.
- **New defaults arrive with updates.** When a release adds a default, it is installed once on the first start after the update. A release that only changes the version of a default does not touch your copy. Defaults are pinned to a version, and `pi update --extensions` never moves a pinned package. To upgrade one, install the version you want (`pi install npm:<package>@<version>` replaces the pinned entry), or install it without a version (`pi install npm:<package>`) so `pi update --extensions` keeps it current.
- **Offline.** Defaults need network access to install. If one fails, the add-on logs a warning, still starts and tries again on the next start. All default installs share a 10-minute budget on each start, so a stalled registry cannot delay the add-on for long; defaults not reached are installed on the next start. With `PI_OFFLINE=1` set in `env_vars`, installs are skipped.
- The start log has a `Pi packages: ...` line listing what is installed.

## Folders and storage

| Path in the container | Access | What it is |
|---|---|---|
| `/homeassistant` | read-write | Your live Home Assistant configuration (`configuration.yaml`, `automations.yaml`, `scripts.yaml`, `scenes.yaml`, `packages/`, `blueprints/`, `custom_components/`, `secrets.yaml`, `.storage/`). Changes affect the running home. |
| `/addon_configs` | read-write | Configuration folders of **all** other add-ons (Zigbee2MQTT, Mosquitto, ESPHome, ...). |
| `/config` | read-write | This add-on's own editable agent-config folder (see below). On the host it is `/addon_configs/<repo>_paseo`, so File Editor, Samba and the Studio Code Server see it. |
| `/share` | read-write | The add-on shared folder — convenient for worktrees, exports and files to hand between add-ons. |
| `/ssl` | read-only | TLS certificates. Agents can inspect them, never change them. |
| `/media` | read-only | The HA media library. |
| `/backup` | read-only | HA backups. |
| `/data` | private | Add-on state: Paseo home (`/data/home/.paseo`), all agent credentials and sessions, installed agents (`/data/agents`), Pi packages (`/data/home/.pi/agent/npm`) and the record of which defaults were offered (`/data/paseo-ha/pi-packages.offered`), skill-link manifest. Not shown by File Editor/Samba, but part of HA backups. |

## Editable agent configuration

`/config` is the folder you edit; every agent picks it up on the next start.

```
/config/
  AGENTS.md              your shared instructions for every agent
  skills/<name>/SKILL.md skills available to Pi, Claude Code, Codex and OpenCode
  claude/agents/         Claude Code subagents
  claude/commands/       Claude Code slash commands
  opencode/agents/       OpenCode agents
  opencode/plugins/      OpenCode plugins
  pi/extensions/         Pi extensions
  pi/prompts/            Pi prompts
  codex/prompts/         Codex prompts
  README.md              the same explanation, in the folder
```

- **Nothing is overwritten once it exists.** The folders and the two seed files are created
  on first start only.
- **Shared instructions:** edit `AGENTS.md`. On every start the add-on concatenates the
  bundled Home Assistant guidance with your `AGENTS.md` into each tool's own global file
  (`CLAUDE.md`, `AGENTS.md`, …). Those generated files live in `/data`, carry a
  "do not edit" header, and are rewritten on each start — your edits always go to
  `/config/AGENTS.md`.
- **Skills:** put a folder with a `SKILL.md` in `/config/skills/`. It is linked (not
  copied) into the skill locations the tools read. Bundled skills are linked first and
  yours second, so **a user skill named like a bundled one wins** — copy
  `/opt/paseo-ha/skills/home-assistant` to `/config/skills/home-assistant` and edit that to
  customise the HA guidance. If a skill name collides with one of Paseo's own built-in
  skills, the add-on warns in the log and skips it, because Paseo manages those entries.
- **Per-agent folders** above are directory symlinks into the tools' home folders. If a
  tool already has a real folder there, it is moved to
  `<folder>.paseo-ha-backup-<timestamp>` instead of being deleted; move your files into
  `/config` afterwards.

## What agents can do with Home Assistant

No token setup is needed — the Supervisor hands the add-on an access token and the add-on
exports it to the daemon and every agent:

- `SUPERVISOR_TOKEN`, `HASS_SERVER` (`http://supervisor/core`) and `HASS_TOKEN`.
- Core REST API: `http://supervisor/core/api/...` — check configuration, read states, call
  services, reload domains, read the error log.
- Core WebSocket API: `ws://supervisor/core/websocket` — registries, dashboards and other
  things that are not in YAML. The image ships a helper for it:
  `paseo-ha-ws '{"type":"config/entity_registry/list"}'`.
- The `ha` CLI (Supervisor access, `manager` role): `ha core check`, `ha core logs`,
  `ha core restart`, `ha apps logs <slug>` (in `ha` CLI 5.x `ha addons` is its deprecated
  alias), `ha backups new`, `ha supervisor logs`.
- Restarting Core does not restart this add-on, so an agent can restart HA and keep
  reading the log afterwards.

Agents run as root inside this container, and their file edits under `/homeassistant` are
live. Read [Security and trust model](#security-and-trust-model) before letting an agent
loose on your home.

## Home Assistant MCP tools

Home Assistant can publish its own MCP server ("Model Context Protocol Server"). When it
is enabled, the add-on detects it on start and wires it into Pi, Claude Code, Codex and
OpenCode automatically as an MCP server named `homeassistant` — no manual JSON editing.

To enable it in Home Assistant:

1. **Settings → Devices & Services → Add Integration**.
2. Search for **Model Context Protocol Server** and complete the setup.
3. Expose the entities agents should reach - the MCP server only sees entities marked as
   exposed in their entity settings.
4. Restart the add-on. The log states whether the endpoint was found.

The add-on probes `http://supervisor/core/api/mcp` and falls back to
`http://homeassistant:8123/api/mcp`, using `SUPERVISOR_TOKEN`. If the log says the token
was rejected (401/403), create a long-lived Home Assistant token and add it to `env_vars`
as `HA_MCP_TOKEN` — the agents' MCP entries then reference that variable instead.

When the integration is not enabled the add-on logs one informational line and agents start
normally — they still have the REST API, the WebSocket API and the `ha` CLI.

The generated MCP entries are merged into each tool's own config file and never replace it.
An existing `homeassistant` server entry that is not the add-on's is left alone, and the
token is referenced by environment variable name, so no secret is written to disk.

## Bundled guidance and the safe edit workflow

The image ships a `home-assistant` skill and a short set of global instructions for every
agent. They cover the folder layout, API and `ha` CLI recipes, and require this workflow
for any change:

1. Understand the current setup (including `!include` and `packages:`) and read real entity
   IDs from the API instead of guessing them.
2. Snapshot — commit if `git_snapshot` is on, otherwise suggest a backup for big changes.
3. Edit the narrowest file, keeping your style.
4. `check_config` (or `ha core check`) — must report valid.
5. Reload the narrowest domain (`automation.reload`, `template.reload`, …). Restart Core
   only when the change really needs it, and only after asking.
6. Verify via states and `ha core logs`.
7. Commit the result, or roll back and tell you what broke.

Hard rules the guidance imposes: never print or copy values from `secrets.yaml` or any
token (use `!secret`), never edit `/homeassistant/.storage/` while Core runs, never touch
the recorder database, and always ask before restarting Core or changing another add-on.

## Git snapshots and rollback

`git_snapshot: true` turns `/homeassistant` into a git repository the first time it is
enabled, so agent changes are reviewable and revertible:

- `git init -b main`, a local identity of `Paseo Agent <paseo-agent@homeassistant.local>`,
  and an initial commit.
- A `.gitignore` is written **only if none exists** and keeps `secrets.yaml`,
  `.storage/`, databases, logs, `.cloud/`, `deps/`, `tts/`, `__pycache__/`,
  `home-assistant.log*`, `.HA_VERSION` and `.ha_run.lock` out of git.
- **An existing repository is never modified.** If you already keep your config in git, the
  add-on only marks it as a `safe.directory` so root can operate on it, and leaves your
  history, ignores and remotes alone.
- Turning the option off does not delete `.git`.
- The bundled guidance tells agents to commit before and after each change with a
  descriptive message, so you can review `git -C /homeassistant log` in a Paseo terminal.

Roll back a bad change:

```sh
git -C /homeassistant revert --no-edit HEAD    # undo the last commit
# or, for an uncommitted mess:
git -C /homeassistant checkout -- automations.yaml
```

**Take a backup first.** A git snapshot is not a backup: it lives in the same folder it
protects, and it is not a Home Assistant backup. Before a significant change — or whenever
`git_snapshot` is off — create one from a Paseo terminal with `ha backups new`, or use
**Settings → System → Backups**. Restoring a backup is the reliable way out of a change you
cannot revert.

## Security and trust model

Read this section before you enable the add-on. It is what makes agents useful, and what
makes them dangerous.

- **Agents run as root** inside the add-on container, and **read-write mount** the Home
  Assistant configuration, all other add-ons' configuration folders and `/share`. A change
  an agent makes is a change to your live home, made with the permissions of the HA system
  user. (Root is used because the mapped HA folders are root-owned; a non-root add-on user
  could not write them without changing ownership of your config.)
- **Agents hold a Home Assistant Core token and Supervisor `manager` access.** With it they
  can read every entity state, call any service, check and reload configuration, read Core
  and add-on logs, restart Home Assistant Core, and manage other add-ons. `manager` does not
  include host/OS operations (that would be `admin`, which this add-on does not request).
- **This lowers the add-on's security rating.** HA shows it as a higher-privilege add-on;
  that is accurate and intentional. It is why the guidance, the ask-before-restart rule and
  git snapshots exist.
- **Whoever can open the sidebar panel can drive the agents.** Ingress is authenticated by
  Home Assistant only: any HA user with access to the panel gets full control of Paseo, and
  therefore of everything listed above. Restrict the panel to the users who should
  configure HA.
- **Panel content is served from your HA origin.** Like every ingress add-on, HTML that
  Paseo renders (agent previews, dashboards) runs inside your HA origin. Treat untrusted
  content pasted into a prompt as you would in any other ingress add-on.
- **Direct-port access needs a password.** With no password the daemon stays on loopback
  even if you map the port. The daemon's own traffic on the published port is plain HTTP —
  use it on a trusted LAN or in front of TLS termination you control, or prefer the relay.
- **Values in `env_vars` are secrets in `/data`**, exported into every agent's environment.
  They are never logged, but any agent (and anything it prints from the environment) can
  read them.
- **Prompt injection is the real risk.** Agents read files that external systems can
  influence (logs, webhooks, device payloads). The mitigations are narrow: read-only
  `/ssl`, `/media`, `/backup`; the ask-before-restart and ask-before-touching-other-addons
  rules; and, for anything serious, `git_snapshot` plus a backup.

Recommendations: keep a current HA backup, enable `git_snapshot`, give the panel only to
people you trust with your home, and review agent commits.

## Supported architectures

`amd64` and `aarch64` images are built from Home Assistant base images and
published to GHCR for every release, so installs pull instead of build.

- `armv7` and `i386` (32-bit) are not supported. Home Assistant deprecated 32-bit systems in
  2025 and dropped them from Core 2025.12 and Home Assistant OS 17. A Raspberry Pi 3 or 4
  needs the 64-bit Home Assistant OS image (`aarch64`).

## Troubleshooting

Open the add-on **Log** tab. The daemon's own output is there too.

| Log line | Meaning |
|---|---|
| `Port 6767 is mapped but no password is set; the daemon stays loopback-only` | Set `password` to enable direct access, or unmap the port. |
| `A password is set but port 6767 is not mapped...` | Harmless: the password only applies to the direct port. Ingress never asks for it. |
| `Local speech engine (sherpa-onnx-node) cannot load on this platform` | Dictation and voice mode were turned off and nothing was downloaded. Use `speech_provider: openai` with `OPENAI_API_KEY` in `env_vars`. |
| `Provider <id> could not be installed or does not run on <arch>` | That provider is disabled in Paseo and retried on the next start. Pi and the other providers still work. |
| `Provider <id> is not installed and the npm registry could not be reached` | The add-on has no network access to npm. That provider stays disabled until a start that can reach `registry.npmjs.org`. |
| `Could not check for a newer <id>; keeping the installed version` | Harmless: the registry was unreachable, so the installed version is used. |
| `Provider <id> <package>@<version> could not be installed or does not run on <arch>; rolling back` | A new release is broken here. The previous version was restored and that release is skipped from now on. |
| `Unknown provider '<name>' in providers option` | The value is ignored. Use one of `claude`, `codex`, `copilot`, `opencode`, `pi`, `omp`. |
| `Skill '<name>' ... has the same name as a Paseo built-in skill; skipped` | Rename your skill folder so Paseo's own skill sync cannot conflict. |
| `Moved existing <dir> to <dir>.paseo-ha-backup-...` | A real tool folder was in the way of a `/config` link. Move your files into `/config` and delete the backup. |
| `SUPERVISOR_TOKEN is not set` | The container is not running under the Supervisor (e.g. a plain `docker run`). API access is unavailable. |

If the panel opens to a blank page: check the Log tab for a failed `init-paseo` or nginx
render, then restart the add-on. If the daemon is healthy but the panel stays blank, reload
the browser tab; if it still fails, restart Home Assistant Core, which owns the ingress
session.

## Known limitations

- **Sidebar icon:** Home Assistant only accepts Material Design Icons for sidebar panels,
  so the entry uses `mdi:robot-outline` rather than the Paseo logo. The store icon and
  logo do use Paseo's.
- **The ingress adapter is coupled to Paseo internals.** It prefixes root-absolute asset
  paths, the `/ws` WebSocket and the daemon's connection hint at request time (nginx
  `sub_filter` plus a small browser shim). A Paseo version bump can change those internals;
  releases are gated by a smoke test that checks asset rewriting, the health endpoint and a
  WebSocket upgrade, but a new Paseo release can still need the rules updated. Bumps are
  documented in the repository README.
- **Tested flows:** the sidebar UI was click-tested behind a mock Ingress (boot and auto-connect, deep-link reload, Settings, new workspace, terminal with live output, file explorer and opening a file, file download link). Anything not in that list is untested under Ingress; if a link or request escapes the Ingress path, the direct port still works.
- **PWA installation from the panel is not a supported path.** The manifest's `start_url` is
  prefixed for ingress, but its `scope` stays `/`, so installing Paseo as a standalone app
  from inside Home Assistant is not expected to behave.
- **Paseo's Pair-device and share links do not point at the ingress URL**, so the mobile and
  desktop apps connect through the relay or the direct port rather than through the sidebar
  panel.
- **The first start needs internet access.** No agent is in the image, so a fresh install
  that can't reach the npm registry starts with every provider disabled (the log says so)
  and installs them on a later start.
- **New agent releases arrive on restart, untested.** Agents follow their latest stable
  release, not a version tested with this add-on, so a release that installs and starts but
  misbehaves with the bundled Paseo reaches you on your next restart. Report it; an add-on
  update can hold that agent at the previous version.
- **Oh My Pi (`omp`) does not run on the Alpine (musl) images.** Its native add-on is
  published for glibc only (the aarch64 package has no musl build either) and refuses to
  load on musl, even with `gcompat` (checked on amd64). Selecting `omp`
  is safe: the install is attempted, the failure is logged and Oh My Pi stays disabled.
- **Claude Code refuses `--dangerously-skip-permissions` when run as root**, so its
  permission prompts stay on. Approve them interactively, or use Pi.
- **No multi-user isolation.** Everyone using the panel shares one Paseo daemon, one set of
  agents, one workspace and one set of credentials.
- **Local speech is unavailable on the Alpine (musl) images** where the prebuilt ONNX
  runtime cannot load; use `speech_provider: openai`.
- **Backups of `/data` are large** once speech models and agent CLIs are installed; a
  restore re-downloads nothing, but plan for the size.

## See also

- Source, issues and releases: <https://github.com/farajfarook/paseo-ha-addon>
- Paseo: <https://paseo.sh>
- Pi coding agent: <https://www.npmjs.com/package/@earendil-works/pi-coding-agent>

Paseo is © the Paseo authors, Apache-2.0. This add-on is not affiliated with or endorsed by
the Paseo project.

[aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg
[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg
