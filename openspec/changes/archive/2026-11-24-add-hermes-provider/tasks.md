# Tasks

## 1. Investigation
- [x] 1.1 Confirm the cause of the provider-check failure: Paseo 0.17.4 bundles `hermes-provider` (`id: "hermes"`, `command: ["hermes", "acp"]`, `requiresConfiguration: true`), and `check-providers.sh 0.17.4` reports `hermes` as a plugin provider missing from the option
- [x] 1.2 Run Hermes' real installer in the add-on image: it fails in its hash-locked `uv sync` while the base image's `UV_EXTRA_INDEX_URL`/`PIP_EXTRA_INDEX_URL` are set, and installs v0.23.4 with them unset (`--non-interactive --skip-browser --skip-computer-use`); `hermes --version` and an ACP `initialize` work; `hermes update` from v0.23.3 works with the variables set
- [x] 1.3 Check aarch64 coverage without emulation: `pm/lock.json` has `linux-arm64-musl` uv, Python, Node.js, pnpm and ripgrep; every compiled dependency the x86_64 install used has a musllinux aarch64 wheel in `uv.lock`
- [x] 1.4 Find why Paseo lists Hermes as `error` and `session/new` fails (`service_identity_unverified`): Hermes treats any s6 container as its own image unless a gateway is already running; `hermes gateway run --no-supervise --external-supervisor` is its documented foreign-supervisor mode

## 2. Providers hook and option
- [x] 2.1 `20-providers.sh`: add `hermes` to `ALL_PROVIDERS`, `PROVIDER_BIN`, `PROVIDER_KIND` (script), `PROVIDER_BIN_DIR`, `SCRIPT_URL`, `SCRIPT_SHELL`, `SCRIPT_ARGS` (`--dir .../hermes-agent --non-interactive --skip-browser --skip-computer-use`) and `SCRIPT_ENV` (`-u UV_EXTRA_INDEX_URL -u PIP_EXTRA_INDEX_URL`); header comments
- [x] 2.2 `20-providers.sh`: `PROVIDER_CLI_SUBDIR` and `provider_cli_dir` for a CLI inside its provider directory (binary lookup, `--version` PATH, daemon PATH)
- [x] 2.3 `20-providers.sh`: `SCRIPT_TIMEOUT` per script provider (Hermes 1800 s), overridden by `PASEO_HA_PROVIDER_INSTALL_TIMEOUT` when set
- [x] 2.4 s6 longrun `hermes-gateway` (`type`, `run`, `finish`, `dependencies.d/init-paseo`, `user/contents.d/hermes-gateway`): runs `hermes gateway run --no-supervise --external-supervisor --replace -q` while `hermes` is on PATH; exits without restart otherwise; restarts on exit 75, stops on 78
- [x] 2.5 `paseo/config.yaml`: add `hermes` to the `providers` enum and the add-on description
- [x] 2.6 `paseo/translations/en.yaml`: name Hermes in the `providers` description
- [x] 2.7 `.github/scripts/check-providers.sh`: comment names Hermes; the check passes for 0.17.4 and still fails for 0.17.3

## 3. Documentation
- [x] 3.1 `paseo/DOCS.md`: intro, options row, Agent providers section and table, "Which versions are installed" (layout, size, install time and cap, no browser/computer-use tools, gateway and its memory and logs, `hermes update`, what deselection keeps), login steps, first-start note, troubleshooting rows (provider install, gateway configuration error, gateway restart), known limitations (no HA setup for Hermes; backup size)
- [x] 3.2 `paseo/README.md`, root `README.md`, `SECURITY.md`, bug report template: list Hermes (eleven agents), `hermes update`, Hermes among the agents without the HA skill and MCP tools

## 4. Tests
- [x] 4.1 `paseo/tests/providers/run.sh`: stub installer handles Hermes (fresh `--dir`, required flags, HA index variables unset, CLI in `.hermes/bin`, multi-line version); all-provider assertions include hermes; install, stamp, summary, PATH, deselection (checkout removed, `/data/home/.hermes` kept), install time cap
- [x] 4.2 Negative checks: the providers test's Hermes stub fails a hook that keeps the HA index variables or drops `--non-interactive`
- [x] 4.3 `paseo/tests/smoke/run.sh`: check g), no gateway without `hermes` selected
- [x] 4.4 shellcheck and `bash -n` on the hook, the s6 scripts and the tests; providers suite passes on the built image
- [x] 4.5 Live check on the built image with `providers: [pi, hermes]`: the real installer runs through the hook (~2.5 min), the start log names `hermes Hermes Agent v0.23.4 ...`, the gateway service starts, `paseo provider ls` lists Hermes enabled and `available` with its modes, a restart downloads nothing, a `paseo run --provider hermes` turn against a local OpenAI-compatible mock completes (`PONG`), `hermes update` from v0.23.3 hands the gateway back and the service restarts it on v0.23.4, and with `providers: [pi]` the checkout is removed, `/data/home/.hermes` kept and the gateway service stays down
