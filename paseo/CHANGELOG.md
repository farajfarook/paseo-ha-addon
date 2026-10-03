# Changelog

## 0.10.3-5

- Install a set of default Pi packages on first start: `@juicesharp/rpiv-todo` and `@juicesharp/rpiv-ask-user-question` (the todo list and question dialogs Paseo shows for Pi), `pi-subagents`, `pi-provider-litellm` and `pi-web-access`.
- Manage packages with `pi install`, `pi remove` and `pi list` in a Paseo terminal. Your changes persist across restarts, add-on updates and backups, and a default you remove stays removed. Nothing to configure and no new options.
- Defaults are installed over the network on the first start after this update, so that start takes longer. A failed install is logged and retried on the next start.

## 0.10.3-4

- Stop downloading speech models that cannot be used. With `dictation` or `voice_mode` on and `speech_provider: local`, the Alpine image cannot load the local speech engine, but the daemon still downloaded about 790 MB of models. The add-on now turns both features off in that case, downloads nothing, and logs a warning that points to `speech_provider: openai`.

## 0.10.3-3

- Drop the `armv7` (32-bit ARM) image. Home Assistant no longer supports 32-bit systems (Core 2025.12, Home Assistant OS 17), and the image took far too long to build under emulation. Raspberry Pi 3 and 4 users need the 64-bit Home Assistant OS image, which uses `aarch64`.
- Includes the 0.10.3-2 ingress fix (the web UI no longer stalls on a blank page). The 0.10.3-2 images were published for `amd64` and `aarch64` only, with no GitHub Release.

## 0.10.3-2

- Fix the Paseo web UI stalling on a blank page under Home Assistant Ingress. The ingress adapter injected its shim tag into the JavaScript bundle as well as the HTML page, which broke the bundle with a syntax error. The shim is now injected into HTML responses only.
- Keep the app's routes working while it boots under Ingress, and rewrite file download links so downloads work through Ingress.

## 0.10.3-1

First release of the Paseo add-on.

- Paseo **0.10.3** (`@getpaseo/cli`) with its bundled web UI, opened from the Home Assistant sidebar through Ingress.
- Pi coding agent **1.0.0** (`@earendil-works/pi-coding-agent`) bundled; Claude Code, Codex and OpenCode installable through the `agents` option.
- Home Assistant integration: `/homeassistant`, `/addon_configs` and `/share` read-write; Core API and `ha` CLI access; HA MCP server wired into MCP-capable agents; bundled Home Assistant skill; default "Home Assistant" project; optional git snapshots.
- Editable agent configuration (skills, shared `AGENTS.md`, agent definitions) in the add-on's `addon_configs` folder.
- Optional password-protected direct port 6767 for the Paseo apps and CLI.
- Images for `amd64`, `aarch64` and `armv7` (armv7 best-effort).
