# Design

## Context

- Pi 1.0.0 is baked into the image (`/opt/node`, design D7 of `add-paseo-ha-addon`). `PI_CODING_AGENT_DIR=/data/home/.pi/agent`, which is persistent, private, in backups and survives image updates (D6).
- `pi install <source>` writes the source to `<agentDir>/settings.json` → `packages` and installs it:
  - npm sources go to `<agentDir>/npm`.
  - git sources go under the agent dir.

  `pi remove` deletes both the entry and the files. Everything lives in `/data`, so Pi's own state already persists across restarts and updates.
- Pi reinstalls any package listed in `settings.json` but missing on disk the next time it resolves resources (`DefaultPackageManager.resolvePackageSources`, unless `PI_OFFLINE`). This repairs a partly lost install.
- Add-on updates pull a new GHCR image (`ghcr.io/farajfarook/{arch}-addon-paseo:<version>`). The container filesystem is replaced, but `/data` and `/config` are kept. Anything written outside `/data` or `/config` at runtime is lost, and anything in the image is replaced.
- Init hooks in `/etc/paseo-ha/init.d/*.sh` run in lexical order before the daemon starts. They are non-fatal and have the daemon env (`HOME`, `PI_CODING_AGENT_DIR`) loaded. `20-agents.sh` is the precedent for npm installs into `/data` with a stamp file.

## Goals / Non-Goals

**Goals:**
- Pi's `settings.json` stays the only record of what is installed, so `pi install` and `pi remove` work exactly as Pi documents.
- Maintainer defaults are offered once per installation, by package identity.
- Startup is never blocked, and the network is only used when there is a new default to offer.

**Non-Goals:**
- No editable package list in `/config` and no add-on option. The user rejected these: Pi's commands already persist, and a second list would conflict with them.
- No automatic upgrades of installed packages. Users run `pi update --extensions` when they want them.
- No project-scope (`.pi/settings.json`) packages. No per-resource filters for defaults. Users can still narrow resources with `pi config`.
- No baking package files into the image.

## Decisions

### D1. Install at runtime into `/data`, not baked into the image
Defaults are installed by `pi install` on start into the persistent agent dir.
- **Why:** if packages were baked into the image (for example `/opt/pi-packages`, referenced as local paths), every image update would replace them. A user's removal would then have to be re-applied with filters against an image path, and their installs would live in a different place from the defaults. A runtime install puts defaults and user packages in one place, managed by one tool.
- **Cost:** the first start after a release that adds defaults needs network access and takes longer. This is acceptable because `20-agents.sh` already depends on npm at runtime, and failures are retried (D4).
- **Alternative rejected:** a hybrid where defaults are baked in and the user's opt-outs are written as `-path` filters. It is complex, it is invisible to `pi list` users, and it breaks Pi's identity rules.

### D2. Offer-once ledger keyed by package identity
`/data/paseo-ha/pi-packages.offered` holds one identity per line:
- npm: `npm:<name>` with the version removed (scoped names keep their leading `@`).
- git: `git:<host>/<path>` with the ref removed and a `https://` URL normalised the same way.

This matches the identity Pi itself uses (packages.md, "Understand scope and identity"). On start the hook computes each default's identity:
- **Identity already in the ledger:** skip it. This covers both "the user removed it" and "it is installed".
- **Identity not in the ledger, but `pi list` (or `settings.json` `packages`) already has a source with the same identity:** the user installed it themselves. Record it as offered without reinstalling.
- **Otherwise:** run `pi install <source>`. On success, add the identity to the ledger.

`/data` is in HA backups, so a restore brings back the ledger together with Pi's settings. The two stay consistent.
- **Alternative rejected:** mark defaults inside `settings.json`. Pi owns that file and could drop unknown fields. The ledger keeps add-on state separate.
- **Alternative rejected:** reconcile against the default list on every start. That would undo the user's `pi remove`, which is the bug the user wants to avoid.

### D3. Hook placement and invocation
- New hook `36-pi-packages.sh`. It runs after `30-agent-config.sh`, which links `pi/extensions` and `pi/prompts` into the agent dir, and before the daemon starts, so the first Pi session already sees the packages.
- It runs `pi install` with the daemon env, so packages go to the persistent agent dir.
- It sets `PI_SKIP_VERSION_CHECK=1` and installation telemetry off for these calls only.
- Each install runs under `timeout` (about 300 s) so a stuck registry cannot hang startup.
- Default list file: `/opt/paseo-ha/pi-packages.default`. It holds one Pi source per line; blank lines and `#` comments are ignored. The maintainer pins versions (for example `npm:pi-foo@1.2.3`) for reproducible installs.
- An empty or missing list file means nothing to offer, and the hook only logs `pi list`.

### D3a. Initial default list
The first release ships these five packages, pinned to the versions the maintainer runs today:

```
npm:@juicesharp/rpiv-todo@2.12.0
npm:@juicesharp/rpiv-ask-user-question@2.12.0
npm:pi-subagents@0.75.0
npm:pi-provider-litellm@3.3.0
npm:pi-web-access@0.35.0
```

- `rpiv-todo`, `rpiv-ask-user-question` and `pi-subagents` are the Pi extensions Paseo 0.10.3 knows how to display (`@getpaseo/server` `providers/pi/extensions/registry.js`): the todo list panel, structured question dialogs and sub-agent activity. Pi 1.0.0 has no built-in todo or question tool, so without these Paseo shows neither for Pi agents.
- `pi-provider-litellm` lets Pi use models through a LiteLLM proxy. It does nothing until it is configured: either `/login litellm` in a Paseo terminal (the credential is saved under `/data`), or `LITELLM_BASE_URL` plus `LITELLM_API_KEY` added through the `env_vars` option.
- `pi-web-access` adds web search and page fetching. Search works without any key (Exa MCP, DuckDuckGo). Provider API keys go in `env_vars` or in `/data/home/.pi/agent/web-search.json`. Its YouTube and local-video features need `yt-dlp`/`ffmpeg`, which the image does not include; those features stay unavailable and nothing else is affected.
- `pi-mcp-adapter` is deliberately left out. It would replace Pi's built-in MCP support, which already serves the Home Assistant MCP server (`mcp.json`, D13a).

### D4. Failure handling
- On a failed install, the hook logs a warning with the source and the last lines of output, then moves on to the next default.
- The failed default is not added to the ledger, so it is retried on the next start.
- The hook always exits 0 (init hooks are non-fatal anyway).
- If `PI_OFFLINE` is set in the env (users can set it through `env_vars`), installs are skipped with an info log and nothing is recorded.

### D5. Visibility
At the end of the hook, it logs `Pi packages: <sources>` from `pi list` (one line).
The docs explain:
- how to manage packages from a Paseo terminal (`pi install`, `pi remove`, `pi list`, `pi config`, `pi update --extensions`);
- that removed defaults do not come back;
- how to get a default back (`pi install <source>`).

## Risks / Trade-offs

- [The first start after a release with a new default is slower or needs network] → One install per new default with a timeout, retried on later starts, and logged.
- [A default package breaks Pi (a bad extension)] → The maintainer pins versions in the list. Users can `pi remove` it, or switch it off with `pi config`. The removal sticks (D2).
- [The user deletes `/data/paseo-ha/pi-packages.offered`] → Defaults the user removed come back once. This is documented as the way to "reset to defaults".
- [A user `pi install`s a default under a different source form (npm vs git) before the add-on offers it] → Identities differ, so both could end up installed. This is unlikely, and Pi's identity dedup does not cover it. Documented and accepted.
- [Pi package install runs code (npm lifecycle scripts)] → This is the same trust model as `pi install` itself. Defaults are maintainer-reviewed and pinned.
- [Pi version bump changes install layout or CLI] → The agent-config test exercises `pi install`/`pi list` and runs on every bump.

## Migration Plan

- Existing installations have no ledger, so on the first start after the update every default is offered once.
- A user who already installed a default gets a ledger entry without a reinstall (D2).
- Rollback: an older image ignores the ledger. Installed packages stay in Pi's settings and keep working, and users remove them with `pi remove`.
