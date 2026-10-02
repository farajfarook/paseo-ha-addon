# `ha` CLI recipes

The `ha` command talks to the Supervisor with `$SUPERVISOR_TOKEN` (role: `manager`). Add
`--raw-json` for JSON output (`ha core info --raw-json | jq .data`).

## Core

```sh
ha core info                 # version, state, port, ...
ha core check                # validate the configuration (same as check_config)
ha core logs | tail -n 200   # recent Core log
ha core restart              # ASK THE USER FIRST. Restarts Core only; this Paseo session keeps running.
```

After a restart, Core takes a while to come back. Poll until it answers, then check logs:

```sh
until curl -fs -H "Authorization: Bearer $SUPERVISOR_TOKEN" http://supervisor/core/api/ >/dev/null; do sleep 5; done
ha core logs | tail -n 100
```

Never use `ha core stop`, `ha host reboot|shutdown` or `ha os ...` unless the user explicitly asks.

## Backups

```sh
ha backups                                          # list
ha backups new --name "before <task>"               # full backup (can take minutes; ask first)
ha backups new --help                               # partial backups (selected add-ons/folders)
```

Never restore a backup without the user's explicit request.

## Add-ons

```sh
ha addons                     # installed add-ons with slugs and states
ha addons info <slug>         # details, options, version
ha addons logs <slug> | tail -n 100
ha addons restart <slug>      # ASK FIRST (e.g. after editing /addon_configs/<slug>)
```

Do not install, uninstall, update, start, stop or change options of add-ons unless asked.

## Supervisor / system

```sh
ha supervisor info
ha supervisor logs | tail -n 100
ha info
ha resolution info            # issues/suggestions reported by the Supervisor
```

`ha --help` and `ha <command> --help` list everything else.
