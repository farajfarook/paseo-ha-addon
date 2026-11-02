#!/usr/bin/env bash
# Run INSIDE a Codex workspace-write command, never elevated.
# Usage: bash probe.sh /absolute/workspace /absolute/outside-sentinel
set -euo pipefail

workspace="${1:?workspace required}"
outside="${2:?outside sentinel required}"
[[ -d "${workspace}" && -f "${outside}" && "${outside}" != "${workspace}"/* ]]
[[ "$(awk '/^NoNewPrivs:/ {print $2}' /proc/self/status)" == 1 ]]
[[ "$(awk '/^Seccomp:/ {print $2}' /proc/self/status)" == 2 ]]
[[ "$(awk '/^CapEff:/ {print $2}' /proc/self/status)" == 0000000000000000 ]]

probe_dir="$(mktemp -d "${workspace}/.codex-sandbox-probe.XXXXXX")"
trap 'rm -rf -- "${probe_dir}"' EXIT
cd "${probe_dir}"
printf 'one\n' > sample
[[ "$(cat sample)" == one ]]
printf 'two\n' > sample
[[ "$(cat sample)" == two ]]
rm sample
echo 'PASS: Bash and workspace read/write/delete'

if (printf 'must-not-write\n' >> "${outside}") 2>/dev/null; then
  echo 'FAIL: outside-workspace write succeeded' >&2
  exit 1
fi
echo 'PASS: outside-workspace write denied'

git init -q -b sandbox-probe
git config user.name 'Sandbox Probe'
git config user.email 'sandbox-probe@example.invalid'
printf 'test\n' > tracked
git add tracked
git -c core.hooksPath=/dev/null commit -qm 'Temporary sandbox validation'
git switch -qc probe-branch
[[ "$(git branch --show-current)" == probe-branch ]]
echo 'PASS: temporary Git repo, commit and local branch'

if command -v python3 >/dev/null; then
  python3 -c 'import unittest; t=unittest.FunctionTestCase(lambda: None); r=unittest.TestResult(); t.run(r); assert r.wasSuccessful()'
  echo 'PASS: Python test'
else
  echo 'SKIP: Python unavailable'
fi
printf 'const {test}=require("node:test"); const assert=require("node:assert/strict"); test("runtime",()=>assert.equal(2+2,4));\n' > runtime.test.cjs
node --test runtime.test.cjs
echo 'PASS: Node test'

curl --fail --silent --show-error --max-time 30 https://registry.npmjs.org/is-number/7.0.0 -o /dev/null
git ls-remote https://github.com/octocat/Hello-World.git HEAD > remote-head
[[ -s remote-head ]]
echo 'PASS: HTTPS and public Git remote'

npm install --prefix "${probe_dir}/deps" --cache "${probe_dir}/npm-cache" \
  --ignore-scripts --no-audit --no-fund --package-lock=false is-number@7.0.0
node -e 'if (!require(process.argv[1])(42)) process.exit(1)' "${probe_dir}/deps/node_modules/is-number"
echo 'PASS: dependency installation using workspace-local cache'
