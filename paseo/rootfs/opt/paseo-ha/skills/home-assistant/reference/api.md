# Home Assistant Core API recipes

Every request needs `Authorization: Bearer $SUPERVISOR_TOKEN`. The base URL is
`$HASS_SERVER` = `http://supervisor/core` (the Supervisor proxies to Core). Never echo the token.

```sh
HA() { curl -sS -H "Authorization: Bearer $SUPERVISOR_TOKEN" -H "Content-Type: application/json" "$@"; }
HA http://supervisor/core/api/            # {"message":"API running."}
```

## Configuration check

```sh
HA -X POST http://supervisor/core/api/config/core/check_config | jq
# {"result":"valid","errors":null,"warnings":null}
# {"result":"invalid","errors":"Invalid config for 'automation' at automations.yaml, line 12: ..."}
```

Same via the CLI: `ha core check`. Only continue when the result is `valid`.

## Reload per domain

`POST /api/services/<domain>/<service>` with `{}` as body:

| Changed | Call |
|---|---|
| `automations.yaml`, automation blueprints | `automation/reload` |
| `scripts.yaml`, script blueprints | `script/reload` |
| `scenes.yaml` | `scene/reload` |
| `template:` entities | `template/reload` |
| `input_boolean`/`input_number`/`input_select`/`input_text`/`input_datetime`/`input_button` | `<domain>/reload` |
| `group:` | `group/reload` |
| `timer:`, `counter:`, `schedule:`, `zone:`, `person:` | `<domain>/reload` |
| `homeassistant: customize:` / core section | `homeassistant/reload_core_config` |
| themes | `frontend/reload_themes` |
| a whole package or an integration that has a YAML reload | `<domain>/reload` (check Developer tools for which exist) |
| all reloadable YAML at once | `homeassistant/reload_all` |
| config entry (UI integration) | `homeassistant/reload_config_entry` with `{"entry_id": "..."}` |

```sh
HA -X POST -d '{}' http://supervisor/core/api/services/automation/reload
```

If no reload exists for the change (new YAML integration, `custom_components`, `http:`,
`recorder:`, `logger:` defaults…), a Core restart is needed: **ask the user**, then `ha core restart`.

List available services (and so reloads): `HA http://supervisor/core/api/services | jq -r '.[] | .domain as $d | .services | keys[] | "\($d).\(.)"' | grep reload`.

## States

```sh
HA http://supervisor/core/api/states | jq -r '.[].entity_id' | sort               # all entity ids
HA http://supervisor/core/api/states | jq -r '.[] | select(.entity_id|startswith("light.")) | "\(.entity_id)\t\(.state)\t\(.attributes.friendly_name)"'
HA http://supervisor/core/api/states/automation.porch_light_at_sunset | jq     # one entity
```

An automation entity's id comes from its `alias` (slugified), not its `id:`; its
`attributes.id` holds the YAML `id`. Check `last_triggered` after a test.

## Services

```sh
HA -X POST -d '{"entity_id":"light.porch"}' http://supervisor/core/api/services/light/turn_on
HA -X POST -d '{"entity_id":"automation.porch_light_at_sunset"}' http://supervisor/core/api/services/automation/trigger
HA -X POST -d '{"entity_id":"light.porch"}' "http://supervisor/core/api/services/light/turn_on?return_response"   # for services that return data
```

Only act on physical devices when the user asked for it.

## Templates (great for checking entities and logic)

```sh
HA -X POST -d '{"template":"{{ states(\"sun.sun\") }} {{ state_attr(\"sun.sun\",\"next_setting\") }}"}' \
  http://supervisor/core/api/template
HA -X POST -d '{"template":"{{ states.light | map(attribute=\"entity_id\") | list }}"}' http://supervisor/core/api/template
```

## Logs, history, logbook

```sh
HA http://supervisor/core/api/error_log | tail -n 100                 # current Core log (text)
HA "http://supervisor/core/api/history/period?filter_entity_id=light.porch&minimal_response" | jq
HA "http://supervisor/core/api/logbook/$(date -u -d '-1 hour' +%Y-%m-%dT%H:%M:%SZ)" | jq
HA http://supervisor/core/api/config | jq '{version, location_name, time_zone, unit_system, components: (.components|length)}'
```

`ha core logs` gives the same Core log via the Supervisor.

## WebSocket API (registries, dashboards, helpers)

Use the helper `paseo-ha-ws` (already authenticated; prints the result as JSON):

```sh
paseo-ha-ws '{"type":"config/entity_registry/list"}' | jq '.[] | {entity_id, name, area_id, platform}'
paseo-ha-ws '{"type":"config/device_registry/list"}' | jq '.[] | {id, name, area_id, manufacturer, model}'
paseo-ha-ws '{"type":"config/area_registry/list"}'
paseo-ha-ws '{"type":"config/entity_registry/update","entity_id":"light.lamp_1","name":"Desk lamp","area_id":"office"}'
paseo-ha-ws '{"type":"config_entries/get"}' | jq '.[] | {entry_id, domain, title, state}'
```

Dashboards (storage mode):

```sh
paseo-ha-ws '{"type":"lovelace/dashboards/list"}'
paseo-ha-ws '{"type":"lovelace/config","url_path":null}' > /tmp/dashboard.json     # default dashboard
# edit /tmp/dashboard.json, then:
jq -c '{type:"lovelace/config/save", url_path:null, config:.}' /tmp/dashboard.json | paseo-ha-ws
```

Save a copy of the original dashboard JSON before changing it so you can restore it.

UI helpers (`input_boolean`, `input_number`, `timer`, …) created in the UI: `<domain>/list`,
`<domain>/create`, `<domain>/update`, e.g. `paseo-ha-ws '{"type":"input_boolean/create","name":"Guest mode"}'`.

Raw endpoint, if you need something else: `ws://supervisor/core/websocket` (send
`{"type":"auth","access_token":"$SUPERVISOR_TOKEN"}` after `auth_required`, then commands with
increasing `id`).

## Supervisor API

The `ha` CLI wraps it; raw calls also use `$SUPERVISOR_TOKEN`:

```sh
curl -sS -H "Authorization: Bearer $SUPERVISOR_TOKEN" http://supervisor/core/info | jq .data
curl -sS -H "Authorization: Bearer $SUPERVISOR_TOKEN" http://supervisor/addons | jq '.data.addons[] | {slug, name, state}'
```

## MCP

When the user enabled HA's **Model Context Protocol Server** integration, Pi, Claude Code, Codex
and OpenCode get a `homeassistant` MCP server (Assist tools such as `HassTurnOn`, `GetLiveContext`)
for entities exposed to Assist. It cannot edit configuration, so the REST/WebSocket API above is
still the way to change config. If no MCP tools are listed, use the API.
