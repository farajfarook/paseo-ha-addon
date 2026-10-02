# Changelog

## 0.10.3-1

First release of the Paseo add-on.

- Paseo **0.10.3** (`@getpaseo/cli`) with its bundled web UI, opened from the Home Assistant sidebar through Ingress.
- Pi coding agent **1.0.0** (`@earendil-works/pi-coding-agent`) bundled; Claude Code, Codex and OpenCode installable through the `agents` option.
- Home Assistant integration: `/homeassistant`, `/addon_configs` and `/share` read-write; Core API and `ha` CLI access; HA MCP server wired into MCP-capable agents; bundled Home Assistant skill; default "Home Assistant" project; optional git snapshots.
- Editable agent configuration (skills, shared `AGENTS.md`, agent definitions) in the add-on's `addon_configs` folder.
- Optional password-protected direct port 6767 for the Paseo apps and CLI.
- Images for `amd64`, `aarch64` and `armv7` (armv7 best-effort).
