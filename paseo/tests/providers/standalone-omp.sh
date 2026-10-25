#!/usr/bin/env bash
# shellcheck disable=SC2016  # positional arguments expand in the child shell
# Exercise the real startup hook without Docker, network, or live configuration.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "${here}/../.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf -- "${test_dir}"' EXIT
mkdir -p "${test_dir}/bin" "${test_dir}/home with spaces/.local/bin"

cat > "${test_dir}/bin/paseo" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
config="${PASEO_HOME}/config.json"
mkdir -p "${PASEO_HOME}"
if [[ "$*" == 'daemon config get agents.providers '* ]]; then
  if [[ -f "${config}" ]]; then
    jq -c '{set:true,value:(.agents.providers // {})}' "${config}"
  else
    echo '{"set":false}'
  fi
elif [[ "$*" == 'daemon config set agents.providers '* ]]; then
  jq -n --argjson providers "$5" '{agents:{providers:$providers}}' > "${config}"
else
  exit 99
fi
STUB
cat > "${test_dir}/bin/npm" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${PASEO_HA_DATA}/npm.calls"
if [[ "$1" == uninstall ]]; then
  rm -f "${PASEO_HA_DATA}/agents/node_modules/.bin/omp"
else
  exit 99
fi
STUB
chmod +x "${test_dir}/bin/"*

run_hook() {
  printf '{"providers":%s}\n' "$1" > "${test_dir}/options.json"
  : > "${test_dir}/daemon.env"
  env HOME="${test_dir}/home with spaces" \
    PATH="${test_dir}/bin:${test_dir}/data/agents/node_modules/.bin:/usr/local/bin:/usr/bin:/bin" \
    PASEO_HOME="${test_dir}/paseo" PASEO_HA_DATA="${test_dir}/data" \
    PASEO_HA_OPTIONS_FILE="${test_dir}/options.json" \
    PASEO_HA_ENV_FILE="${test_dir}/daemon.env" PASEO_HA_TEST_OFFLINE=1 \
    bash -c 'source "$1"; (source "$2"); ph_load_env; command -v omp > "$3" || true' \
    _ "${root}/rootfs/usr/local/lib/paseo-ha/common.sh" \
    "${root}/rootfs/etc/paseo-ha/init.d/20-providers.sh" \
    "${test_dir}/resolved" > "${test_dir}/hook.log" 2>&1
}
enabled() { jq -er '.agents.providers.omp.enabled == true' "${test_dir}/paseo/config.json" >/dev/null; }
standalone="${test_dir}/home with spaces/.local/bin/omp"
printf '#!/bin/sh\necho omp/18.12.6\n' > "${standalone}"
chmod +x "${standalone}"

run_hook '["omp"]'
enabled
[[ "$(cat "${test_dir}/resolved")" == "${standalone}" ]]
[[ ! -e "${test_dir}/data/npm.calls" ]]
grep -F 'Providers: omp omp/18.12.6' "${test_dir}/hook.log" >/dev/null
run_hook '["omp"]'
enabled
[[ "$(cat "${test_dir}/resolved")" == "${standalone}" ]]
[[ ! -e "${test_dir}/data/npm.calls" ]]
echo 'PASS: standalone OMP survives repeated starts and is discoverable without npm'

# A managed stamp must remain so deselection can clean npm without removing
# the separately installed standalone executable.
printf 'omp=bun@1.3.14 @oh-my-pi/pi-coding-agent@18.12.6\n' > "${test_dir}/data/agents/.paseo-ha-providers.stamp"
run_hook '["omp"]'
enabled
grep '^omp=bun@' "${test_dir}/data/agents/.paseo-ha-providers.stamp" >/dev/null
run_hook '[]'
if enabled; then exit 1; fi
[[ -x "${standalone}" && ! -s "${test_dir}/resolved" ]]
grep '^uninstall ' "${test_dir}/data/npm.calls" >/dev/null
echo 'PASS: deselection removes managed npm packages but retains standalone OMP'

printf '#!/bin/sh\nexit 1\n' > "${standalone}"
run_hook '["omp"]'
if enabled; then exit 1; fi
echo 'PASS: broken standalone OMP is not enabled when npm is unavailable'
rm "${standalone}"
run_hook '["omp"]'
if enabled; then exit 1; fi
echo 'PASS: missing standalone OMP retains existing offline behavior'

mkdir -p "${test_dir}/data/agents/node_modules/.bin"
printf '#!/bin/sh\necho 18.12.6\n' > "${test_dir}/data/agents/node_modules/.bin/omp"
chmod +x "${test_dir}/data/agents/node_modules/.bin/omp"
printf 'omp=bun@1.3.14 @oh-my-pi/pi-coding-agent@18.12.6\n' > "${test_dir}/data/agents/.paseo-ha-providers.stamp"
printf '#!/bin/sh\nexit 1\n' > "${standalone}"
chmod +x "${standalone}"
run_hook '["omp"]'
enabled
[[ "$(cat "${test_dir}/resolved")" == "${test_dir}/data/agents/node_modules/.bin/omp" ]]
grep '^omp=bun@' "${test_dir}/data/agents/.paseo-ha-providers.stamp" >/dev/null
echo 'PASS: broken standalone OMP falls back to the healthy managed npm installation'
