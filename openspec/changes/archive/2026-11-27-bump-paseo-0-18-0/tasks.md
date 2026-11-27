# Tasks

## 1. Bump
- [x] 1.1 Pin Paseo 0.18.0 in paseo/build.yaml and both ARG lines of paseo/Dockerfile; add-on version 0.18.0-1; CHANGELOG entry
- [x] 1.2 paseo-anchors.sh --check and check-providers.sh pass for 0.18.0; --diff unchanged

## 2. Verification
- [x] 2.1 docs test, shellcheck, YAML parse
- [x] 2.2 docker build; smoke, direct-port and providers suites pass
- [x] 2.3 agent-config suite passes
- [x] 2.4 Built image started with `providers: [pi, antigravity]`: the vendor installer gives Antigravity CLI 1.5.1 or later (Paseo 0.18.0's minimum) and Paseo lists the provider
