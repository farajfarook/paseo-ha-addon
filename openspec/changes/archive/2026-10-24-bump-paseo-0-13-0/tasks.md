# Tasks

## 1. Bump
- [x] 1.1 Pin Paseo 0.13.0 in paseo/build.yaml and both ARG lines of paseo/Dockerfile; gh 2.103.2; add-on version 0.13.0-1; CHANGELOG entry
- [x] 1.2 paseo-anchors.sh --check and check-providers.sh pass for 0.13.0; both --diff changes (index.html "/_expo/ 2 → 3, bundle "/_expo/ 1 → 2) reviewed against shim.js and nginx

## 2. Verification
- [x] 2.1 docs test, shellcheck, YAML parse
- [x] 2.2 docker build; smoke, direct-port and providers suites pass
- [x] 2.3 agent-config suite passes
- [x] 2.4 ingress browser suite passes (an anchor count moved)
