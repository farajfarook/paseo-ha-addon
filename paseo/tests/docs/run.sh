#!/usr/bin/env bash
# ==============================================================================
# Documentation checks for the add-on (task 7.1 / 7.3). No Docker needed.
#
#   1. every key in paseo/config.yaml `schema:` has a row in the DOCS.md options
#      table, a name and a description in translations/en.yaml, and no option
#      default is undocumented;
#   2. every `map:` type resolves to the path DOCS.md documents;
#   3. DOCS.md contains the sections the spec requires (install, options,
#      security/trust model, known limitations, ...);
#   4. CHANGELOG.md names a version that equals paseo/config.yaml `version`.
#
# Usage: run.sh            (run from anywhere; paths are resolved from the file)
# Exit:  0 all checks pass, 1 otherwise.
# ==============================================================================
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADDON_DIR="$(cd "${HERE}/../.." && pwd)"
CONFIG="${ADDON_DIR}/config.yaml"
DOCS="${ADDON_DIR}/DOCS.md"
CHANGELOG="${ADDON_DIR}/CHANGELOG.md"
TRANSLATIONS="${ADDON_DIR}/translations/en.yaml"

FAILED=0
ok()   { echo "[docs] PASS: $*"; }
bad()  { echo "[docs] FAIL: $*" >&2; FAILED=1; }

for f in "${CONFIG}" "${DOCS}" "${CHANGELOG}" "${TRANSLATIONS}"; do
  [[ -f "${f}" ]] || { echo "[docs] missing file: ${f}" >&2; exit 1; }
done

# --- helper: read the one-key-per-line list under a top-level yaml block ------
# The add-on manifests here are written in a flat style, so awk is enough and
# keeps this test dependency-free (no yq/python-yaml in the CI image).
keys_under() { # keys_under <file> <top-level-key>
  awk -v key="$1" '
    $0 ~ "^"key":" { inblock = 1; next }
    inblock && /^[^ \t-]/ { inblock = 0 }
    inblock && /^[ \t]+[A-Za-z_][A-Za-z0-9_]*:/ {
      line = $0; sub(/^[ \t]+/, "", line); sub(/:.*/, "", line); print line
    }' "${2}" | grep -v -E '^(name|description|url|version)$' || true
}

schema_keys() { awk '/^schema:/{f=1;next} f && /^[^ \t]/{f=0} f && /^  [a-z_]+:/{sub(/^  /,"");sub(/:.*/,"");print}' "${CONFIG}"; }
map_types()   { awk '/^map:/{f=1;next} f && /^[^ \t-]/{f=0} f && /type:/{sub(/.*type: /,"");print}' "${CONFIG}"; }
version_of()  { awk '/^version:/{gsub(/["\047]/,"",$2); print $2; exit}' "${CONFIG}"; }

# --- 1. options are documented, translated and tabulated ----------------------
OPTION_DEFAULTS="$(awk '/^options:/{f=1;next} f && /^[^ \t]/{f=0} f && /^  [a-z_]+:/{sub(/^  /,"");sub(/:.*/,"");print}' "${CONFIG}")"
MISSING=""
for key in $(schema_keys); do
  grep -qE "^\| *\`${key}\` *\|" "${DOCS}" || MISSING="${MISSING} ${key}(no DOCS row)"
  grep -qE "^  ${key}:\$" "${TRANSLATIONS}" || MISSING="${MISSING} ${key}(no translation)"
done
for key in ${OPTION_DEFAULTS}; do
  grep -qE "\`${key}\`" "${DOCS}" || MISSING="${MISSING} ${key}(default not mentioned)"
done
if [[ -n "${MISSING}" ]]; then
  bad "documentation gaps:${MISSING}"
else
  ok "all $(schema_keys | wc -l) schema options have a DOCS row and a translation; all declared defaults are mentioned"
fi

# a translation entry without a schema key is a stale option name
STALE=""
for key in $(keys_under configuration "${TRANSLATIONS}"); do
  schema_keys | grep -qx "${key}" || STALE="${STALE} ${key}"
done
if [[ -n "${STALE}" ]]; then bad "translations/en.yaml has entries for unknown options:${STALE}"
else ok "translations/en.yaml matches the schema"; fi

# --- 2. mapped folders are documented ----------------------------------------
MISSING_MAP=""
while read -r type; do
  case "${type}" in
    homeassistant_config) path=/homeassistant ;;
    all_addon_configs)    path=/addon_configs ;;
    addon_config)         path=/config ;;
    share)                path=/share ;;
    ssl)                  path=/ssl ;;
    media)                path=/media ;;
    backup)               path=/backup ;;
    *)                    path="${type}" ;;
  esac
  grep -q "\`${path}\`" "${DOCS}" || MISSING_MAP="${MISSING_MAP} ${type}->${path}"
done < <(map_types)
if [[ -n "${MISSING_MAP}" ]]; then bad "mapped folders not documented:${MISSING_MAP}"
else ok "every config.yaml map: type is documented with its container path"; fi

# --- 3. required sections -----------------------------------------------------
MISSING_SECTIONS=""
for heading in \
  "## Installation" \
  "## Options reference" \
  "## Which settings live where" \
  "## Folders and storage" \
  "## Editable agent configuration" \
  "## Home Assistant MCP tools" \
  "## Security and trust model" \
  "## Supported architectures" \
  "## Known limitations"; do
  grep -qF "${heading}" "${DOCS}" || MISSING_SECTIONS="${MISSING_SECTIONS} ${heading}"
done
[[ -n "${MISSING_SECTIONS}" ]] && bad "DOCS.md missing sections:${MISSING_SECTIONS}" || ok "DOCS.md has all required sections"

# the security section must name the permissions it grants
for claim in "root" "read-write" "manager" "password" "security rating"; do
  grep -qiE "${claim}" "${DOCS}" || bad "DOCS.md never mentions '${claim}' (required by the trust-model requirement)"
done
[[ "${FAILED}" -eq 0 ]] && ok "security/trust model covers root, read-write mounts, the Supervisor role, the direct-port password and the rating"

# --- 4. changelog names the current version ----------------------------------
VERSION="$(version_of)"
BUILD_PIN="$(awk '/^ *PASEO_VERSION:/{print $2; exit}' "${ADDON_DIR}/build.yaml")"
if grep -qE "^## ${VERSION//./\\.}\$" "${CHANGELOG}"; then
  ok "CHANGELOG.md has an entry for version ${VERSION}"
else
  bad "CHANGELOG.md has no '## ${VERSION}' entry"
fi
if grep -qF "**${BUILD_PIN}**" "${CHANGELOG}"; then
  ok "CHANGELOG.md names the bundled Paseo ${BUILD_PIN}"
else
  bad "the CHANGELOG entry for ${VERSION} must name the bundled Paseo (${BUILD_PIN}) version"
fi

# --- 5. the pins agree between build.yaml, Dockerfile and config.yaml --------
DOCKER_PIN="$(awk '/^ARG PASEO_VERSION=/{sub(/^ARG PASEO_VERSION=/,"");print;exit}' "${ADDON_DIR}/Dockerfile")"
if [[ -n "${BUILD_PIN}" && "${BUILD_PIN}" == "${DOCKER_PIN}" ]]; then
  ok "PASEO_VERSION matches build.yaml and Dockerfile (${BUILD_PIN})"
else
  bad "PASEO_VERSION differs: build.yaml=${BUILD_PIN:-?} Dockerfile=${DOCKER_PIN:-?}"
fi
if [[ "${VERSION}" == "${BUILD_PIN}-"* ]]; then
  ok "add-on version ${VERSION} starts with the pinned Paseo ${BUILD_PIN}"
else
  bad "add-on version ${VERSION} does not start with the pinned Paseo ${BUILD_PIN}"
fi

if [[ "${FAILED}" -ne 0 ]]; then
  echo "[docs] FAILED"
  exit 1
fi
echo "[docs] all documentation checks passed"
