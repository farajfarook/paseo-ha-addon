#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034  # the record arrays are read and written through namerefs
# ==============================================================================
# 20-providers: make the installed agent CLIs and the providers enabled in Paseo
# match the `providers` option.
#
#  1. Install the CLI of every selected provider, Pi included, persistently under
#     /data/agents, and uninstall the CLI of every deselected one. Home/credential
#     directories are never touched. No provider is baked into the image; Pi is
#     installed here like the rest. A provider is installed either from npm (the
#     default) or by its vendor's installer script (`PROVIDER_KIND` = script),
#     because Muse Code and Antigravity are not published to npm.
#  2. Set agents.providers.<id>.enabled in the persisted Paseo config for all
#     eight providers: true only if the provider is selected and its CLI runs.
#     Paseo resolves the providers its bundled plugins register through the same
#     per-provider override, so one mechanism covers both kinds.
#
# - Each start looks up `<package>@latest` in the npm registry. A prerelease on
#   the latest tag is ignored. PACKAGE_HOLD pins a package instead of the lookup.
# - Reinstall only when the selected set or the resolved versions change
#   (stamp file /data/agents/.paseo-ha-providers.stamp, lines `id=name@ver ...`).
# - A script provider is installed into its own directory under
#   /data/agents/bin and never looked up in the registry: the vendor's installer
#   runs once, and the CLI updates itself afterwards. Each start records the
#   version the CLI reports, and nothing is downloaded while it answers.
# - No registry: an installed provider keeps its version; a missing one stays
#   disabled and is retried on the next start.
# - An upgrade whose CLI fails --version is rolled back to the stamped version and
#   recorded in /data/agents/.paseo-ha-providers.failed, so that exact version is
#   not downloaded again. A newer release is tried normally. Script providers have
#   no version to blame, so they are only ever retried.
# - Failures are logged per provider and never abort startup. Each install is capped
#   at PASEO_HA_PROVIDER_INSTALL_TIMEOUT seconds (default 600) and each --version
#   check at 60 s, so a hung registry, install script or CLI counts as a failure
#   instead of blocking the daemon.
# - Test seams: PASEO_HA_TEST_FAIL_INSTALL="id,id" makes those installs fail;
#   PASEO_HA_TEST_FAIL_SPEC="name@ver,..." makes installs of those exact specs fail;
#   PASEO_HA_TEST_LATEST="name=ver,..." replaces the registry lookup for those
#   packages; PASEO_HA_TEST_SCRIPT_URL="<url|path>" replaces the vendor installer
#   for every script provider (a readable local path skips the download);
#   PASEO_HA_TEST_OFFLINE=1 makes every other lookup fail.
# ==============================================================================

AGENTS_DIR="${PASEO_HA_DATA}/agents"
STAMP="${AGENTS_DIR}/.paseo-ha-providers.stamp"
FAILED="${AGENTS_DIR}/.paseo-ha-providers.failed"
BIN_DIR="${AGENTS_DIR}/node_modules/.bin"
SCRIPT_DIR="${AGENTS_DIR}/bin"
LOOKUP_TIMEOUT="${PASEO_HA_PROVIDER_LOOKUP_TIMEOUT:-20}"   # seconds per package
INSTALL_TIMEOUT="${PASEO_HA_PROVIDER_INSTALL_TIMEOUT:-600}"  # seconds per provider install (npm and its scripts)

# Every provider Paseo supports, in `providers` option order.
ALL_PROVIDERS=(claude codex copilot opencode pi omp muse antigravity)

# npm packages per provider (space separated, the CLI's own package last).
# Only used for npm-installed providers; a script provider has no package.
declare -A PROVIDER_PKGS=(
  [claude]="@anthropic-ai/claude-code"
  [codex]="@openai/codex"
  [copilot]="@github/copilot"
  [opencode]="opencode-ai"
  [pi]="@earendil-works/pi-coding-agent"
  [omp]="bun @oh-my-pi/pi-coding-agent"
)
# Binary that proves the provider works (run with --version).
declare -A PROVIDER_BIN=(
  [claude]="claude"
  [codex]="codex"
  [copilot]="copilot"
  [opencode]="opencode"
  [pi]="pi"
  [omp]="omp"
  [muse]="muse"
  [antigravity]="agy"
)
# Install path per provider: "npm" (the default) or "script" (vendor installer).
declare -A PROVIDER_KIND=(
  [muse]="script"
  [antigravity]="script"
)
# Where the CLI lives. npm providers share the npm bin dir; a script provider gets
# a directory of its own, so uninstalling it removes exactly the files the vendor
# installer wrote and nothing of another provider's.
declare -A PROVIDER_BIN_DIR=(
  [muse]="${SCRIPT_DIR}/muse"
  [antigravity]="${SCRIPT_DIR}/antigravity"
)
# Vendor installers for the script providers: the installer is downloaded and run
# once into the provider's own directory, and the CLI updates itself afterwards.
declare -A SCRIPT_URL=(
  [muse]="https://dev.meta.ai/install.sh"
  [antigravity]="https://antigravity.google/cli/install.sh"
)
# Shell the vendor documents for running the installer, and the extra arguments and
# environment variables that put it in our directory (the vendors disagree on how).
# Muse Code's installer is a bash script despite the documentation's `| sh`, and
# Alpine's /bin/sh (busybox) would fail on it.
declare -A SCRIPT_SHELL=(
  [muse]="bash"
  [antigravity]="bash"
)
declare -A SCRIPT_ARGS=(
  [antigravity]="--dir ${PROVIDER_BIN_DIR[antigravity]}"
)
declare -A SCRIPT_ENV=(
  [muse]="MUSE_INSTALL_DIR=${PROVIDER_BIN_DIR[muse]}"
)
# Maintainer hold: package name -> exact version installed instead of `latest`.
# Empty by default. Use it when a new agent release breaks with the pinned Paseo.
declare -A PACKAGE_HOLD=(
)

mkdir -p "${AGENTS_DIR}"
[[ -f "${AGENTS_DIR}/package.json" ]] || echo '{"name":"paseo-ha-agents","private":true}' > "${AGENTS_DIR}/package.json"

# Selected providers (known IDs only, unique).
declare -A SELECTED=()
while IFS= read -r name; do
  [[ -z "${name}" ]] && continue
  if [[ -z "${PROVIDER_BIN[${name}]:-}" ]]; then
    ph_log_warn "Unknown provider '${name}' in providers option; ignoring"
    continue
  fi
  SELECTED["${name}"]=1
done < <(ph_opt_list providers)

# Stamp and failed-upgrade records: id -> specs. For an npm provider the specs are
# its npm specs; for a script provider it is `<bin>@<the version its CLI reports>`,
# which may contain spaces (Muse Code answers "Muse Code 1.4.4 (1.4.4-R5419.1)").
# Only the npm path parses a spec, and the uninstall path does not need one.
declare -A STAMPED=() BAD=()
read_records() { # read_records <file> <array name>
  local -n into="$2"
  local id specs
  [[ -f "$1" ]] || return 0
  while IFS='=' read -r id specs || [[ -n "${id}" ]]; do   # last line has no newline
    [[ -n "${id}" ]] && into["${id}"]="${specs}"
  done < "$1"
}
read_records "${STAMP}" STAMPED
read_records "${FAILED}" BAD

npm_pkg_name() { # strip the trailing @version from an npm spec
  local spec="$1"
  printf '%s' "${spec%@*}"
}

# in_csv <value> <comma list> -> true when value is one of the items.
in_csv() { [[ ",$2," == *",$1,"* ]]; }

# provider_is_script <id> -> true when the CLI comes from a vendor installer.
provider_is_script() { [[ "${PROVIDER_KIND[$1]:-npm}" == "script" ]]; }

# provider_bin_dir <id> -> the directory the provider's CLI lives in.
provider_bin_dir() { printf '%s' "${PROVIDER_BIN_DIR[$1]:-${BIN_DIR}}"; }

# npm_uninstall <specs...> -> remove the packages (names only), quietly.
npm_uninstall() {
  local spec names=()
  for spec in "$@"; do names+=("$(npm_pkg_name "${spec}")"); done
  npm uninstall --prefix "${AGENTS_DIR}" --no-audit --no-fund "${names[@]}" >/dev/null 2>&1
}

# provider_bin <id> -> prints the CLI path when it is installed, else fails.
provider_bin() {
  local bin
  bin="$(provider_bin_dir "$1")/${PROVIDER_BIN[$1]}"
  [[ -x "${bin}" ]] || return 1
  printf '%s' "${bin}"
}

# provider_version <id> -> prints the CLI's first --version line (fails when the
# CLI is missing, exits non-zero or prints nothing). The provider's own directory
# goes first on PATH: an npm CLI wrapper looks up its runtime (bun, node) there.
provider_version() {
  local bin out
  bin="$(provider_bin "$1")" || return 1
  out="$(timeout -k 5 60 env PATH="$(provider_bin_dir "$1"):${PATH}" "${bin}" --version 2>/dev/null)" || return 1
  [[ -n "${out}" ]] || return 1
  printf '%s\n' "${out%%$'\n'*}"
}

# provider_runs <id> -> true when the provider's CLI answers --version.
provider_runs() { provider_version "$1" >/dev/null 2>&1; }

# provider_uninstall <id> <specs> -> remove the provider's CLI files: the whole
# directory for a script provider, the npm packages otherwise.
provider_uninstall() {
  local id="$1" specs="$2"
  if provider_is_script "${id}"; then
    rm -rf "$(provider_bin_dir "${id}")"
  else
    # shellcheck disable=SC2086  # specs is a space-separated list
    npm_uninstall ${specs}
  fi
}

# resolve_pkg <name> -> prints <name>@<version> for the held or latest stable
# version; fails when the registry can't answer or `latest` is a prerelease.
resolve_pkg() {
  local name="$1" ver="" item
  if [[ -n "${PACKAGE_HOLD[${name}]:-}" ]]; then
    ver="${PACKAGE_HOLD[${name}]}"
  else
    local IFS=','
    for item in ${PASEO_HA_TEST_LATEST:-}; do
      [[ "${item%=*}" == "${name}" ]] && ver="${item##*=}"
    done
    unset IFS
    if [[ -z "${ver}" ]]; then
      [[ -n "${PASEO_HA_TEST_OFFLINE:-}" ]] && return 1
      ver="$(timeout "${LOOKUP_TIMEOUT}" npm view "${name}@latest" version \
               --fetch-retries=0 --fetch-timeout=$(( LOOKUP_TIMEOUT * 1000 )) 2>/dev/null | tail -n1)"
    fi
    if [[ ! "${ver}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      [[ -n "${ver}" ]] && ph_log_warn "Latest ${name} is ${ver}, not a stable release; not installing it" >&2
      return 1
    fi
  fi
  printf '%s@%s' "${name}" "${ver}"
}

# install_specs <id> <specs> -> npm install and check --version; output in $log.
install_specs() {
  local id="$1" specs="$2" spec
  for spec in ${specs}; do
    in_csv "${spec}" "${PASEO_HA_TEST_FAIL_SPEC:-}" && { echo "test seam: ${spec} fails" >"${log}"; return 1; }
  done
  in_csv "${id}" "${PASEO_HA_TEST_FAIL_INSTALL:-}" && { echo "test seam: ${id} fails" >"${log}"; return 1; }
  # shellcheck disable=SC2086  # specs is a space-separated list
  timeout -k 10 "${INSTALL_TIMEOUT}" npm install --prefix "${AGENTS_DIR}" --no-audit --no-fund --omit=dev --fetch-retries=1 --fetch-timeout=60000 ${specs} >"${log}" 2>&1 \
    && provider_version "${id}" >>"${log}" 2>&1
}

# install_script <id> -> download and run the vendor's installer into the
# provider's own directory, then require the CLI to answer --version. The
# directory is emptied first, so a partial download or an older vendor layout
# cannot be mistaken for a working install. A non-zero exit from the installer
# only counts against it when the CLI does not run afterwards: a vendor's
# post-install step failing must not turn into a reinstall loop. Output in $log.
install_script() {
  local id="$1" url shell installer rc
  in_csv "${id}" "${PASEO_HA_TEST_FAIL_INSTALL:-}" && { echo "test seam: ${id} fails" >"${log}"; return 1; }
  url="${PASEO_HA_TEST_SCRIPT_URL:-${SCRIPT_URL[${id}]}}"
  shell="${SCRIPT_SHELL[${id}]}"

  rm -rf "$(provider_bin_dir "${id}")"
  mkdir -p "$(provider_bin_dir "${id}")"

  installer="$(mktemp)"
  if [[ -f "${url}" ]]; then                    # test seam: a local stub installer
    cp "${url}" "${installer}"
  elif ! timeout -k 5 120 curl -fsSL --fetch-retries=1 --fetch-timeout=60000 \
         -o "${installer}" "${url}" 2>>"${log}"; then
    echo "could not download the installer from ${url}" >>"${log}"
    rm -f "${installer}"
    return 1
  fi

  # shellcheck disable=SC2086  # args is a space-separated list from SCRIPT_ARGS
  env ${SCRIPT_ENV[${id}]:-} timeout -k 10 "${INSTALL_TIMEOUT}" "${shell}" "${installer}" ${SCRIPT_ARGS[${id}]:-} >"${log}" 2>&1
  rc=$?
  rm -f "${installer}"

  if provider_version "${id}" >>"${log}" 2>&1; then
    [[ ${rc} -eq 0 ]] || echo "the installer exited with ${rc}, but ${PROVIDER_BIN[${id}]} runs" >>"${log}"
    return 0
  fi
  [[ ${rc} -eq 0 ]] || echo "the installer exited with ${rc}" >>"${log}"
  return 1
}

log_tail() { grep -v '^[[:space:]]*$' "${log}" | tail -n 5 | while IFS= read -r line; do ph_log_error "  ${line}"; done; }

# --- Uninstall providers that are installed (per stamp) but no longer selected.
# A provider whose uninstall fails stays in the stamp so the next start retries it.
declare -A NEW_STAMP=() NEW_BAD=() NEW_VERSION=()
for id in "${!STAMPED[@]}"; do
  [[ -n "${SELECTED[${id}]:-}" ]] && continue
  ph_log_info "Removing provider ${id}"
  if ! provider_uninstall "${id}" "${STAMPED[${id}]}"; then
    ph_log_warn "Failed to uninstall provider ${id}; it will be retried on the next start"
    NEW_STAMP["${id}"]="${STAMPED[${id}]}"
  fi
done

# --- Bring each selected provider to its resolved version. A script provider is
# installed once into its own directory and updates itself afterwards, so its
# stamp carries whatever version its CLI reports; an npm provider is compared
# with the latest stable release of its packages on every start.
skipped_checks=""
for id in "${ALL_PROVIDERS[@]}"; do
  [[ -n "${SELECTED[${id}]:-}" ]] || continue
  old="${STAMPED[${id}]:-}"

  if provider_is_script "${id}"; then
    # The daemon (and agents) find the CLI through PATH; the directory only exists
    # while the provider is selected.
    ph_env_prepend_path "$(provider_bin_dir "${id}")"
    if provider_runs "${id}"; then
      version_seen="$(provider_version "${id}")"
      NEW_STAMP["${id}"]="${PROVIDER_BIN[${id}]}@${version_seen}"
      NEW_VERSION["${id}"]="${version_seen}"
      continue
    fi
    ph_log_info "Installing provider ${id} from ${SCRIPT_URL[${id}]} into $(provider_bin_dir "${id}")..."
    log="$(mktemp)"
    if install_script "${id}"; then
      version_seen="$(provider_version "${id}")"
      ph_log_info "Installed provider ${id}: ${version_seen}"
      NEW_STAMP["${id}"]="${PROVIDER_BIN[${id}]}@${version_seen}"
      NEW_VERSION["${id}"]="${version_seen}"
    else
      ph_log_error "Provider ${id} could not be installed or does not run on $(uname -m) (it will be disabled and retried on the next start). Last output:"
      log_tail
      # A half install is not worth keeping: the next start empties the directory
      # anyway, and this way a failed 336 MB download does not sit in /data.
      rm -rf "$(provider_bin_dir "${id}")"
    fi
    rm -f "${log}"
    continue
  fi

  desired="" lookup_ok=true
  for name in ${PROVIDER_PKGS[${id}]}; do
    if spec="$(resolve_pkg "${name}")"; then desired+="${spec} "; else lookup_ok=false; fi
  done
  desired="${desired% }"

  if [[ "${lookup_ok}" != true ]]; then
    skipped_checks+="${id} "
    [[ -n "${BAD[${id}]:-}" ]] && NEW_BAD["${id}"]="${BAD[${id}]}"
    if [[ -n "${old}" ]] && provider_runs "${id}"; then
      ph_log_warn "Could not check for a newer ${id}; keeping the installed version"
      NEW_STAMP["${id}"]="${old}"
    else
      ph_log_error "Provider ${id} is not installed and the npm registry could not be reached; it stays disabled and will be retried on the next start"
    fi
    continue
  fi

  # Package names dropped from a provider (a maintainer change) are removed.
  for spec in ${old}; do
    name="$(npm_pkg_name "${spec}")"
    [[ " ${desired} " == *" ${name}@"* ]] || npm_uninstall "${spec}" || true
  done

  if [[ "${desired}" == "${old}" ]] && provider_runs "${id}"; then
    NEW_STAMP["${id}"]="${old}"
    continue
  fi
  if [[ "${desired}" == "${BAD[${id}]:-}" && -n "${old}" ]] && provider_runs "${id}"; then
    ph_log_info "Skipping ${id} ${desired}: it failed its check before; keeping ${old}"
    NEW_STAMP["${id}"]="${old}"
    NEW_BAD["${id}"]="${desired}"
    continue
  fi

  ph_log_info "Installing provider ${id} (${desired}) into ${AGENTS_DIR}..."
  log="$(mktemp)"
  if install_specs "${id}" "${desired}"; then
    ph_log_info "Installed provider ${id}: $(provider_version "${id}")"
    NEW_STAMP["${id}"]="${desired}"
  elif [[ -n "${old}" && "${old}" != "${desired}" ]]; then
    ph_log_error "Provider ${id} ${desired} could not be installed or does not run on $(uname -m); rolling back to ${old}. Last output:"
    log_tail
    if install_specs "${id}" "${old}"; then
      ph_log_info "Rolled back provider ${id} to ${old}; ${desired} will not be tried again"
      NEW_STAMP["${id}"]="${old}"
      NEW_BAD["${id}"]="${desired}"
    else
      ph_log_error "Rollback of provider ${id} failed too (it will be disabled and retried on the next start). Last output:"
      log_tail
      # shellcheck disable=SC2086
      npm_uninstall ${desired} || true
    fi
  else
    ph_log_error "Provider ${id} could not be installed or does not run on $(uname -m) (it will be disabled and retried on the next start). Last output:"
    log_tail
    # shellcheck disable=SC2086
    npm_uninstall ${desired} || true
  fi
  rm -f "${log}"
done

write_records() { # write_records <file> <array name>
  local -n from="$2"
  local id out=""
  for id in "${ALL_PROVIDERS[@]}"; do
    [[ -n "${from[${id}]:-}" ]] && out+="${id}=${from[${id}]}"$'\n'
  done
  printf '%s' "${out%$'\n'}" > "$1"
}
write_records "${STAMP}" NEW_STAMP
write_records "${FAILED}" NEW_BAD

# --- Sync Paseo's provider enable flags (the add-on owns these on every start).
# Paseo's `config set` only accepts the whole agents.providers object (dynamic keys
# have no per-field path), so read it, merge the eight enabled flags with jq (keeping
# any other overrides under agents.providers.<id>) and write it back in one call.
enabled_list=""
summary=""
flags='{}'
for id in "${ALL_PROVIDERS[@]}"; do
  state=false
  if [[ -n "${SELECTED[${id}]:-}" ]] && provider_runs "${id}"; then
    state=true
    enabled_list+="${id} "
    version="${NEW_VERSION[${id}]:-}"
    if [[ -z "${version}" ]]; then
      # npm provider: the stamp is `<specs>` and its last spec ends in @<version>.
      main="${NEW_STAMP[${id}]:-?}"
      main="${main##* }"
      version="${main##*@}"
    fi
    summary+="${id} ${version}, "
  elif [[ -n "${SELECTED[${id}]:-}" ]]; then
    ph_log_warn "Provider ${id} is selected but its CLI is not usable; disabling it in Paseo"
  fi
  flags="$(jq -c --arg id "${id}" --argjson s "${state}" '.[$id] = {enabled: $s}' <<<"${flags}")"
done
summary="${summary%, }"
[[ -n "${skipped_checks}" ]] && summary+=" (update check skipped for ${skipped_checks% }: npm registry unreachable)"
ph_log_info "Providers: ${summary:-none}"

# A failed or unreadable read must not look like "no overrides": writing the whole object
# back would then erase the user's other provider settings. `config get` succeeds with
# set:false when nothing is stored, which is the only case that means an empty object.
merged=""
if raw="$(paseo daemon config get agents.providers --home "${PASEO_HOME}" --json 2>/dev/null)" \
   && existing="$(jq -ce 'if .set == true then (.value | select(type == "object")) elif .set == false then {} else empty end' <<<"${raw}" 2>/dev/null)" \
   && [[ -n "${existing}" ]]; then
  merged="$(jq -cn --argjson e "${existing}" --argjson f "${flags}" '$e * $f' 2>/dev/null)"
fi
if [[ -z "${merged}" ]]; then
  ph_log_warn "Could not read Paseo's provider settings; leaving them unchanged (the enable flags were not synced)"
elif paseo daemon config set agents.providers "${merged}" --home "${PASEO_HOME}" >/dev/null 2>&1; then
  ph_log_info "Paseo providers enabled: ${enabled_list:-none}"
else
  ph_log_warn "Failed to set Paseo provider enable flags; Paseo keeps its previous provider settings"
fi
exit 0
