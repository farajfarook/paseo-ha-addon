# Proposal

## Why

After an add-on is uninstalled and installed again, the sidebar panel stays on "Reconnecting to host" and shows old sessions, never the new ones. Uninstalling wipes `/data`, so the daemon creates a new random server ID (`$PASEO_HOME/server-id`). The Paseo web app keeps its host list in browser storage under the old ID. It refuses a daemon that answers with a different ID ("Connection resolved to X, expected Y") and retries forever. Users have to remove the host by hand or clear site data. Paseo apps connected over the direct port hit the same problem.

## What Changes

- **The daemon keeps its server ID across reinstalls.** Before the daemon starts, the add-on makes sure `$PASEO_HOME/server-id` exists. On a fresh `/data` it writes an ID derived from the Home Assistant instance UUID (`/homeassistant/.storage/core.uuid`) and the add-on's hostname. When the UUID is readable, the same add-on on the same Home Assistant gets the same ID after a reinstall. An existing `server-id` file is never changed. Without a readable UUID, the add-on writes a random ID in Paseo's format. That ID survives restarts and updates but not a reinstall, and the panel heal covers that case.
- **The panel heals a stale host on its own.** nginx renders the daemon's server ID into the shim `<script>` tag. Before the app boots, the shim removes browser host entries for the panel's own endpoint that carry a different server ID. It also clears the remembered last workspace when that workspace belongs to a removed host, sends a deep link into a removed host to the app root, and drops `@paseo`/`paseo` keys named after a removed host. The app then adds the current daemon again from its connection hint and deletes cached rows of hosts that are no longer registered. This also covers restores from backup, a deleted `/data`, and installs made before this change.
- Tests: the smoke test checks that the shim tag carries the live server ID and checks how the hook derives, keeps and generates IDs. The ingress browser test seeds a stale host and checks that the panel heals.
- Docs, CHANGELOG and version bump (`0.10.3-9`).

## Capabilities

### New Capabilities
<!-- None. -->

### Modified Capabilities
- `agent-runtime`: new requirement that the daemon's identity stays the same across restarts and reinstalls.
- `ingress-web-ui`: new requirement that the panel reconnects on its own when the daemon's identity has changed since the browser last saw it.

## Impact

- New hook `paseo/rootfs/etc/paseo-ha/init.d/10-server-id.sh`.
- `paseo/rootfs/opt/paseo-ha/nginx/paseo.conf.tpl` and `render.js`: a server ID token in the shim tag. `paseo/rootfs/etc/paseo-ha/init.d/50-nginx.sh` passes it through.
- `paseo/rootfs/opt/paseo-ha/www/shim.js`: stale-host heal before boot.
- `paseo/tests/smoke/run.sh`, `paseo/tests/ingress/run.sh`.
- `paseo/DOCS.md`, `paseo/CHANGELOG.md`, `paseo/config.yaml` (version).
- Reads `/homeassistant/.storage/core.uuid` (read only). The add-on already maps `homeassistant_config`.
- The ingress adapter depends on two more Paseo internals: the `@paseo:daemon-registry` and `paseo:last-workspace-route-selection` storage keys and the `/h/<serverId>/` route shape. A Paseo bump must recheck them, like the existing anchors.
