# Contributing

Thanks for helping. Short version: open an issue first for anything beyond a
typo, keep PRs small, and follow `AGENTS.md`.

## Ways to help without writing code

- Try the add-on and report what broke (use the bug template; include the
  add-on **Log** tab output and your HA / add-on versions).
- Answer questions in [Discussions](https://github.com/farajfarook/paseo-ha-addon/discussions).
- Translate the option names in `paseo/translations/` (copy `en.yaml`).
- Improve `paseo/DOCS.md` where it was unclear to you.

## Code changes

1. Open an issue describing the problem or the provider you want added.
2. Fork, branch from `main`.
3. Read [`AGENTS.md`](AGENTS.md). It is the rulebook CodeRabbit reviews against:
   - every change to `paseo/**`, `.github/**` or `repository.yaml` needs an
     OpenSpec change under `openspec/changes/`, archived in the same PR;
   - bump `version` in `paseo/config.yaml` and add a `paseo/CHANGELOG.md` entry
     **only** when shipped files change (not for docs, tests or translations);
   - bash with `set -euo pipefail`, passes `shellcheck`.
4. Run the checks before opening the PR:

   ```bash
   bash paseo/tests/docs/run.sh
   shellcheck paseo/rootfs/etc/paseo-ha/init.d/*.sh .github/scripts/*.sh
   docker build -t paseo-smoke:ci paseo && paseo/tests/smoke/run.sh paseo-smoke:ci
   ```

5. Open the PR. CI runs lint, build and the smoke test; CodeRabbit reviews.

## Adding or fixing a provider

Providers live in `paseo/rootfs/etc/paseo-ha/init.d/20-providers.sh` and the
`providers` schema in `paseo/config.yaml`. The CI check
`.github/scripts/check-providers.sh` requires the option to match the pinned
Paseo release's providers, so a new provider usually arrives with a Paseo bump
(see "Bumping Paseo" in `README.md`).

## Code of conduct

Be kind and assume good intent. Harassment of any kind is not tolerated;
report it to the maintainer by email (see the GitHub profile).
