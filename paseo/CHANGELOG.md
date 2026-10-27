# Changelog

## 0.13.2-1

- Bundled Paseo **0.13.2** (was 0.13.1). It fixes bottom sheets keeping window-size listeners after they close, plus animation and chat-streaming fixes for the Android app.
- The bundled GitHub CLI is now 2.103.3 (was 2.103.2). The ingress adapter needed no change, and there is nothing to do after updating.
- Bundled Paseo **0.13.2** and Pi **1.4.0** (Pi and the other npm agents still follow their latest stable release).

## 0.13.1-1

- Bundled Paseo **0.13.1** (was 0.13.0). It fixes a startup crash when Show background is on and a project has eight or more workspaces.
- The ingress adapter needed no change, and there is nothing to do after updating.
- Bundled Paseo **0.13.1** and Pi **1.4.0** (Pi and the other npm agents still follow their latest stable release).

## 0.13.0-1

- Bundled Paseo **0.13.0** (was 0.12.0). New in Paseo: connected hosts, so agents can create, prompt and monitor agents on other machines; an All changes view in the Changes pane that shows committed and uncommitted work in one diff; and pasting images or dropping files into terminals. It also fixes agents showing as running after a daemon restart and large Claude sessions showing an empty chat or crashing the daemon.
- The bundled GitHub CLI is now 2.103.2 (was 2.103.0). The ingress adapter needed no change, and there is nothing to do after updating.
- Bundled Paseo **0.13.0** and Pi **1.4.0** (Pi and the other npm agents still follow their latest stable release).

## 0.12.0-1

- Bundled Paseo **0.12.0** (was 0.11.4). New in Paseo: background workspaces (hidden from the sidebar unless Show background is on), a Send feedback button in the diff pane, a fullscreen composer on phones, and `paseo usage` to show account quotas from the CLI. It also fixes Paseo slowly growing to about 1 GB of memory and running out of memory during long OpenCode replies.
- The bundled Home Assistant CLI is now 5.6.0 (was 5.5.0) and the GitHub CLI 2.103.0 (was 2.102.0). The ingress adapter needed no change, and there is nothing to do after updating.
- Bundled Paseo **0.12.0** and Pi **1.3.0** (Pi and the other npm agents still follow their latest stable release).

## 0.11.4-1

- Bundled Paseo **0.11.4** (was 0.11.2). Paseo's Add provider catalog now has a search box, and Remove is no longer offered for plugin providers such as Muse Code and Antigravity. Add provider failures now show as a short message.
- Paseo 0.11.3 also bundles Hoplite, a sponsored provider. The add-on does not offer it and never enables it, so nothing changes for you. There is nothing to do after updating.
- Bundled Paseo **0.11.4** and Pi **1.3.0** (Pi and the other npm agents still follow their latest stable release).

## 0.11.2-1

- Bundled Paseo **0.11.2** (was 0.11.1). It fixes text that was sometimes cut off in chats and Markdown previews on iOS. Nothing else changed in the add-on, and there is nothing to do after updating.
- Bundled Paseo **0.11.2** and Pi **1.1.0** (Pi and the other npm agents still follow their latest stable release).

## 0.11.1-1

- Bundled Paseo **0.11.1** (was 0.10.3). Two new agent providers come with it: **Muse Code** (`muse`, Meta) and **Antigravity** (`antigravity`, Google). Both appear in the `providers` option, and Paseo's own Usage screen, plugin registry and provider fixes come along with the upgrade. The ingress adapter needed no change: the anchors it rewrites are identical in 0.11.1.
- **Muse Code and Antigravity are not npm packages**, so the add-on installs them with the vendor's own installer instead of npm: Muse Code from `https://dev.meta.ai/install.sh` and Antigravity from `https://antigravity.google/cli/install.sh`. Each goes into a directory of its own under `/data/agents/bin` and is put on `PATH`. The installer runs once and the CLI updates itself afterwards: each start only checks that it still runs. Deselecting one deletes that directory and keeps its login.
- Muse Code is a large download (about 336 MB) on the first start after you select it. No provider is downloaded unless you select it. A working Muse Code or Antigravity CLI is not downloaded again; npm providers still update to new stable releases as before.
- Agents on `muse` or `antigravity` do not get the bundled Home Assistant skill, instructions or MCP tools yet; that needs a separate change. See **Known limitations**.
- Bundled Paseo **0.11.1** and Pi **1.1.0** (Pi and the other npm agents still follow their latest stable release).

## 0.10.3-9

- Fix the sidebar panel staying on **Reconnecting to host** and showing old sessions after the add-on is uninstalled and installed again. The daemon's server ID now survives a reinstall: on a fresh install it is derived from your Home Assistant instance ID and the add-on, so the same add-on gets the same ID back. If the instance ID can't be read, a random ID is used and a later reinstall gets a new one, which the panel then heals. An existing ID is never changed.
- If the browser remembers the panel's host under an older ID (installs before this release, or a restore from an older backup), the panel removes that stale entry when it opens and connects to the running daemon. Hosts on other addresses are left alone. No need to clear site data.
- Bundled Paseo **0.10.3** is unchanged. Agents still follow their latest stable release.

## 0.10.3-8

- Agents can now use git remotes without prompts. See the new **Git access** section in the documentation.
- The GitHub CLI (`gh` 2.102.0) is built in. Sign in once with `gh auth login` in a Paseo terminal, or add `GH_TOKEN` to `env_vars`. On every start git uses `gh` for `https://github.com` unless you set your own credential helper.
- SSH keys in `/homeassistant/.ssh` and `/share/.ssh` are used automatically, in place. Keys readable by others are changed to mode `600` (logged), and keys with a passphrase are skipped with a warning.
- `~/.ssh` is now persistent (`/data/home/.ssh`), so keys you create with `ssh-keygen` survive updates.
- github.com, gitlab.com and bitbucket.org host keys are built in. Other hosts are accepted on first use and remembered. A changed host key is refused.
- The start log has a `Git access: ...` line with the keys in use and the GitHub CLI state.
- `git_snapshot` no longer commits SSH keys. The `.gitignore` it writes now also excludes `.ssh/`, `id_rsa`, `id_ecdsa`, `id_ed25519` (and `_sk` variants), `*.pem` and `*.key`. Public keys can still be committed.
- A `.gitignore` written by an earlier version of the add-on gets these rules appended once on the next start. A `.gitignore` you wrote yourself is never changed.
- If SSH keys are already tracked in `/homeassistant`, the start log warns and explains how to untrack them. History is never rewritten, so rotate any key that was pushed.
- Rollback to an older version: run `git config --global --unset-all credential.https://github.com.helper` and the same for `https://gist.github.com` in a Paseo terminal, because the helper points at `gh`, which older images do not have. Bundled Paseo **0.10.3** is unchanged.

## 0.10.3-7

- No agent CLI is built into the image any more. Pi is installed on start like Claude, Codex, Copilot, OpenCode and Oh My Pi, and deselecting it in `providers` now uninstalls it. It stays selected by default.
- Every selected provider is installed at its latest stable npm release, checked on every start, instead of a version fixed by the add-on. Nothing is downloaded when no newer release is out.
- Without access to the npm registry, installed providers keep their version. A new release whose CLI does not run is rolled back to the previous version and not tried again.
- The first start after this update downloads Pi. Your Pi logins, settings and packages are kept. A fresh install now needs internet access on its first start.
- The start log has a `Providers: ...` line with each provider's version. Bundled Paseo **0.10.3** is unchanged.

## 0.10.3-6

- Install a set of default Pi packages on first start: `@juicesharp/rpiv-todo` and `@juicesharp/rpiv-ask-user-question` (the todo list and question dialogs Paseo shows for Pi), `pi-subagents`, `pi-provider-litellm` and `pi-web-access`.
- Manage packages with `pi install`, `pi remove` and `pi list` in a Paseo terminal. Your changes persist across restarts, add-on updates and backups, and a default you remove stays removed. Nothing to configure and no new options.
- Defaults are installed over the network on the first start after this update, so that start takes longer. A failed install is logged and retried on the next start.

## 0.10.3-5

- **BREAKING:** the `agents` option is replaced by `providers`, a multi-select of Paseo's six providers (`claude`, `codex`, `copilot`, `opencode`, `pi`, `omp`) that defaults to `[pi]`. There is no migration: remove and reinstall the add-on, then pick your providers again.
- Selected providers are installed and enabled in Paseo on every start; deselected providers are uninstalled and disabled. Pi stays built into the image and can now be switched off.
- Added GitHub Copilot CLI and Oh My Pi as providers. Oh My Pi cannot load its native add-on on the Alpine (musl) images yet, so it is disabled with a logged error.
- Bundled Paseo **0.10.3** and Pi **1.0.0** are unchanged.

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
