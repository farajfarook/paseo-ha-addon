# Tasks

## 1. Bump
- [x] 1.1 Pin gh 2.105.0 in paseo/build.yaml and its ARG line in paseo/Dockerfile; add-on version 0.16.1-2; CHANGELOG entry (Paseo **0.16.1** unchanged, Pi **1.5.2**)
- [x] 1.2 paseo-anchors.sh --check and check-providers.sh pass for the unchanged Paseo 0.16.1; gh 2.105.0 release notes reviewed against how the add-on uses `gh`

## 2. Verification
- [x] 2.1 docs test, shellcheck, YAML parse
- [x] 2.2 docker build (runs `gh --version`); smoke, direct-port and providers suites pass
- [x] 2.3 agent-config suite passes (includes "gh version matches the pin" and gh as git's credential helper)
