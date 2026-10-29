## Why

Paseo 0.14.0 is out (stable, 2026-10-29). Plugins can give tools to specific agents and add MCP servers when a session opens; Chat display settings can group tool calls or collapse completed turns; Voice settings can download local speech models (including SenseVoice and Whisper for Chinese dictation); there is a choice of Enter or Ctrl/Cmd+Enter to send, sent-message recall and long-press Send; idle agent runtimes are released after an hour and resumed on the next prompt; and many fixes (terminal glyph corruption, restored workspaces and tabs, background Git fetch credential prompts, large ACP terminal output blocking the daemon). The add-on bundles 0.13.2, so users only get these once the pin moves. Pi 1.4.0, HA CLI 5.6.0 and gh 2.103.3 are already current.

## What Changes

- Pin Paseo 0.14.0 in `paseo/build.yaml` and both `ARG PASEO_VERSION` lines of `paseo/Dockerfile`; add-on version `0.14.0-1` in `paseo/config.yaml`.
- CHANGELOG entry naming the bundled Paseo **0.14.0** and Pi **1.4.0**, with a note that going back to an older add-on version needs the pre-update backup (Paseo 0.14.0 saves speech and idle-cleanup settings in a new `config.json` format).

The add-on's specified behaviour is unchanged: nothing under `paseo/rootfs/` changes.

- `paseo-anchors.sh --diff 0.13.2 0.14.0`: anchors unchanged. `paseo-anchors.sh --check 0.14.0`: all ingress anchors present.
- `check-providers.sh 0.14.0`: built-in `claude codex copilot omp opencode pi`, plugin `antigravity hoplite muse`, hoplite excluded; the providers option matches.
- `npm pack` diff of `@getpaseo/server` 0.13.2 → 0.14.0: `dist/server/server/web-ui.js` is byte-identical; `web-ui/index.html` only changes the entry bundle hash in its root-absolute `<script src="/_expo/static/js/web/index-<hash>.js">` (rewritten by nginx `sub_filter '"/_expo/'`). `@getpaseo/cli` 0.13.2 → 0.14.0 changes only `package.json` (dependency versions), so the `paseo daemon run|status|stop|config` and `paseo provider ls` commands the add-on uses are unchanged. The server's set of `PASEO_*` environment variables only gains `PASEO_CONFIG_BYTES`; every variable the add-on sets is still read.
- Release notes: no breaking, removed or changed entries. The three upgrade notes were checked against the add-on:
  - "Voice mode now defaults to off": the add-on always sets `PASEO_VOICE_MODE_ENABLED` and `PASEO_DICTATION_ENABLED` from its `voice_mode`/`dictation` options (both `false` by default), and the 0.14.0 speech resolver still reads those variables before persisted settings, so the add-on's defaults and options behave as before.
  - "If environment variables select OpenAI speech, move keys stored only in legacy `providers.openai` into Voice settings": the add-on selects OpenAI speech through the `PASEO_*_STT_PROVIDER`/`PASEO_VOICE_TTS_PROVIDER` variables and documents `OPENAI_API_KEY` in `env_vars`; 0.14.0 still reads `OPENAI_API_KEY` (after `OPENAI_STT_API_KEY`/`OPENAI_TTS_API_KEY`), and the add-on never writes `providers.openai`.
  - "Before downgrading to 0.13.2, restore a backed-up `config.json`": covered by the CHANGELOG note (Home Assistant's pre-update add-on backup holds `/data`).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None (pin-only bump, `skip_specs`, AGENTS.md Rule 1.4).

## Impact

- `paseo/build.yaml`, `paseo/Dockerfile`, `paseo/config.yaml`, `paseo/CHANGELOG.md`.
- Published images `ghcr.io/farajfarook/{amd64,aarch64}-addon-paseo:0.14.0-1`.
