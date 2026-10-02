# Proposal

## Why

Configuring Home Assistant (YAML, automations, scripts, dashboards, add-on configs) is tedious and error-prone. Coding agents (Claude Code, Codex, OpenCode, Pi, …) are good at exactly this kind of work. [Paseo](https://paseo.sh) runs those agents behind a daemon with a self-hostable web UI. The purpose of this add-on is to make **configuring Home Assistant with agents** easy. Paseo runs on the HA box and opens from the HA sidebar, authenticated by HA. Agents start inside the HA configuration with live API access to validate, reload and inspect HA, and with guidance and rollback that keep changes safe. Users don't manage Docker, ports, tokens or reverse proxies.

## What Changes

- Publish this directory as the public GitHub repo `farajfarook/paseo-ha-addon` and turn it into a Home Assistant **add-on repository** (`repository.yaml`) containing a single `paseo` add-on.
- Package the Paseo daemon + bundled web UI (pinned `@getpaseo/cli` / `@getpaseo/server` release) into a multi-arch add-on image for `aarch64`, `amd64` and `armv7` on Home Assistant base images.
- Expose the Paseo web UI through **HA Ingress** with `panel_icon`/`panel_title` so it appears as a "Paseo" entry in the HA side menu and opens as an embedded web application. HA's login is the only authentication on this path; the daemon itself only listens on loopback.
- Add an ingress adapter (reverse proxy inside the container) that makes Paseo's root-path web app, `/api/*` calls and `/ws` WebSocket work under HA's dynamic `/api/hassio_ingress/<token>/` prefix.
- Bundle the **Pi coding agent harness** (`@earendil-works/pi-coding-agent`) in the image so Paseo has a working provider out of the box, and let users opt in to additional agent CLIs (Claude Code, Codex, OpenCode) via add-on options, installed persistently.
- Persist Paseo state, agent credentials and sessions under the add-on's private `/data`. Give users an editable agent-config folder (skills, shared instructions, agent definitions) in the add-on's own `addon_configs` folder, reachable from File Editor/Samba.
- **Home Assistant integration:** map the HA config (`/homeassistant`, rw), all add-on configs (`/addon_configs`, rw), `/share` (rw) and `ssl`/`media`/`backup` (ro). Auto-register `/homeassistant` as the default "Home Assistant" Paseo project. Grant HA Core API and Supervisor (`manager`) access with the `ha` CLI bundled, so agents can check config, reload, read logs and restart. Wire HA's MCP server into agents that support MCP. Ship a bundled Home Assistant skill/instructions with a safe edit workflow. Offer an optional git snapshot of `/homeassistant` for rollback.
- Optional direct-port access (disabled by default) that requires a Paseo password when enabled.
- Use the Paseo logo for the add-on store `icon.png` / `logo.png`. The sidebar entry uses the closest Material Design Icon because HA panels only accept `mdi:` icons.
- Add user documentation (`README.md`, `DOCS.md`, `CHANGELOG.md`, option translations) and CI that lints and builds the add-on for all architectures.
- Publish pre-built multi-arch images to GHCR (`ghcr.io/farajfarook/{arch}-addon-paseo`) from a tag-triggered GitHub Actions workflow, so HA pulls instead of building on-device.

## Capabilities

### New Capabilities

- `addon-packaging`: The add-on repository and manifest — repository metadata, add-on `config.yaml`/`build.yaml`, supported architectures, base images, pinned Paseo version, branding assets (Paseo logo icon), documentation and CI build/lint.
- `ingress-web-ui`: Serving the Paseo web UI inside Home Assistant — sidebar panel registration, ingress path-prefix handling for HTTP and WebSocket traffic, access restriction to the HA ingress proxy, and optional password-protected direct port.
- `agent-runtime`: The runtime environment Paseo agents run in — daemon lifecycle and health, the bundled Pi harness, optional extra agent CLIs, persistence of state and credentials, the editable agent-config folder, and user-facing add-on options.
- `ha-integration`: What agents can do with Home Assistant — folder mappings, the default HA project, live Core/Supervisor API access and `ha` CLI, MCP wiring, bundled HA guidance and safety rules, and optional git snapshots for rollback.

### Modified Capabilities

<!-- None: this is a new repository with no existing specs. -->

## Impact

- **New code/files** (repository is currently empty apart from OpenSpec tooling): `repository.yaml`, `paseo/` add-on directory (`config.yaml`, `build.yaml`, `Dockerfile`, `rootfs/` s6/bashio service scripts, nginx config, ingress shim, `icon.png`, `logo.png`, `DOCS.md`, `README.md`, `CHANGELOG.md`, `translations/en.yaml`), `.github/workflows/` (lint, test build, publish), `LICENSE`.
- **Hosting**: new public GitHub repo `farajfarook/paseo-ha-addon`. Three public GHCR packages. GitHub Actions on free public-repo minutes.
- **External dependencies**: Home Assistant Supervisor/Ingress, HA base images, Node.js ≥ 22.19, `@getpaseo/cli` (Apache-2.0), `@earendil-works/pi-coding-agent`, optional `@anthropic-ai/claude-code`, `@openai/codex`, `opencode-ai`, nginx.
- **Upstream coupling**: Paseo's web UI assumes it is served from `/` and connects to `<host>:<port>/ws`; the ingress adapter depends on that behaviour and must be re-verified on every Paseo version bump.
- **Security**: agents run as root with read-write access to the HA config and all add-on configs, a Core API token and the Supervisor `manager` role (they can restart Core and manage add-ons). The add-on relies on HA authentication for ingress. Documentation must make the trust model explicit and recommend backups and git snapshots.
- **Platform risk**: `armv7` is deprecated by Home Assistant and some agent CLIs/native modules may not ship 32-bit ARM builds; support there is best-effort.
