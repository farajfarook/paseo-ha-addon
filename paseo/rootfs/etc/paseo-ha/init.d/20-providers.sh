#!/usr/bin/env bash
# shellcheck shell=bash
# ==============================================================================
# 20-providers: make the installed agent CLIs and the providers enabled in Paseo
# match the `providers` option.
#
#  1. Install the CLI of every selected provider persistently under /data/agents
#     and uninstall the CLI of every deselected one. Home/credential directories
#     are never touched. Pi is baked into the image and never installed here.
#  2. Set agents.providers.<id>.enabled in the persisted Paseo config for all
#     six providers: true only if the provider is selected and its CLI runs.
#
# - Reinstall only when the selected set or the pinned versions change
#   (stamp file /data/agents/.paseo-ha-providers.stamp).
# - Failures are logged per provider and never abort startup. A failed provider
#   stays out of the stamp (retried next start) and is disabled in Paseo.
# - Test seam: PASEO_HA_TEST_FAIL_INSTALL="id,id" makes those installs fail.
# ==============================================================================

AGENTS_DIR="${PASEO_HA_DATA}/agents"
STAMP="${AGENTS_DIR}/.paseo-ha-providers.stamp"
BIN_DIR="${AGENTS_DIR}/node_modules/.bin"

# Every provider Paseo supports, in `providers` option order.
ALL_PROVIDERS=(claude codex copilot opencode pi omp)

# Pinned npm specs per provider (space separated). Bump with add-on releases.
# `pi` has none: it is built into the image.
declare -A PROVIDER_SPECS=(
  [claude]="@anthropic-ai/claude-code@2.1.287"
  [codex]="@openai/codex@0.160.0"
  [copilot]="@github/copilot@1.0.91"
  [opencode]="opencode-ai@1.18.34"
  [omp]="bun@1.4.2 @oh-my-pi/pi-coding-agent@18.5.1"
  [pi]=""
)
# Binary that proves the provider works (run with --version).
declare -A PROVIDER_BIN=(
  [claude]="claude"
  [codex]="codex"
  [copilot]="copilot"
  [opencode]="opencode"
  [omp]="omp"
  [pi]="pi"
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

# Desired state: "id=specs" lines for selected providers that need an install.
desired=""
for id in "${ALL_PROVIDERS[@]}"; do
  [[ -n "${SELECTED[${id}]:-}" && -n "${PROVIDER_SPECS[${id}]}" ]] || continue
  desired+="${id}=${PROVIDER_SPECS[${id}]}"$'\n'
done

desired="${desired%$'\n'}"   # same shape as $(cat stamp): no trailing newline
current=""
[[ -f "${STAMP}" ]] && current="$(cat "${STAMP}")"

npm_pkg_name() { # strip the trailing @version from an npm spec
  local spec="$1"
  printf '%s' "${spec%@*}"
}

# npm_uninstall <specs...> -> remove the packages (names only), quietly.
npm_uninstall() {
  local spec names=()
  for spec in "$@"; do names+=("$(npm_pkg_name "${spec}")"); done
  npm uninstall --prefix "${AGENTS_DIR}" --no-audit --no-fund "${names[@]}" >/dev/null 2>&1
}

# provider_runs <id> -> true when the provider's CLI answers --version.
provider_runs() {
  local id="$1" bin="${PROVIDER_BIN[$1]}"
  if [[ "${id}" == "pi" ]]; then
    pi --version >/dev/null 2>&1
  else
    PATH="${BIN_DIR}:${PATH}" "${BIN_DIR}/${bin}" --version >/dev/null 2>&1
  fi
}

# --- Uninstall providers that are installed (per stamp) but no longer desired, or whose pins changed.
while IFS='=' read -r id specs; do
  [[ -z "${id}" ]] && continue
  if ! grep -qxF "${id}=${specs}" <<<"${desired}"; then
    if ! grep -q "^${id}=" <<<"${desired}"; then
      ph_log_info "Removing provider ${id}"
    fi
    # shellcheck disable=SC2086  # specs is a space-separated list
    npm_uninstall ${specs} || ph_log_warn "Failed to uninstall provider ${id}"
  fi
done <<<"${current}"

# --- Install each desired provider that is not already recorded with the same pins.
new_stamp=""
if [[ "${desired}" == "${current}" ]]; then
  new_stamp="${current}"
  [[ -n "${desired}" ]] && ph_log_info "Providers up to date: $(cut -d= -f1 <<<"${desired}" | paste -sd' ' -)"
else
  while IFS='=' read -r id specs; do
    [[ -z "${id}" ]] && continue
    if grep -qxF "${id}=${specs}" <<<"${current}" && provider_runs "${id}"; then
      new_stamp+="${id}=${specs}"$'\n'
      continue
    fi
    ph_log_info "Installing provider ${id} (${specs}) into ${AGENTS_DIR}..."
    log="$(mktemp)"
    # shellcheck disable=SC2086  # specs is a space-separated list
    if [[ ",${PASEO_HA_TEST_FAIL_INSTALL:-}," != *",${id},"* ]] \
       && npm install --prefix "${AGENTS_DIR}" --no-audit --no-fund --omit=dev --fetch-retries=1 --fetch-timeout=60000 ${specs} >"${log}" 2>&1 \
       && PATH="${BIN_DIR}:${PATH}" "${BIN_DIR}/${PROVIDER_BIN[${id}]}" --version >>"${log}" 2>&1; then
      ph_log_info "Installed provider ${id}: $(PATH="${BIN_DIR}:${PATH}" "${BIN_DIR}/${PROVIDER_BIN[${id}]}" --version 2>/dev/null | head -n1)"
      new_stamp+="${id}=${specs}"$'\n'
    else
      ph_log_error "Provider ${id} could not be installed or does not run on $(uname -m) (it will be disabled and retried on the next start). Last output:"
      grep -v '^[[:space:]]*$' "${log}" | tail -n 5 | while IFS= read -r line; do ph_log_error "  ${line}"; done
      # shellcheck disable=SC2086
      npm_uninstall ${specs} || true
    fi
    rm -f "${log}"
  done <<<"${desired}"
fi

# Failed providers are left out of the stamp so the next start retries them.
printf '%s' "${new_stamp}" > "${STAMP}"

# --- Sync Paseo's provider enable flags (the add-on owns these on every start).
# Paseo's `config set` only accepts the whole agents.providers object (dynamic keys
# have no per-field path), so read it, merge the six enabled flags with jq (keeping
# any other overrides under agents.providers.<id>) and write it back in one call.
enabled_list=""
flags='{}'
for id in "${ALL_PROVIDERS[@]}"; do
  state=false
  if [[ -n "${SELECTED[${id}]:-}" ]] && provider_runs "${id}"; then
    state=true
    enabled_list+="${id} "
  elif [[ -n "${SELECTED[${id}]:-}" ]]; then
    ph_log_warn "Provider ${id} is selected but its CLI is not usable; disabling it in Paseo"
  fi
  flags="$(jq -c --arg id "${id}" --argjson s "${state}" '.[$id] = {enabled: $s}' <<<"${flags}")"
done
existing="$(paseo daemon config get agents.providers --home "${PASEO_HOME}" --json 2>/dev/null | jq -c '.value // {}' 2>/dev/null)"
[[ -n "${existing}" ]] || existing='{}'
merged="$(jq -cn --argjson e "${existing}" --argjson f "${flags}" '$e * $f' 2>/dev/null)"
if [[ -n "${merged}" ]] \
   && paseo daemon config set agents.providers "${merged}" --home "${PASEO_HOME}" >/dev/null 2>&1; then
  ph_log_info "Paseo providers enabled: ${enabled_list:-none}"
else
  ph_log_warn "Failed to set Paseo provider enable flags; Paseo keeps its previous provider settings"
fi
exit 0
