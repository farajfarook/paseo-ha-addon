# Tasks

## 1. Bump
- [x] 1.1 Pin Paseo 0.12.0 in paseo/build.yaml and both ARG lines of paseo/Dockerfile; HA CLI 5.6.0 and gh 2.103.0; add-on version 0.12.0-1; CHANGELOG entry
- [x] 1.2 paseo-anchors.sh --check and check-providers.sh pass for 0.12.0; the one --diff change (useTls 2 → 3, default port in injectConnectionHint) reviewed against shim.js and nginx

## 2. Verification
- [x] 2.1 docs test, shellcheck, YAML parse
- [x] 2.2 docker build; smoke, direct-port and providers suites pass
- [x] 2.3 agent-config suite passes
