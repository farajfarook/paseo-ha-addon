# Worked recipes

`HA` below is `curl -sS -H "Authorization: Bearer $SUPERVISOR_TOKEN" -H "Content-Type: application/json"`.

## Add an automation (e.g. "turn on the porch light at sunset")

1. Find the real entity: `HA http://supervisor/core/api/states | jq -r '.[] | select(.entity_id|startswith("light.")) | "\(.entity_id)\t\(.attributes.friendly_name)"'`.
   If several match, ask the user which one.
2. Snapshot: if `/homeassistant/.git` exists, commit pending changes
   (`git -C /homeassistant add -A && git -C /homeassistant commit -m "Before: porch light automation"`; skip if clean).
3. Check where automations live: `grep -n "automation" /homeassistant/configuration.yaml`
   (usually `automation: !include automations.yaml`). If `automations.yaml` is `[]`, replace it with a list.
4. Append (keep the list style and indentation; `id` must be unique, e.g. a timestamp):
   ```yaml
   - id: "1717171717171"
     alias: Porch light at sunset
     description: Turn on the porch light at sunset
     triggers:
       - trigger: sun
         event: sunset
         offset: "00:00:00"
     conditions: []
     actions:
       - action: light.turn_on
         target:
           entity_id: light.porch
     mode: single
   ```
   (Older cores, before 2024.10, use `trigger:`/`platform:`/`action:`/`service:` keys; match what the
   file already uses. Check the version in `/homeassistant/.HA_VERSION`.)
5. Check: `HA -X POST http://supervisor/core/api/config/core/check_config` → `"result":"valid"`.
6. Reload: `HA -X POST -d '{}' http://supervisor/core/api/services/automation/reload`.
7. Verify: `HA http://supervisor/core/api/states | jq '.[] | select(.attributes.id=="1717171717171") | {entity_id, state}'`
   shows `state: "on"`, and `ha core logs | tail -n 50` has no new errors about it.
8. Commit: `git -C /homeassistant commit -am "Add automation: porch light at sunset"` (if using git).

## Add a template sensor

In `configuration.yaml` (or a package):

```yaml
template:
  - sensor:
      - name: "Average indoor temperature"
        unique_id: average_indoor_temperature
        unit_of_measurement: "°C"
        device_class: temperature
        state: >
          {{ [states('sensor.living_temp'), states('sensor.bedroom_temp')]
             | map('float', 0) | average | round(1) }}
```

Test the template first with `POST /api/template`, then check config, `template/reload`, and
read `/api/states/sensor.average_indoor_temperature`.

## Use a secret

```yaml
# configuration.yaml
some_integration:
  api_key: !secret some_integration_api_key
```

Tell the user to add `some_integration_api_key: <value>` to `secrets.yaml` themselves, or ask them
for the value and append only that key. Never read back or display existing values.

## Roll back

- With git: `git -C /homeassistant log --oneline -5`, then `git -C /homeassistant revert --no-edit <commit>`
  (or `git checkout -- <file>` for uncommitted edits), check config, reload.
- Without git: restore your saved copy of the file (always `cp file file.bak-paseo` before editing
  when there is no git), check config, reload, then delete the `.bak-paseo` copy.
- Dashboards: save the JSON you fetched before the change back with `lovelace/config/save`.

## Rename entities / assign areas

```sh
paseo-ha-ws '{"type":"config/entity_registry/update","entity_id":"sensor.temp_1","new_entity_id":"sensor.office_temperature","name":"Office temperature"}'
```

Renaming an entity id breaks automations, scripts and dashboards that use the old id: search
first (`grep -rn "sensor.temp_1" /homeassistant --include=*.yaml`) and update them too.

## Edit another add-on's config (e.g. Zigbee2MQTT)

1. `ha addons` to find the slug; the folder is `/addon_configs/<slug>/`.
2. Ask the user, copy the file aside, edit, then `ha addons restart <slug>` (ask) and
   `ha addons logs <slug> | tail -n 100` to verify.
