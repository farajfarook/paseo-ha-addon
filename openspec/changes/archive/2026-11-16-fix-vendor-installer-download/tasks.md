# Tasks

## 1. Fix
- [x] 1.1 Reproduce on the built image: with `providers: [pi, fx]` the start log shows `curl: option --fetch-retries=1: is unknown` and fx stays disabled
- [x] 1.2 `20-providers.sh` `install_script`: replace the npm-only `--fetch-retries`/`--fetch-timeout` with `--retry 1 --connect-timeout 30 --max-time 110`, with a comment; shellcheck and `bash -n`

## 2. Tests
- [x] 2.1 `paseo/tests/providers/run.sh`: a `file://` stub URL goes through the curl download (installed, stamped, enabled, no "is unknown" in the log); an undownloadable installer is logged, leaves nothing behind, stays disabled and is retried
- [x] 2.2 Negative check: the hook with the old options fails the `file://` case; with the fix it passes
- [x] 2.3 Providers suite passes on the built image; live start with `providers: [pi, fx]` downloads the real fx installer from `https://fx.sh/setup.sh`
