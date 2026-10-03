#!/usr/bin/env bash
# Print the paseo/CHANGELOG.md section for <version> (the lines under
# "## <version>", up to the next "## " heading) on stdout. Fails if missing.
#
# Usage: release-notes.sh <version|tag> [CHANGELOG.md]
set -euo pipefail

ver="${1:-}"
file="${2:-$(dirname "$0")/../../paseo/CHANGELOG.md}"
[[ -n "${ver}" ]] || { echo "usage: $0 <version> [CHANGELOG.md]" >&2; exit 2; }
[[ -f "${file}" ]] || { echo "error: ${file} not found" >&2; exit 2; }
ver="${ver#refs/tags/}"; ver="${ver#v}"

notes="$(awk -v v="${ver}" '
  /^## / { if (on) exit; on = ($2 == v); next }
  on { print }
' "${file}" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')"

if [[ -z "${notes//[[:space:]]/}" ]]; then
  echo "error: no non-empty '## ${ver}' section in ${file}" >&2
  exit 1
fi
printf '%s\n' "${notes}"
