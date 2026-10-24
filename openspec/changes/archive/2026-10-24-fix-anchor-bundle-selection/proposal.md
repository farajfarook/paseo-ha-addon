## Why

Paseo 0.13.0 ships two files that match `web-ui/_expo/static/js/web/index-*.js`: the 23.6 MB entry bundle that `index.html` loads (`index-b635bff8….js`) and a new 45 KB lazy chunk with a ZXing barcode-detector polyfill (`index-3c0448b1….js`). The lazy chunk sorts first, and both CI scripts take the first glob match (`ls … index-*.js | head -n1`), so they read the wrong file:

- `paseo-anchors.sh --check 0.13.0` reports every `bundle:` anchor as 0 (`"/_expo/` literals, `paseo.bearer.`, `"@paseo:daemon-registry"`, `"paseo:last-workspace-route-selection"`, `/h/<serverId>` routes, `Connection resolved to`) and fails.
- `check-providers.sh 0.13.0` fails with "provider definitions not found".

Nothing moved upstream: with the entry bundle, every anchor is present and the provider list is unchanged. `lint.yaml` runs both scripts for the pinned release, so the 0.13.0 bump cannot pass CI without this fix. Reported in #31.

## What Changes

- `.github/scripts/paseo-anchors.sh` and `.github/scripts/check-providers.sh` take the bundle from the `<script src="/_expo/static/js/web/index-<hash>.js">` tag in `web-ui/index.html` instead of globbing `index-*.js`. Both fail loudly when `index.html` references no entry bundle or the referenced file is missing (`paseo-anchors.sh` reports a missing protocol `daemon-endpoints.js` as its own error).

Tooling only: no shipped file changes, so this change needs no version bump of its own (it ships in the same PR as the 0.13.0 bump).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. No spec describes how the CI scripts locate the bundle; the add-on's behaviour does not change (`skip_specs`).

## Impact

- `.github/scripts/paseo-anchors.sh`, `.github/scripts/check-providers.sh` (CI `lint.yaml` "Documentation and pins" job, README "Bumping Paseo", release runs).
