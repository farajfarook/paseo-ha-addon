## Why

The ingress browser suite (`paseo/tests/ingress/run.sh`) could not run on the Linux release host, and part of it no longer ran anywhere:

- The file is not executable in git (mode 644, unlike every other suite's `run.sh`), so `paseo/tests/ingress/run.sh <image>` fails with "Permission denied".
- It documents `PLAYWRIGHT_DIR` but never uses it. `node` resolves `playwright-core` only from the working directory's `node_modules` tree, so with playwright-core in the documented `../browsertest` the suite logs "playwright-core not found" and skips every browser check.
- `findExecutable()` only knows Windows Edge/Chrome paths, so on Linux it fails with "no Edge/Chrome executable found" even when Chrome, Chromium, Brave or Playwright's own Chromium is installed.
- The navigation and deep-link reload checks look for `nav a, nav button, [role=tablist] [role=tab], aside button`. The current Paseo sidebar uses aria-labelled buttons outside `nav`/`aside`, so with 0.13.0 the suite logs "no nav elements found; navigation/reload checks skipped" and never checks them.

The Paseo 0.13.0 bump moves an ingress anchor count (a new lazy chunk path in the bundle), so its release run needs this suite.

## What Changes

- `paseo/tests/ingress/run.sh` becomes executable (git mode 755), like the other suites.
- Put `${PLAYWRIGHT_DIR}/node_modules` on `NODE_PATH` (native path and `;` separator on Windows), so playwright-core is found where the usage text says.
- `findExecutable()`: honour a new `INGRESS_BROWSER` override, keep the Windows candidates, then try `/usr/bin/google-chrome`, `chromium`, `chromium-browser`, `microsoft-edge`, Playwright's downloaded Chromium (`~/.cache/ms-playwright/chromium-<rev>/chrome-linux64/chrome` or `chrome-linux/chrome`, newest first) and `/usr/bin/brave-browser`. Log the browser it uses.
- Navigation check: click the sidebar's `Settings` button (`aria-label="Settings"`) when present and require that the path changed and stayed under the ingress prefix; the deep-link reload check then reloads that page as before. Without a Settings button the old generic selectors are used, as before.

Test-only. No shipped file changes, so no version bump of its own.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. The add-on's behaviour does not change; only how the test finds its tools and its navigation target (`skip_specs`).

## Impact

- `paseo/tests/ingress/run.sh` (local release runs; CI does not run this suite).
