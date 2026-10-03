#!/usr/bin/env bash
# Checks that the `providers` option in paseo/config.yaml lists exactly the built-in
# agent providers of the pinned Paseo release (design: configurable-agent-providers D1).
#
# Usage: check-providers.sh <paseo-version> [config.yaml] [server-package-dir]
#   With a server-package-dir (an extracted @getpaseo/server) nothing is downloaded.
set -euo pipefail

ver="${1:-}"
config="${2:-paseo/config.yaml}"
pkg="${3:-}"
[[ -n "${ver}" ]] || { echo "usage: $0 <paseo-version> [config.yaml] [server-package-dir]" >&2; exit 2; }

if [[ -z "${pkg}" ]]; then
  work="$(mktemp -d)"; trap 'rm -rf "${work}"' EXIT
  ( cd "${work}" && npm pack --silent "@getpaseo/server@${ver}" >/dev/null )
  tar -xzf "${work}/getpaseo-server-${ver}.tgz" -C "${work}"
  pkg="${work}/package"
fi

# Provider IDs shipped by Paseo: the `id:` of every AGENT_PROVIDER_DEFINITIONS entry.
# The definitions live in the web UI bundle (shared with the server); take the array
# between AGENT_PROVIDER_DEFINITIONS' `l=[` and the dev-only `d=[` list.
bundle="$(ls "${pkg}"/dist/server/web-ui/_expo/static/js/web/index-*.js | head -n1)"
paseo_ids="$(node -e '
  const s = require("fs").readFileSync(process.argv[1], "utf8");
  const start = s.indexOf("AGENT_PROVIDER_DEFINITIONS\",{enumerable");
  const arr = s.indexOf("l=[{id:", start);
  const end = s.indexOf(",d=[{id:", arr);
  if (start < 0 || arr < 0 || end < 0) { console.error("provider definitions not found"); process.exit(1); }
  // Provider entries carry defaultModeId; mode entries (id/label/description/icon) do not.
  const re = /\{id:"([a-z0-9-]+)",label:"[^"]*",description:"(?:[^"\\]|\\.)*",(?:enabledByDefault:![01],)?defaultModeId:/g;
  const ids = [...s.slice(arr, end).matchAll(re)].map(m => m[1]);
  console.log(ids.sort().join("\n"));
' "${bundle}")"

# Provider IDs in the add-on schema: list(a|b|c) under schema.providers.
schema_ids="$(awk '/^schema:/{s=1;next} s&&/^[^ \t]/{s=0} s&&/^  providers:/{p=1;next} p&&/^    - list\(/{sub(/^    - list\(/,"");sub(/\)$/,"");gsub(/\|/,"\n");print;exit}' "${config}" | sort)"

echo "Paseo ${ver} providers: $(paste -sd' ' <<<"${paseo_ids}")"
echo "add-on schema providers: $(paste -sd' ' <<<"${schema_ids}")"
if [[ -z "${paseo_ids}" || "${paseo_ids}" != "${schema_ids}" ]]; then
  echo "ERROR: the providers option in ${config} does not match Paseo ${ver}'s providers" >&2
  exit 1
fi
echo "providers option matches Paseo ${ver}"
