# Tasks

## 1. Bump
- [x] 1.1 Pin Paseo 0.15.4 in paseo/build.yaml and both ARG lines of paseo/Dockerfile; add-on version 0.15.4-1; CHANGELOG entry
- [x] 1.2 paseo-anchors.sh --check and check-providers.sh pass for 0.15.4; --diff unchanged

## 2. Verification
- [x] 2.1 docs test, shellcheck, YAML parse
- [x] 2.2 docker build; smoke, direct-port and providers suites pass
- [x] 2.3 agent-config suite passes
- [x] 2.4 ingress browser suite passes against the 0.15.4 web UI bundle
