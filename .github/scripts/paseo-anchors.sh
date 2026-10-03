#!/usr/bin/env bash
# Ingress anchors of a Paseo release.
#
# The ingress adapter (nginx `sub_filter` rules in rootfs/opt/paseo-ha/nginx/
# paseo.conf.tpl, rootfs/opt/paseo-ha/www/shim.js and nginx/render.js) depends on
# internals of the bundled Paseo web UI: root-absolute asset paths, the hard-coded
# "/ws" path, the daemon connection hint and the `paseo.bearer.<token>` WebSocket
# subprotocol. This script prints those facts for one Paseo version, so a version
# bump can be reviewed as a diff of the report instead of by reading a minified
# bundle. See the repository README, section "Bumping Paseo".
#
# Usage:
#   paseo-anchors.sh <server-package-dir> [protocol-package-dir]
#       Print the anchor report. <server-package-dir> is an extracted
#       @getpaseo/server package (the directory that contains `dist/`).
#       [protocol-package-dir] defaults to the @getpaseo/protocol package sitting
#       next to it, as in a real node_modules tree.
#
#   paseo-anchors.sh --diff <old-version> <new-version>
#       Fetch @getpaseo/server and @getpaseo/protocol for both versions from npm
#       and print the diff of their reports. Exits non-zero when an anchor moved.
#
#   paseo-anchors.sh --version <version>
#       Fetch @getpaseo/server + @getpaseo/protocol for <version> from npm and
#       print its report (no comparison). Used by CI for the pinned release.
#
#   paseo-anchors.sh --check <version>
#       Like --version, but fails if any anchor the add-on relies on is missing
#       (count 0). This is the CI gate for the pinned Paseo release.
#
#   paseo-anchors.sh --installed
#       Report the anchors of the globally installed @getpaseo/server.
set -euo pipefail

count() { # count <label> <pattern> <file>
  local n
  n="$(grep -c -E -- "$2" "$3" 2>/dev/null || true)"
  printf '%-52s %s\n' "$1" "${n:-0}"
}

report() { # report <server-package-dir> <protocol-package-dir>
  local s="$1" p="$2" bundle endpoints
  bundle="$(ls "$s"/dist/server/web-ui/_expo/static/js/web/index-*.js 2>/dev/null | head -n 1 || true)"
  endpoints="${p}/dist/daemon-endpoints.js"
  if [[ -z "${bundle}" || ! -f "${endpoints}" ]]; then
    echo "error: unexpected package layout (no web UI bundle or ${endpoints})" >&2
    return 1
  fi

  echo "# anchor counts (0 means the add-on's assumption no longer holds)"
  count 'index.html: "/_expo/ asset URLs'                '"/_expo/'                 "${s}/dist/server/web-ui/index.html"
  count 'index.html: "/manifest.json"'                   '"/manifest\.json"'         "${s}/dist/server/web-ui/index.html"
  count 'index.html: "/favicon.ico"'                     '"/favicon\.ico"'           "${s}/dist/server/web-ui/index.html"
  count 'index.html: "/apple-touch-icon.png"'            '"/apple-touch-icon\.png"'  "${s}/dist/server/web-ui/index.html"
  count 'manifest.json: "start_url": "/"'                '"start_url": *"/"'         "${s}/dist/server/web-ui/manifest.json"
  count 'manifest.json: "/pwa-icon-*.png"'               '"/pwa-icon-'               "${s}/dist/server/web-ui/manifest.json"
  count 'bundle: "/_expo/ string literals'               '"/_expo/'                  "${bundle}"
  count 'server: __PASEO_INITIAL_DAEMON_CONNECTION__'    '__PASEO_INITIAL_DAEMON_CONNECTION__' "${s}/dist/server/server/web-ui.js"
  count 'server: hint injected before </head>'           '</head>'                   "${s}/dist/server/server/web-ui.js"
  count 'server: useTls in the hint'                     'useTls'                    "${s}/dist/server/server/web-ui.js"
  count 'server: "/public/" literal'                     '"/public/'                 "${s}/dist/server/server/web-ui.js"
  count 'server: app.use("/public")'                     'use\("/public'             "${s}/dist/server/server/bootstrap.js"
  count 'server: GET /api/health route'                  'get\("/api/health'         "${s}/dist/server/server/bootstrap.js"
  count 'protocol: buildDaemonWebSocketUrl'              'buildDaemonWebSocketUrl'   "${endpoints}"
  count 'protocol: hard-coded "/ws" path'                '"/ws'                      "${endpoints}"
  count 'bundle: paseo.bearer.<token> subprotocol'       'paseo\.bearer\.'           "${bundle}"

  echo
  echo "# exact root-absolute strings the nginx sub_filter rules prefix"
  grep -h -o -E '"/(_expo/[^"]*|manifest\.json|favicon\.ico|apple-touch-icon\.png|pwa-icon-[^"]*)"' \
    "${s}/dist/server/web-ui/index.html" "${s}/dist/server/web-ui/manifest.json" | sort -u
}

fetch_extract() { # fetch_extract <version> <workdir> -> "<serverdir> <protocoldir>"
  local ver="$1" work="$2"
  ( cd "${work}" \
    && npm pack --silent "@getpaseo/server@${ver}" >/dev/null \
    && npm pack --silent "@getpaseo/protocol@${ver}" >/dev/null )
  mkdir -p "${work}/server-${ver}" "${work}/protocol-${ver}"
  tar -xzf "${work}/getpaseo-server-${ver}.tgz" -C "${work}/server-${ver}"
  tar -xzf "${work}/getpaseo-protocol-${ver}.tgz" -C "${work}/protocol-${ver}"
  printf '%s %s\n' "${work}/server-${ver}/package" "${work}/protocol-${ver}/package"
}

strip_hashes() { sed -E 's/index-[0-9a-f]{32}\.js/index-<hash>.js/g'; }

case "${1:-}" in
  --diff)
    old="${2:-}"; new="${3:-}"
    [[ -n "${old}" && -n "${new}" ]] || { echo "usage: $0 --diff <old-version> <new-version>" >&2; exit 2; }
    work="$(mktemp -d)"; trap 'rm -rf "${work}"' EXIT
    read -r old_s old_p <<<"$(fetch_extract "${old}" "${work}")"
    read -r new_s new_p <<<"$(fetch_extract "${new}" "${work}")"
    report "${old_s}" "${old_p}" | strip_hashes >"${work}/old.txt"
    report "${new_s}" "${new_p}" | strip_hashes >"${work}/new.txt"
    if diff -u "${work}/old.txt" "${work}/new.txt"; then
      echo "anchors unchanged between ${old} and ${new}"
    else
      echo "ANCHORS CHANGED between ${old} and ${new}: review the ingress adapter (README 'Bumping Paseo')" >&2
      exit 1
    fi
    ;;
  --check)
    ver="${2:-}"
    [[ -n "${ver}" ]] || { echo "usage: $0 --check <version>" >&2; exit 2; }
    work="$(mktemp -d)"; trap 'rm -rf "${work}"' EXIT
    read -r c_s c_p <<<"$(fetch_extract "${ver}" "${work}")"
    echo "# Paseo ${ver}"
    out="$(report "${c_s}" "${c_p}" | strip_hashes | tee /dev/stderr)"
    zeros="$(sed -n 's/^\([^#].*[^0-9 ]\) *0$/\1/p' <<<"${out}" | sed 's/ *$//')"
    if [[ -n "${zeros}" ]]; then
      echo "MISSING ANCHORS:" >&2
      printf '  %s\n' ${zeros} >&2
      exit 1
    fi
    echo "all ingress anchors present in ${ver}"
    ;;
  --version)
    ver="${2:-}"
    [[ -n "${ver}" ]] || { echo "usage: $0 --version <version>" >&2; exit 2; }
    work="$(mktemp -d)"; trap 'rm -rf "${work}"' EXIT
    read -r v_s v_p <<<"$(fetch_extract "${ver}" "${work}")"
    echo "# Paseo ${ver}"
    report "${v_s}" "${v_p}" | strip_hashes
    ;;
  --installed)
    root="$(npm root -g)"
    report "${root}/@getpaseo/server" "${root}/@getpaseo/protocol"
    ;;
  "")
    echo "usage: $0 <server-package-dir> [protocol-package-dir] | --diff <old> <new> | --version <v> | --check <v> | --installed" >&2
    exit 2
    ;;
  *)
    s="$1"
    if [[ -n "${2:-}" ]]; then
      p="$2"
    else
      p=""
      for cand in "$(dirname "$(dirname "${s}")")/@getpaseo/protocol" "$(dirname "${s}")/@getpaseo/protocol" "${s}/node_modules/@getpaseo/protocol"; do
        [[ -d "${cand}" ]] && { p="${cand}"; break; }
      done
      [[ -n "${p}" ]] || { echo "error: no @getpaseo/protocol next to ${s}; pass it as the second argument" >&2; exit 2; }
    fi
    report "${s}" "${p}"
    ;;
esac
