## Why

No vendor-installed provider (Muse Code, Antigravity, and now fx) can be installed on a real add-on. `install_script` in `paseo/rootfs/etc/paseo-ha/init.d/20-providers.sh` downloads the vendor's installer with

```
curl -fsSL --fetch-retries=1 --fetch-timeout=60000 -o <tmp> <url>
```

`--fetch-retries` and `--fetch-timeout` are npm options, not curl options. curl rejects them before it connects, so every download fails and the provider stays disabled, retried (and failing again) on every start. Found while checking the new fx provider live on the 0.16.0 image with `providers: [pi, fx]`:

```
INFO: Installing provider fx from https://fx.sh/setup.sh into /data/agents/bin/fx...
ERROR: Provider fx could not be installed or does not run on x86_64 (it will be disabled and retried on the next start). Last output:
ERROR:   curl: option --fetch-retries=1: is unknown
ERROR:   could not download the installer from https://fx.sh/setup.sh
```

The bug has been there since the script-installer path was added (`add-paseo-plugin-providers`, 0.11.1-1). The providers suite did not catch it because its test seam (`PASEO_HA_TEST_SCRIPT_URL`) hands the hook a local file path, which is copied instead of downloaded, so no test ever ran the curl call. The specified behaviour (`agent-providers`: "Vendor-installed providers" / "Install on selection") was never met; this change makes the add-on meet it.

## What Changes

- `20-providers.sh` `install_script`: use curl's own options, `curl -fsSL --retry 1 --connect-timeout 30 --max-time 110`, inside the existing `timeout -k 5 120` cap, with a comment saying why. Checked in the add-on image (curl 8.23.0): the command downloads `https://fx.sh/setup.sh`, and a missing `file://` source fails with exit 37 ("Could not open file").
- `paseo/tests/providers/run.sh`: two new cases that go through the curl call without network access, by passing the stub installer as a `file://` URL (a URL is not a readable path, so the hook downloads it): the installer is downloaded, curl accepts its options, fx is installed, stamped and enabled; and an installer that cannot be downloaded (`file:///nonexistent/install.sh`) is logged ("could not download the installer from ..."), leaves no directory and no stamp, keeps fx disabled, and is retried on the next start.
- Negative check: the same hook with the old curl options, run in the image with `PASEO_HA_TEST_SCRIPT_URL=file://<stub>`, logs `curl: option --fetch-retries=1: is unknown` and leaves fx disabled; with the fix it logs `Installed provider fx: 0.0.17`.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None (`skip_specs`). The `agent-providers` requirements "Vendor-installed providers" and "Failed installs never block startup" already describe the intended behaviour (install on selection, a download failure logged and retried); the add-on did not meet the first, and this fix restores it without changing any requirement.

## Impact

- `paseo/rootfs/etc/paseo-ha/init.d/20-providers.sh` (shipped; released with the version bump of the `bump-paseo-0-16-0` change in the same PR). Users who selected `muse` or `antigravity` get them installed on the first start of the new version; the CHANGELOG says so.
- `paseo/tests/providers/run.sh` (not shipped).
