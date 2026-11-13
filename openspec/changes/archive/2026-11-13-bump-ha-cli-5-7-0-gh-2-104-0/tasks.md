# Tasks

## 1. Bump
- [x] 1.1 Pin HA CLI 5.7.0 and gh 2.104.0 in paseo/build.yaml and their ARG lines in paseo/Dockerfile; add-on version 0.15.4-2; CHANGELOG entry (Paseo **0.15.4** unchanged, Pi **1.5.2**)
- [x] 1.2 paseo-anchors.sh --check and check-providers.sh pass for the unchanged Paseo 0.15.4; HA CLI 5.7.0 and gh 2.104.0 release notes reviewed against how the add-on uses `ha` and `gh`

## 2. Verification
- [x] 2.1 docs test, shellcheck, YAML parse
- [x] 2.2 docker build (runs `ha help` and `gh --version`); smoke, direct-port and providers suites pass
- [x] 2.3 agent-config suite passes (includes "gh version matches the pin" and gh as git's credential helper)
- [x] 2.4 Manual check of `ha` 5.7.0 in the built image against a mock Supervisor (not part of the committed suites): TCP with `SUPERVISOR_TOKEN`, the Unix socket named by `SUPERVISOR_SOCKET` without a token, and a non-zero exit for an error result with `--raw-json`
