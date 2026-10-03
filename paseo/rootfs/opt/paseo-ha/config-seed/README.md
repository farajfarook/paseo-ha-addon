# Paseo agent configuration

This folder is the Paseo add-on's own configuration folder. In File Editor or Samba it
shows up as `addon_configs/<id>_paseo`. Inside the add-on it is mounted at `/config`.
Everything here is shared by the coding agents that Paseo runs. Changes take effect
when the add-on restarts.

Do **not** put passwords, API keys or tokens here. Add them as `env_vars` in the
add-on configuration instead. Agent logins, sessions and Paseo's own state stay in the
add-on's private storage (`/data`), which is not visible here.

| Path | Used by | What goes here |
|---|---|---|
| `AGENTS.md` | all agents | Your shared instructions. They are added to the bundled Home Assistant guidance in every agent's global instructions. |
| `skills/<name>/SKILL.md` | Pi, Claude Code, Codex, OpenCode | Your [Agent Skills](https://agentskills.io). Each skill is a folder with a `SKILL.md`. If a skill has the same name as a bundled one (e.g. `home-assistant`), your copy wins. |
| `claude/agents/` | Claude Code | Sub-agent definitions (`*.md`). |
| `claude/commands/` | Claude Code | Custom slash commands (`*.md`). |
| `opencode/agents/` | OpenCode | Agent definitions (`*.md`). |
| `opencode/plugins/` | OpenCode | Plugins (`*.js`/`*.ts`). |
| `pi/extensions/` | Pi | Single-file extensions. |
| `pi/prompts/` | Pi | Prompt templates (`*.md`). |
| `codex/prompts/` | Codex | Custom prompts (`*.md`). |

## Pi packages

Packages from <https://pi.dev/packages> are not managed with files here. Run `pi list`, `pi install npm:<package>` and `pi remove npm:<package>` in a Paseo terminal. Your changes persist across restarts and updates, and a default package you remove stays removed.

## Customising the bundled Home Assistant skill

The add-on ships a `home-assistant` skill that add-on updates keep current. To change
it, copy it into `skills/home-assistant/` from a Paseo terminal:

```sh
cp -r /opt/paseo-ha/skills/home-assistant /config/skills/
```

Then edit your copy. Delete the folder to go back to the bundled version.

The add-on never overwrites files in this folder. If you delete a file or folder, the
default is recreated on the next start.
