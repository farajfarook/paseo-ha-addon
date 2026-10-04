# Tasks

## 1. Stable server ID (design D1, D2)

- [x] 1.1 Add `paseo/rootfs/etc/paseo-ha/init.d/10-server-id.sh`: keep an existing non-empty `$PASEO_HOME/server-id`. Otherwise derive `srv_` + 12 base64url chars of `sha256("paseo-ha:server-id:v1:<uuid>:<hostname>")` from `${PASEO_HA_HA_CONFIG_DIR:-/homeassistant}/.storage/core.uuid`, or fall back to a random ID of the same shape. Write it atomically with mode 600 and log which source was used. Verify with `bash -n` and `shellcheck`
- [x] 1.2 Extend `paseo/tests/smoke/run.sh` to check, inside the container, that the hook writes the same ID twice for one UUID and hostname, a different ID for another UUID, a random `srv_` ID without a UUID, and leaves an existing file unchanged. Also check that the running daemon's `/api/status` `serverId` equals `$PASEO_HOME/server-id`. Verify the smoke test passes against the built image

## 2. Panel heal (design D3, D4)

- [x] 2.1 Add a `@SERVER_ID@` token to the shim tag in `paseo/rootfs/opt/paseo-ha/nginx/paseo.conf.tpl` (`data-paseo-server-id`), substitute it in `render.js` from `PASEO_HA_SERVER_ID` with the allow-list check, and pass the ID from `50-nginx.sh` (`PASEO_SERVER_ID`, else the `server-id` file). Verify in the smoke test that `index.html` carries `data-paseo-server-id="<live id>"`, and that the JS bundle still has no injected tag
- [x] 2.2 Implement the heal in `paseo/rootfs/opt/paseo-ha/www/shim.js` before `stripPath()`: drop stale hosts on the panel's endpoint, the stale last-workspace selection, `@paseo`/`paseo` keys naming a stale ID, and a `/h/<staleId>` path. Verify with `node --check` on the file
- [x] 2.3 Extend `paseo/tests/ingress/run.sh`: seed a stale registry entry on the panel endpoint plus an unrelated host on another endpoint, a stale last-workspace selection and a provider-snapshot key, then open `<prefix>/h/<staleId>/workspace/x`. Check that the registry holds the live ID and the unrelated host, that the stale key and selection are gone, that the path does not contain the stale ID, and that the UI does not show "Reconnecting to host". Also check that a second load with a matching ID leaves storage unchanged. Verify the test passes against the built image

## 3. Documentation and release

- [x] 3.1 Document in `paseo/DOCS.md`: the server ID survives reinstalls, the panel heals a stale host, desktop and mobile apps may need the host removed after a restore from an older backup, and two Paseo add-ons on one HA share the panel endpoint (Known limitations). Add the storage keys and `/h/` route to the "Bumping Paseo" checks in `README.md`, and add them, the server-ID rejection and the `server-id` file as anchors in `.github/scripts/paseo-anchors.sh` so the CI `--check` gate covers them. Verify `bash paseo/tests/docs/run.sh` passes
- [x] 3.2 Bump `version` in `paseo/config.yaml` to `0.10.3-9` and add the CHANGELOG entry (Bundled Paseo **0.10.3** unchanged). Verify the docs check passes and `shellcheck paseo/rootfs/etc/paseo-ha/init.d/*.sh .github/scripts/*.sh` is clean

## 4. Integration

- [ ] 4.1 Deferred to `verify-stale-host-real-ha`: on the real HA instance, update the add-on and open the panel in a browser that still remembers the old server ID, then uninstall and reinstall and check the server ID is unchanged and the panel connects at once. Image-level equivalents passed on amd64 (smoke test incl. server-ID derivation, ingress browser test incl. stale-host heal, direct-port and docs tests)
