# Tasks

## 1. Bump
- [x] 1.1 Pin Paseo 0.16.0 in paseo/build.yaml and both ARG lines of paseo/Dockerfile; add-on version 0.16.0-1; CHANGELOG entry
- [x] 1.2 paseo-anchors.sh --check and check-providers.sh pass for 0.16.0 (with the `add-fx-provider` option); --diff unchanged; web-ui.js and index.html hunks reviewed against shim.js/nginx

## 2. Verification
- [x] 2.1 docs test, shellcheck, YAML parse
- [x] 2.2 docker build; quick start healthy (terminal worker launched); smoke, direct-port and providers suites pass
- [x] 2.3 agent-config suite passes
- [x] 2.4 ingress browser suite passes against the 0.16.0 web UI bundle
