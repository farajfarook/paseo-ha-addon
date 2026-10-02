#!/usr/bin/env bash
# Print build settings for one arch from paseo/build.yaml, which stays the
# single source of truth even though home-assistant/builder's build-image
# action no longer reads it.
#
# Usage:
#   build-args.sh <arch> [build.yaml]            -> KEY=VALUE build args, one per line
#                                                    (BUILD_FROM, BUILD_ARCH, every `args:` entry)
#   build-args.sh --labels [build.yaml]          -> key=value labels from `labels:`
#
# Only the flat two-level layout used by paseo/build.yaml is supported.
set -euo pipefail

mode="${1:-}"
file="${2:-$(dirname "$0")/../../paseo/build.yaml}"

if [[ -z "${mode}" ]]; then
  echo "usage: $0 <arch>|--labels [build.yaml]" >&2
  exit 2
fi
if [[ ! -f "${file}" ]]; then
  echo "error: ${file} not found" >&2
  exit 2
fi

# section <name> -> "key=value" lines of a top-level mapping.
section() {
  awk -v want="$1" '
    { sub(/\r$/, "") }
    /^[^ \t#][^:]*:/ { split($0, a, ":"); cur = a[1]; next }
    cur == want && /^[ \t]+[^ \t#][^:]*:/ {
      line = $0
      sub(/^[ \t]+/, "", line)
      i = index(line, ":")
      key = substr(line, 1, i - 1)
      val = substr(line, i + 1)
      sub(/^[ \t]+/, "", val); sub(/[ \t]+#.*$/, "", val); sub(/[ \t]+$/, "", val)
      if (val ~ /^".*"$/ || val ~ /^\047.*\047$/) val = substr(val, 2, length(val) - 2)
      print key "=" val
    }
  ' "${file}"
}

if [[ "${mode}" == "--labels" ]]; then
  section labels
  exit 0
fi

arch="${mode}"
from="$(section build_from | awk -F= -v a="${arch}" '$1 == a { sub(/^[^=]*=/, ""); print; exit }')"
if [[ -z "${from}" ]]; then
  echo "error: no build_from entry for arch '${arch}' in ${file}" >&2
  exit 1
fi
echo "BUILD_FROM=${from}"
echo "BUILD_ARCH=${arch}"
section args
