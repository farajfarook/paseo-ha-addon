# Tasks

## 1. Fix
- [x] 1.1 paseo/tests/ingress/run.sh: git mode 755
- [x] 1.2 paseo/tests/ingress/run.sh: resolve playwright-core from PLAYWRIGHT_DIR via NODE_PATH (Windows: native path, ';')
- [x] 1.3 paseo/tests/ingress/run.sh: INGRESS_BROWSER override and Linux browser candidates (system Chrome/Chromium/Edge, Playwright Chromium, Brave) in findExecutable(); log the chosen browser
- [x] 1.4 paseo/tests/ingress/run.sh: navigation check opens Settings from the sidebar when present and requires a changed path under the prefix; deep-link reload of that page

## 2. Verification
- [x] 2.1 bash -n and shellcheck -S warning pass
- [x] 2.2 The ingress suite runs all browser checks (navigation and deep-link reload included) on Debian and passes against the 0.13.0 image
