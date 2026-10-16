# Tasks

## 1. Bump
- [x] 1.1 Pin Paseo 0.11.4 in paseo/build.yaml and both ARG lines of paseo/Dockerfile; add-on version 0.11.4-1; CHANGELOG entry
- [x] 1.2 paseo-anchors.sh --diff/--check pass for 0.11.4

## 2. Exclude Hoplite
- [x] 2.1 EXCLUDED_PROVIDERS (hoplite) in .github/scripts/check-providers.sh, failing if an excluded provider is in the option, is built in, or no longer requires configuration
- [x] 2.2 check-providers.sh passes for 0.11.4 and 0.11.2, and fails for hoplite in the option and for a hoplite registration without requiresConfiguration
- [x] 2.3 DOCS.md states Hoplite is not offered
- [x] 2.4 providers test asserts the hook writes no hoplite override

## 3. Verification
- [x] 3.1 docs test, shellcheck, YAML parse
- [x] 3.2 docker build; smoke, direct-port and providers suites pass; a running 0.11.4 daemon does not list Hoplite (`paseo provider ls`)
- [x] 3.3 agent-config suite passes
