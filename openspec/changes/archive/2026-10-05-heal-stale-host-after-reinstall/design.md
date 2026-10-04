# Design

## Context

- The daemon's ID comes from `getOrCreateServerId` in `@getpaseo/server`. It reads `$PASEO_HOME/server-id` (`/data/home/.paseo/server-id`) and, when the file is missing, writes a random `srv_<12 base64url chars>`. `PASEO_SERVER_ID` overrides the file. Uninstalling the add-on wipes `/data`, so every reinstall gets a new ID.
- The web app stores its hosts in `localStorage["@paseo:daemon-registry"]`: `[{serverId, connections:[{type:"directTcp", endpoint:"<host>:<port>", useTls}], ...}]`. On boot it calls `bootstrapInitialConnectionHint`, which does nothing when a host already has the hint's endpoint. The host controller then connects. When the daemon reports another ID it throws `Connection resolved to <new>, expected <old>`, unless the stored ID starts with `local:`, and retries forever.
- Under ingress the shim sets the hint to the browser's own `<ha-host>:<port>`. Every install on the same HA shares that endpoint, so the stale entry always matches.
- Other per-host state: `localStorage["paseo:last-workspace-route-selection"]` (`{serverId, workspaceId}`), deep links under `/h/<serverId>/...`, keys such as `@paseo/provider-snapshot/v2:["<serverId>",...]`, and the IndexedDB `paseo-replica-row-store`. The app deletes cached rows of hosts that are no longer registered (`ensureStoredIndex`, `setHosts`).
- Init hooks run in sorted order before the daemon starts. `50-nginx.sh` renders the nginx config through `render.js`.
- HA keeps its instance UUID in `/homeassistant/.storage/core.uuid` (`{"data":{"uuid":"<hex>"}}`). The add-on maps it read-write and only reads it. The add-on's hostname (`<repo-hash>-<slug>`, e.g. `b498db88-paseo`) is the same after a reinstall.

## Goals / Non-Goals

**Goals:**
- A reinstall on the same HA keeps the daemon's ID when the HA instance UUID is readable, so clients don't see a change.
- When the ID did change (installs from before this change, a restored older backup, a deleted `/data`, no UUID), the sidebar panel recovers by itself on the next open.

**Non-Goals:**
- Healing Paseo desktop or mobile apps that connect over the direct port or relay. The stable ID prevents the problem for them on reinstall, but a changed ID still needs the user to remove the host.
- Moving session history from the old ID to the new one. A wiped `/data` has no old sessions to show.
- Changing Paseo itself.

## Decisions

### D1: Write `server-id` from a hook; don't set `PASEO_SERVER_ID`
`10-server-id.sh` runs before every other hook. If `$PASEO_HOME/server-id` holds a non-empty line, it does nothing. Otherwise it writes the derived ID to the file (mode 600, atomic rename), and the daemon picks it up through its normal file read.
- An environment override would win over an existing file and change the ID of every current install. Writing the file only when it's missing keeps existing IDs (spec: "Existing installation").
- Users can still override with `PASEO_SERVER_ID` in `env_vars`, which Paseo already honours.

### D2: Derive from the HA UUID and the add-on hostname
`srv_` + the first 12 base64url characters of `sha256("paseo-ha:server-id:v1:" + uuid + ":" + hostname)`. This is Paseo's own shape (12 chars), and its 72 bits keep it hard to guess. The hostname tells a second copy of the add-on (another repository or slug) on the same HA apart. The UUID makes it differ between HA instances. Hashing keeps the UUID itself out of the ID, which clients and the relay see.
- Without a readable, well-formed UUID the hook writes a random ID of the same shape. This matches what the daemon would do, and the file keeps it stable from then on.
- The alternative of storing the ID outside `/data` (for example in `/addon_configs` or `/share`) was rejected. Those folders can also be wiped, and they would put add-on state into user-visible folders.

### D3: Hand the live ID to the shim through the nginx-rendered tag
`render.js` substitutes a `@SERVER_ID@` token in the template's shim tag: `<script src="…/paseo-ha/shim.js" data-paseo-server-id="srv_…">`. `50-nginx.sh` reads the ID from `$PASEO_HOME/server-id` (or `PASEO_SERVER_ID` when set) and passes it as `PASEO_HA_SERVER_ID`. `render.js` accepts it only if it matches `^[A-Za-z0-9_:-]{1,128}$` and renders an empty value otherwise. The shim treats an empty value as "unknown" and skips the heal.
- The alternative of the shim fetching `/api/status` was rejected. It would need a synchronous XHR before the deferred bundle runs, which is deprecated and adds latency on every open. The tag is free, and the HTML is served `no-store`.
- `shim.js` stays static and `no-store`.

### D4: Heal in the shim before the bundle runs
After computing the hint (`host`, e.g. `hass.faraj.au:443`) and before the router reads the path, the shim:
1. Parses `@paseo:daemon-registry`. Stale hosts are those whose `serverId` differs from the live ID, doesn't start with `local:`, and that have a `directTcp` connection whose `endpoint` equals `host` (case-insensitive). It writes the list back without them. The app then probes the hint and adds the live daemon again. Hosts on other endpoints are untouched.
2. Removes `paseo:last-workspace-route-selection` when its `serverId` is stale.
3. Removes `localStorage` keys that start with `@paseo` or `paseo` and contain a stale ID (provider snapshots, migration markers).
4. If the app-relative path is `/h/<staleId>` or starts with `/h/<staleId>/`, replaces it with `/` before the router reads it.
5. Logs one `console.info` line with how many hosts were removed.
The app removes the stale IndexedDB rows itself once the host is gone, so the shim doesn't touch IndexedDB (that is async, and the timing doesn't allow it).
Every step runs in a `try` block. Any parse failure leaves storage as it is.

## Risks / Trade-offs

- [Paseo storage keys and route shape change in a later release] → The keys and `/h/` are read defensively, so a change makes the heal a no-op rather than a breakage. Add them to the "Bumping Paseo" anchor checks and to the ingress browser test.
- [Two Paseo add-ons on one HA share the ingress endpoint] → Each panel removes the other's entry when it opens, so each panel works but reconnects from scratch each time you switch. Today the second panel can't connect at all, so this is better. Documented as a limitation.
- [A predictable ID] → The ID depends on the HA UUID, which isn't public, and on a 72-bit hash. Relay sessions are still authenticated by the daemon key pair, so knowing an ID doesn't grant access.
- [Server ID reused after a reinstall, but with a new daemon key pair] → Paired relay clients see the same ID with a different key and must pair again. Before this change they had to pair again anyway.

## Migration Plan

Nothing to do. Existing installs keep their current ID (D1). A browser that last saw an older ID heals the next time the panel opens (D4). Rollback: an older add-on version still reads the same `server-id` file.
