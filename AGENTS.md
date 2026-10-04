# AGENTS.md

Guidance for coding agents and reviewers (including CodeRabbit) working in this
repository. These rules are the single source of truth: `.coderabbit.yaml`
points its review guidelines and pre-merge checks at this file.

## Repository

Home Assistant add-on repository for [Paseo](https://paseo.sh), a self-hosted
daemon and web UI for coding agents, opened from the HA sidebar through Ingress.

| Path | What it is |
|---|---|
| `repository.yaml` | HA add-on repository manifest |
| `paseo/config.yaml` | Add-on manifest: `version`, options `schema`, defaults |
| `paseo/build.yaml`, `paseo/Dockerfile` | Image build; pins `PASEO_VERSION`, `PI_VERSION`, `HA_CLI_VERSION` |
| `paseo/rootfs/` | Files shipped in the image (init scripts in `etc/paseo-ha/init.d/`, nginx ingress adapter and shim in `opt/paseo-ha/`) |
| `paseo/translations/en.yaml` | Option names and descriptions shown in the HA UI |
| `paseo/DOCS.md`, `paseo/README.md`, `paseo/CHANGELOG.md` | User documentation and release notes |
| `paseo/tests/` | Test suites (`docs`, `smoke`, `direct-port`, `providers`, `agent-config`, `ingress`) |
| `.github/workflows/`, `.github/scripts/` | CI: lint, build, tag, publish |
| `openspec/` | OpenSpec specs (`specs/`) and changes (`changes/`, `changes/archive/`) |
| `.pi/` | OpenSpec skills and prompts (`/opsx-propose`, `/opsx-apply`, `/opsx-archive`, ...) |

Note: `paseo/rootfs/opt/paseo-ha/AGENTS.base.md` is the guidance shipped to
agents running *inside* Home Assistant. It is product code, not guidance for
this repository.

## Rule 1: every code change goes through OpenSpec

The project is spec-driven (`openspec/config.yaml`: `schema: spec-driven`).

**Exempt files** (no OpenSpec change needed): anything under `openspec/`,
`AGENTS.md`, `.coderabbit.yaml`, `.github/CODEOWNERS`, `LICENSE`, `.gitignore`,
`.gitattributes`, the root `README.md`, and `.pi/`.

**Every other changed file is code**, including `paseo/**` (and its DOCS.md),
`.github/workflows/**`, `.github/scripts/**` and `repository.yaml`. A PR that
changes code must:

1. Contain an OpenSpec change with `proposal.md` and `tasks.md` (and
   `design.md` when the change needs design decisions). Create it with
   `/opsx-propose`, then implement with `/opsx-apply`.
2. Cover every changed code file with a task in `tasks.md` or with the
   proposal/design scope.
3. Tick every task (`- [x]`). A task may stay unticked only if its text says
   it is deferred to another named OpenSpec change.
4. Include spec deltas under `specs/<capability>/spec.md` when behaviour
   changes, in OpenSpec format: `## ADDED|MODIFIED|REMOVED Requirements`, and
   each requirement has at least one `#### Scenario`.

## Rule 2: the change is archived in the same PR

Before merging, archive the implemented change with `/opsx-archive`:

1. The change moves to `openspec/changes/archive/YYYY-MM-DD-<name>/`. It must not
   remain in `openspec/changes/<name>/`.
2. Its spec deltas are applied to `openspec/specs/<capability>/spec.md`
   (ADDED/MODIFIED requirements present, REMOVED ones gone).
3. All of its tasks are ticked, except tasks explicitly deferred to another
   named change.

Changes that are not yet implemented may stay in `openspec/changes/`.

## Rule 3: bump the version when shipped files change, and only then

Users receive a change only when `version` in `paseo/config.yaml` changes.
Merging a version bump to `main` *is* the release (`tag.yaml` tags it and
`publish.yaml` builds the images).

**Shipped files** are everything under `paseo/` **except** `paseo/tests/**`,
`paseo/CHANGELOG.md`, `paseo/DOCS.md`, `paseo/README.md` and
`paseo/translations/**` (the same list as the `version-bump` job in
`.github/workflows/lint.yaml`).

- **A shipped file changed:** bump `version` in `paseo/config.yaml` (compared
  with the base branch) and add a matching `## <version>` entry at the top of
  `paseo/CHANGELOG.md`.
- **Only documentation, tests, translations, OpenSpec, CI or repo metadata
  changed:** do **not** bump the version. A needless bump publishes a release
  that contains no change.
- **Version format** is `<paseo>-<rev>`: the pinned Paseo release plus an add-on
  revision. A normal change increments `<rev>` (`0.10.3-6` → `0.10.3-7`).
  Bumping `PASEO_VERSION` resets it (`0.10.3-7` → `0.10.4-1`), and the
  `<paseo>` part must equal `PASEO_VERSION` in `paseo/build.yaml`.
- The new version must be higher than the base branch version. There is one
  bump per PR.
- The changelog entry describes the user-visible change. It must name the
  bundled Paseo and Pi versions in bold (for example "Bundled Paseo **0.10.3**
  and Pi **1.0.0** are unchanged."). `paseo/tests/docs/run.sh` enforces this.

## Other conventions

- **Options:** every key in `schema:` in `paseo/config.yaml` needs a row in the
  DOCS.md options table and a name and description in
  `paseo/translations/en.yaml`.
- **Pins:** `PASEO_VERSION` must agree in `paseo/build.yaml` and
  `paseo/Dockerfile`. Before raising it, follow "Bumping Paseo" in `README.md`
  (check the ingress anchors with `.github/scripts/paseo-anchors.sh`).
- **Shell:** use bash with `set -euo pipefail`. Scripts must pass `bash -n` and
  `shellcheck`. Init scripts must be idempotent and log failures without
  blocking startup.
- **Secrets:** never commit them. Read tokens from the environment or the
  Supervisor.
- **Docs:** write plain English in short sentences. Document user-visible
  behaviour in `paseo/DOCS.md`.

## Checks to run before opening a PR

```bash
bash paseo/tests/docs/run.sh                       # options, translations, changelog/version, pins
shellcheck paseo/rootfs/etc/paseo-ha/init.d/*.sh .github/scripts/*.sh
# with Docker (CI runs these on every PR):
docker build -t paseo-smoke:ci paseo
paseo/tests/smoke/run.sh paseo-smoke:ci
```
