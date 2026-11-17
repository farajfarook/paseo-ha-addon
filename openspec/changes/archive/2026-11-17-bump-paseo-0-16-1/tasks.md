# Tasks

## 1. Bump
- [x] 1.1 Pin Paseo 0.16.1 in paseo/build.yaml and both ARG lines of paseo/Dockerfile, and HA CLI 6.0.0 in paseo/build.yaml and its ARG line; add-on version 0.16.1-1; CHANGELOG entry (Paseo **0.16.1**, `ha` 6.0.0 changes, Pi **1.5.2**)
- [x] 1.2 paseo-anchors.sh --check and check-providers.sh pass for 0.16.1; --diff unchanged; `npm pack` diffs of `@getpaseo/{server,cli,protocol,relay,plugin,client}` reviewed; `ha` CLI 6.0.0 release notes reviewed against how the add-on uses `ha`

## 2. Verification
- [x] 2.1 docs test, shellcheck, YAML parse
- [x] 2.2 docker build (runs `ha help`); quick start healthy with the terminal worker launched; smoke, direct-port and providers suites pass
- [x] 2.3 agent-config suite passes
- [x] 2.4 Manual check of `ha` 6.0.0 in the built image against a mock Supervisor (not part of the committed suites): TCP with `SUPERVISOR_TOKEN`, a non-zero exit for an error result with and without `--raw-json`, the Unix socket named by `SUPERVISOR_SOCKET` without a token, and no TCP fallback when that socket is missing
