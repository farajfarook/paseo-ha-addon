#!/usr/bin/env bash
# Release guard: fail unless <tag> (minus a leading "v", "refs/tags/" allowed)
# equals the add-on `version` in paseo/config.yaml. On success prints the
# version and, under GitHub Actions, writes `version=<v>` to $GITHUB_OUTPUT.
#
# Usage: check-version.sh <tag> [config.yaml]
set -euo pipefail

tag="${1:-}"
config="${2:-$(dirname "$0")/../../paseo/config.yaml}"

if [[ -z "${tag}" ]]; then
  echo "usage: $0 <tag> [config.yaml]" >&2
  exit 2
fi
if [[ ! -f "${config}" ]]; then
  echo "error: ${config} not found" >&2
  exit 2
fi

tag="${tag#refs/tags/}"
want="${tag#v}"
have="$(awk '/^version:/ { sub(/^version:[ \t]*/, ""); sub(/[ \t]+#.*$/, ""); gsub(/["\047]/, ""); sub(/[ \t\r]+$/, ""); print; exit }' "${config}")"

if [[ -z "${have}" ]]; then
  echo "error: no top-level version in ${config}" >&2
  exit 1
fi
if [[ "${want}" != "${have}" ]]; then
  echo "error: tag '${tag}' (version '${want}') does not match ${config} version '${have}'" >&2
  [[ -n "${GITHUB_ACTIONS:-}" ]] && echo "::error::Tag ${tag} does not match paseo/config.yaml version ${have}; no images will be published"
  exit 1
fi

echo "${have}"
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "version=${have}" >> "${GITHUB_OUTPUT}"
fi
