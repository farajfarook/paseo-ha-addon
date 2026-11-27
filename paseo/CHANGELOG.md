# Changelog

## 0.18.0-1

- Bundled Paseo **0.18.0** (was 0.17.5), which includes 0.17.6. Each device can choose which agent, terminal and plugin events send it notifications, agent profiles can carry a system prompt for the agents started from them, syntax highlighting covers diff and patch files and many more languages, Settings is split into Device and Host sections, and the model picker can be used with the arrow keys. Antigravity, fx, goose and Hermes now keep their model lists across restarts (in `/data/home/.paseo/cache`) instead of probing for them in the background. Fixes include OpenCode v2 agents no longer staying Running after Stop, steering a Pi agent no longer aborting a run it started on its own, a workspace created from a pull request in a fork clone checking out the right pull request, worktrees staying inside the configured worktrees folder, and timelines no longer dropping rows.
- Paseo now needs Antigravity CLI 1.5.1 or later and no longer runs `agy -p /usage` in the background. When `antigravity` is selected, the add-on installs the latest CLI with Google's installer (1.5.18 when this version was released) and the CLI updates itself afterwards; the `Providers:` line in the start log shows the installed version. There is nothing to do after updating.
- Pi is not in the image: when it is selected in `providers` (the default), the add-on installs it on start at its latest stable release, like the other npm agents (Pi **1.6.1** when this version was released).

## 0.17.5-1

- Bundled Paseo **0.17.5** (was 0.17.4). You can select several workspaces with Cmd/Ctrl+click and archive them together, agent profiles have their own settings page, Add project opens on folder search, the host picker shows host icons and latency, and schedules can archive their agent when it finishes. Fixes include agents no longer hiding the subagents they create, Claude subagents returning their final reply, agents that watch a pull request no longer staying Running, large Git workspaces no longer stalling the daemon while it scans them, Hermes and other plugin agents no longer leaving processes behind after a model list refresh times out, and idle plugin sessions no longer waking the daemon every 10 seconds. Paseo now hands MCP server tokens to Claude Code 2.1.326 or later over stdin instead of in its command line; when `claude` is selected, the add-on installs the latest Claude Code on start (2.1.332 when this version was released) unless the npm registry is unreachable or the upgrade is rolled back, as "Which versions are installed" in the documentation explains, and the `Providers:` line in the start log shows the installed version. Paseo's new Tailscale setting for a host stays locked in the add-on, which sets the daemon's listen address itself. There is nothing to do after updating.
- Updated the bundled GitHub CLI (`gh`) to **2.106.0** (was 2.105.0), which fixes seven security issues (among them untrusted terminal control characters in the output of `gh api` and other commands, and `gh skill update` installing a skill from a different repository). `gh auth logout` now also revokes the account's GitHub CLI token and removes saved HTTPS credentials for the host from Git credential helpers; use `gh auth logout --no-revoke` to keep the token valid.
- Pi is not in the image: when it is selected in `providers` (the default), the add-on installs it on start at its latest stable release, like the other npm agents (Pi **1.6.1** when this version was released).

## 0.17.4-1

- Bundled Paseo **0.17.4** (was 0.17.3), a bug-fix release. Conversations no longer disappear when a folder's capitalization differs, messages sent to archived agents start a turn again, Paseo's tools reach agents that use the newest MCP protocol, existing OpenCode sessions reopen after Paseo's tools change, OpenCode Go usage works for OpenCode 2 logins, Codex MCP startup failures show up in the daemon log, and the daemon no longer exits when it closes a session after a plugin has stopped. On Android, numbered sublists and quotes in lists no longer overlap, and the terminal keyboard no longer learns what you type.
- New agent provider: **Hermes** (`hermes`, Nous Research's Hermes Agent), which Paseo 0.17.4 bundles. Add `hermes` to `providers` to use it. It takes about 2 GB of storage (Hermes' source in `/data/agents/bin/hermes`, its own Python and Node.js runtime in `/data/home/.hermes`), and the start after selecting it takes a few minutes. Choose a model provider with `hermes setup` in a Paseo terminal, or put the provider's API key in `env_vars`. While Hermes is selected the add-on also runs its gateway (about 250 MB of memory). Update Hermes with `hermes update` in a terminal. Hermes is installed without its browser and computer-use tools, which do not run on the add-on's Alpine image, and like goose it gets no Home Assistant skill or MCP server from the add-on.
- Pi is not in the image: when it is selected in `providers` (the default), the add-on installs it on start at its latest stable release, like the other npm agents (Pi **1.6.0** when this version was released).

## 0.17.3-1

- Bundled Paseo **0.17.3** (was 0.17.1), which includes 0.17.2. Chats can show per-turn and session stats (time, tokens, cache and cost) for Claude, OpenCode v2, Pi, Oh My Pi and plugin providers, enabled providers refresh their model lists every 30 minutes, and the sidebar usage summary is on by default. Provider settings link to each provider's docs and have fuller diagnostic reports. Fixes include Tab or Enter in the slash menu no longer archiving an agent by running a stale `/exit`, busy host connections no longer dropping, Antigravity turns no longer staying busy after creating a schedule, Antigravity Orchestrator chats opening again, and the `/` and `@` pickers no longer disappearing after going back to a workspace. There is nothing to do after updating.
- Pi is not in the image: when it is selected in `providers` (the default), the add-on installs it on start at its latest stable release, like the other npm agents (Pi **1.6.0** when this version was released).

## 0.17.1-1

- Bundled Paseo **0.17.1** (was 0.16.2), which includes 0.17.0. Antigravity now has permission modes, tool approvals and session history (it needs Antigravity CLI 1.5.0 or later; the add-on installs its latest release, which then updates itself). You can start a workspace in an existing worktree or from a branch or pull request, ask an agent to watch a pull request for new checks, reviews and comments, and see an agent's heartbeats next to its background tasks. Usage shows quota forecasts and OpenRouter balances. Messages from other agents now wait for the current turn to end. Many fixes, among them chat history no longer timing out after a reconnect and long Claude chats reopening faster.
- New agent provider: goose (open source, from the Agentic AI Foundation, formerly Block). Add `goose` to `providers` to use it. The add-on installs it with goose's own installer into `/data/agents/bin/goose` (about 160 MB). Set it up with `goose configure` in a Paseo terminal, or put `GOOSE_PROVIDER`, `GOOSE_MODEL` and that provider's API key in `env_vars`. Unlike the other vendor-installed agents, goose does not update itself here: run its installer again to update it (see the documentation).
- Paseo can now show each agent's installed version and offer to update some of them from its settings. In the add-on, restart it instead: every start installs the latest stable release of the npm agents, and Pi refuses the in-app update because the add-on manages its install.
- Pi is not in the image: when it is selected in `providers` (the default), the add-on installs it on start at its latest stable release, like the other npm agents (Pi **1.6.0** when this version was released).

## 0.16.2-1

- Bundled Paseo **0.16.2** (was 0.16.1), a bug-fix release. Agents no longer get stuck after you press Stop a second time, Steer no longer cancels a Claude compaction in progress, and Collapse turns no longer hides a finished Claude reply. Archiving a workspace no longer loses commits made in a detached worktree, creating a worktree no longer times out on large ignored folders, and a failed file download no longer takes over the web UI. There is nothing to do after updating.
- Pi is not in the image: when it is selected in `providers` (the default), the add-on installs it on start at its latest stable release, like the other npm agents (Pi **1.5.2** when this version was released).

## 0.16.1-2

- Updated the bundled GitHub CLI (`gh`) to **2.105.0** (was 2.104.0). It adds `gh event listen` and `gh event subscription`, which wait for pull request events (submitted reviews, state and head changes, merge conflicts, finished check suites) instead of polling. GitHub Event Streams is in preview, so these commands only work once GitHub has given your account access. When `gh` detects that an agent is running it, `gh pr create`, `gh pr view` and `gh api` calls on a pull request now print a hint about `gh event listen` on stderr; their normal output and exit codes are unchanged.
- Bundled Paseo **0.16.1** is unchanged. Pi is not in the image: when it is selected in `providers` (the default), the add-on installs it on start at its latest stable release, like the other npm agents (Pi **1.5.2** when this version was released).

## 0.16.1-1

- Bundled Paseo **0.16.1** (was 0.16.0), a bug-fix release. Claude in Bypass mode now shows a permission card when a `permissions.ask` rule or a hook asks for one, instead of approving the action. Claude sessions no longer fail until `/login` when Paseo refreshes the model list while Claude Code renews its token. Pi model names that contain `/` are shown in full, and an OpenCode question can be answered again after you steer the turn.
- Updated the bundled `ha` CLI to **6.0.0** (was 5.7.0). `ha` now always talks to the Supervisor directly over plain HTTP or its API socket: it ignores `HTTP_PROXY` and similar variables (also when they are set in `env_vars`), refuses `https://` endpoints and does not follow redirects. Its optional settings file is read only from `~/.homeassistant.yaml`, `.yml` or `.json`. The `ha` commands agents use are unchanged (the bundled Home Assistant guidance now describes `ha apps` and its deprecated `ha addons` alias without naming a CLI version), and there is nothing to do after updating.
- Pi is not in the image: when it is selected in `providers` (the default), the add-on installs it on start at its latest stable release, like the other npm agents (Pi **1.5.2** when this version was released).

## 0.16.0-1

- Bundled Paseo **0.16.0** (was 0.15.4). New in Paseo: background tasks you can see and stop above the composer (Claude Code, Codex, OpenCode), a built-in plugin gallery, command center tabs, undo for archiving a workspace, a Change base picker for worktree diffs, background agents and faster diff loading, plus many fixes for Claude, Codex, OpenCode, Pi and ACP agents. If you also use the Paseo desktop or mobile app, update it too to get the new features.
- New agent provider **fx** (`fx`, Vercel Labs' open-source coding agent). Select it in `providers`: the add-on installs it with its vendor's installer (`https://fx.sh/setup.sh`) into `/data/agents/bin/fx` and enables it in Paseo, so there is no need to add it from Paseo's provider catalog. Sign in with `fx login` in a Paseo terminal, or put `AI_GATEWAY_API_KEY` in `env_vars`. Like Muse Code and Antigravity, it updates itself and gets no Home Assistant skill or MCP tools from the add-on yet.
- Fixed: selecting `muse` (Muse Code) or `antigravity` never installed them. The add-on downloaded their vendor installer with options curl does not accept, so every start logged `curl: option --fetch-retries=1: is unknown` and left the provider disabled. They now install on the first start after this update. The ingress adapter needed no change, and there is nothing else to do after updating.
- Pi is not in the image: when it is selected in `providers` (the default), the add-on installs it on start at its latest stable release, like the other npm agents (Pi **1.5.2** when this version was released).

## 0.15.4-2

- Updated the bundled `ha` CLI to **5.7.0** (was 5.6.0) and GitHub CLI (`gh`) to **2.104.0** (was 2.103.3). `ha` commands run with `--raw-json` now exit with an error code when the Supervisor reports an error (they used to exit 0). On a Supervisor that gives each add-on its own API socket, `ha` talks to it over that socket instead of with the token, with the same permissions. `gh auth status` now shows rate-limit, server and network errors.
- `gh repo delete` now asks for an extra confirmation, even with `--yes`, when deleting a private or internal repository would also delete its forks. An agent that deletes such a repository without a prompt must add `--accept-cascading-deletion-of-private-forks`. There is nothing to do after updating.
- Bundled Paseo **0.15.4** is unchanged. Pi is not in the image: when it is selected in `providers` (the default), the add-on installs it on start at its latest stable release, like the other npm agents (Pi **1.5.2** when this version was released).

## 0.15.4-1

- Bundled Paseo **0.15.4** (was 0.15.3). New in Paseo: the Claude Fable 5.2 and Mythos 5.2 models, with medium effort by default. Both need Claude Code 2.1.321 or newer, and Mythos 5.2 only shows up when your Claude account has access to it.
- When `claude` is selected in `providers`, the add-on installs the latest stable Claude Code on every start (2.1.322 when this version was released), so the restart after this update normally brings a new enough version. If the npm registry could not be reached or the upgrade was rolled back, the previous version stays installed and the new models do not appear: check the `Providers: claude <version>` line in the add-on log and restart once the registry is reachable. The ingress adapter needed no change.
- Pi is not in the image: when it is selected in `providers` (the default), the add-on installs it on start at its latest stable release, like the other npm agents (Pi **1.5.1** when this version was released).

## 0.15.3-1

- Bundled Paseo **0.15.3** (was 0.15.2). Fixed in Paseo: conversation text no longer turns blurry when the keyboard opens or closes on iOS 26 and later.
- The ingress adapter needed no change, and there is nothing to do after updating.
- Pi is not in the image: when it is selected in `providers` (the default), the add-on installs it on start at its latest stable release, like the other npm agents (Pi **1.5.0** when this version was released).

## 0.15.2-1

- Bundled Paseo **0.15.2** (was 0.15.0). New in Paseo: a first-run setup that walks you through theme, providers, projects, agent orchestration and the mobile app (Settings, General, Show setup again reopens it), project suggestions from the folders where you ran Claude Code, Codex, OpenCode or Pi, and a theme picker with previews. The daemon now starts without terminals, instead of not at all, when its terminal worker cannot start.
- The ingress adapter needed no change, and there is nothing to do after updating.
- Pi is not in the image: when it is selected in `providers` (the default), the add-on installs it on start at its latest stable release, like the other npm agents (Pi **1.5.0** when this version was released).

## 0.15.0-1

- Bundled Paseo **0.15.0** (was 0.14.0). New in Paseo: terminal programs keep running when the daemon restarts or crashes, an opt-in Resume agents after restart setting (Host settings, Agents) that continues interrupted agents in their conversations, a host setting to turn off usage checks, and copying files listed in `.worktreeinclude` into new worktrees. It also fixes rewinding Claude conversations and Pi tool-result images going missing.
- The image now includes procps (full `ps`, `top`, `free`, `pgrep`): Paseo 0.15.0 needs it to start its terminal worker. The ingress adapter needed no change, and there is nothing to do after updating. Restarting or updating the add-on still closes terminals, because the whole container restarts. Paseo 0.15.0 saves the new agent-resume and usage settings in its `config.json`, so to go back to an older add-on version, restore the backup Home Assistant made before this update.
- Bundled Paseo **0.15.0** and Pi **1.5.0** (Pi and the other npm agents still follow their latest stable release).

## 0.14.0-1

- Bundled Paseo **0.14.0** (was 0.13.2). New in Paseo: Chat display settings that group tool calls or collapse completed turns, a choice of Enter or Ctrl/Cmd+Enter to send, recalling sent messages with Up and Down, downloadable local speech models in Voice settings, and plugins that can give tools to specific agents. Idle agents now free their runtime after an hour and resume on the next prompt. It also fixes terminal glyph corruption and background Git fetches opening credential prompts.
- The ingress adapter needed no change, and the `dictation`, `voice_mode` and `speech_provider` options work as before. Paseo 0.14.0 saves speech and idle-cleanup settings in a new format, so to go back to an older add-on version, restore the backup Home Assistant made before this update.
- Bundled Paseo **0.14.0** and Pi **1.4.0** (Pi and the other npm agents still follow their latest stable release).

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
