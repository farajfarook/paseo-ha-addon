#!/usr/bin/env bash
# Checks that the `providers` option in paseo/config.yaml lists exactly the agent
# providers of the pinned Paseo release (design: configurable-agent-providers D1,
# extended by add-paseo-plugin-providers D4).
#
# "Exactly" means, for the pinned release, the union of
#   1. its built-in providers - the `id:` of every AGENT_PROVIDER_DEFINITIONS entry
#      in the web UI bundle, and
#   2. the providers its bundled plugins register - the `id:` of every
#      `*-provider` plugin under dist/server/builtin-plugins (Muse Code and
#      Antigravity are shipped this way).
# Both are registered through the same agents.providers.<id>.enabled override, so
# the add-on offers both kinds in one option.
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
builtin_ids="$(node -e '
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

# Provider IDs registered by the bundled plugins. Each `*-provider` plugin returns one
# `ProviderRegistration` from its server/provider.ts; its `id:` is the provider ID the
# agent sees, and its `command:` is the CLI. Read the id that sits next to the label in
# that registration, so a plugin for something else (a usage source, say) is ignored.
plugin_dir="${pkg}/dist/server/builtin-plugins"
plugin_ids=""
if [[ -d "${plugin_dir}" ]]; then
  for provider_pkg in "${plugin_dir}"/*-provider; do
    [[ -d "${provider_pkg}" ]] || continue
    registration="${provider_pkg}/server/provider.ts"
    [[ -f "${registration}" ]] || continue
    plugin_ids+="$(sed -n 's/^ *id: "\([a-z0-9-]*\)",$/\1/p' "${registration}" | head -n1)"$'\n'
  done
fi
plugin_ids="$(printf '%s' "${plugin_ids}" | grep -v '^$' | sort -u || true)"

# A layout change upstream must fail loudly: silently comparing against the built-ins
# alone would accept a schema that is missing a provider.
plugin_count="$(grep -c . <<<"${plugin_ids}" || true)"
if [[ "${plugin_count}" -eq 0 ]]; then
  echo "ERROR: no plugin providers found under ${plugin_dir}" >&2
  echo "The pinned Paseo ${ver} is expected to register providers from bundled plugins" >&2
  echo "(at least muse and antigravity). If upstream changed the plugin layout, update the" >&2
  echo "plugin-provider extraction in $0." >&2
  exit 1
fi

paseo_ids="$(printf '%s\n%s\n' "${builtin_ids}" "${plugin_ids}" | grep -v '^$' | sort -u)"

# Provider IDs in the add-on schema: list(a|b|c) under schema.providers.
schema_ids="$(awk '/^schema:/{s=1;next} s&&/^[^ \t]/{s=0} s&&/^  providers:/{p=1;next} p&&/^    - list\(/{sub(/^    - list\(/,"");sub(/\)$/,"");gsub(/\|/,"\n");print;exit}' "${config}" | sort)"

echo "Paseo ${ver} built-in providers:    $(paste -sd' ' <<<"${builtin_ids}")"
echo "Paseo ${ver} plugin providers:      $(paste -sd' ' <<<"${plugin_ids}")"
echo "add-on schema providers:            $(paste -sd' ' <<<"${schema_ids}")"
if [[ -z "${paseo_ids}" || "${paseo_ids}" != "${schema_ids}" ]]; then
  echo "ERROR: the providers option in ${config} does not match Paseo ${ver}'s providers" >&2
  exit 1
fi
echo "providers option matches Paseo ${ver}"
