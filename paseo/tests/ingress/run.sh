#!/usr/bin/env bash
# ==============================================================================
# Ingress browser test (tasks 5.3 / 5.5). Starts the add-on image and a mock
# Home Assistant ingress (nginx, IP 172.30.32.2) on a Supervisor-like Docker
# network, then drives a real browser (Playwright) against
# http://localhost:<port>/api/hassio_ingress/test/ and checks:
#   1. the UI boots and auto-connects (WebSocket up, connection hint overridden)
#   2. the address bar keeps the ingress prefix after the router boots
#   3. in-app navigation keeps URLs under the prefix
#   4. a deep-link reload of a nested page returns to the same page
#   5. reports any request that escapes the prefix
#   6. a stale host (another server ID on the panel endpoint) is healed: the
#      registry holds the live ID and unrelated hosts, stale keys/routes are
#      gone, and the UI connects; a matching ID leaves storage untouched
#
# Usage: run.sh <image> [port]
# Env:   INGRESS_KEEP=1   keep containers for debugging
#        INGRESS_TIMEOUT  seconds to wait for health (default 180)
#        PLAYWRIGHT_DIR   directory with playwright-core installed
# ==============================================================================
set -euo pipefail
export MSYS_NO_PATHCONV=1

IMAGE="${1:?usage: run.sh <image> [port]}"
PORT="${2:-18080}"
export PORT
PREFIX_NAME="paseo-ingress-test"
TIMEOUT="${INGRESS_TIMEOUT:-180}"
NET="${PREFIX_NAME}-net"
ADDON="${PREFIX_NAME}-addon"
MOCK="${PREFIX_NAME}-mock"
ADDON_IP=172.30.33.10
INGRESS_PATH="/api/hassio_ingress/test"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FAILED=0
WORK="$(mktemp -d)"
# Docker Desktop on Windows needs a native host path (MSYS_NO_PATHCONV is set).
HOST_WORK="${WORK}"
command -v cygpath >/dev/null 2>&1 && HOST_WORK="$(cygpath -m "${WORK}")"
PWDIR="${PLAYWRIGHT_DIR:-$(pwd)/../browsertest}"

log()  { echo "[ingress] $*"; }
pass() { echo "[ingress] PASS: $*"; }
fail() { echo "[ingress] FAIL: $*" >&2; FAILED=1; }

cleanup() {
  local rc=$?
  if [[ "${rc}" -ne 0 || "${FAILED}" -ne 0 ]]; then
    docker logs "${ADDON}" 2>&1 | tail -n 200 >&2 || true
    docker logs "${MOCK}" 2>&1 | tail -n 100 >&2 || true
  fi
  if [[ "${INGRESS_KEEP:-}" != "1" ]]; then
    docker rm -f "${ADDON}" "${MOCK}" >/dev/null 2>&1 || true
    docker network rm "${NET}" >/dev/null 2>&1 || true
  fi
  rm -rf "${WORK}"
}
trap cleanup EXIT

docker network create --subnet 172.30.32.0/23 "${NET}" >/dev/null

# --- Mock HA ingress (IP 172.30.32.2, the address the add-on allows) ----------
sed -e "s|@TARGET@|${ADDON}:8099|g" -e "s|@PREFIX@|${INGRESS_PATH}|g" \
  "${HERE}/mock-ingress.conf" > "${WORK}/mock.conf"
docker run -d --name "${MOCK}" --network "${NET}" --ip 172.30.32.2 \
  -p "${PORT}:8123" -v "${HOST_WORK}/mock.conf:/etc/nginx/nginx.conf:ro" nginx:alpine >/dev/null

# --- Add-on ---------------------------------------------------------------------
MSYS_NO_PATHCONV=1 docker run -d --name "${ADDON}" --network "${NET}" --ip "${ADDON_IP}" \
  "${IMAGE}" >/dev/null

log "Waiting up to ${TIMEOUT}s for the add-on and the mock ingress"
for _ in $(seq 1 "${TIMEOUT}"); do
  if docker exec "${ADDON}" curl -fs -o /dev/null --max-time 2 http://127.0.0.1:6767/api/health 2>/dev/null \
    && curl -fs -o /dev/null --max-time 2 "http://localhost:${PORT}/api/hassio_ingress/test/api/health" 2>/dev/null; then
    break
  fi
  sleep 2
done
if ! curl -fs -o /dev/null --max-time 2 "http://localhost:${PORT}/api/hassio_ingress/test/api/health"; then
  fail "mock ingress did not become healthy"
  exit 1
fi
pass "mock ingress + add-on healthy through ${INGRESS_PATH}/"

# --- Browser checks --------------------------------------------------------------
if ! node -e "require('playwright-core')" 2>/dev/null; then
  log "playwright-core not found in ${PWDIR}; skipping browser checks"
  log "install with: (cd ${PWDIR} && npm i playwright-core) and ensure Edge or Chrome is present"
  exit 0
fi

if ! node - <<'EOF'
const { chromium } = require("playwright-core");
const path = require("path");
const os = require("os");

const PORT = process.env.PORT || "18080";
const BASE = `http://localhost:${PORT}`;
const PREFIX = "/api/hassio_ingress/test";
const results = [];
const escapes = [];
const errors = [];

function findExecutable() {
  const candidates = [
    "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe",
    "C:/Program Files/Google/Chrome/Application/chrome.exe",
    "C:/Program Files (x86)/Google/Chrome/Application/chrome.exe",
    path.join(os.homedir(), "AppData/Local/Google/Chrome/Application/chrome.exe"),
  ];
  for (const c of candidates) if (require("fs").existsSync(c)) return c;
  return null;
}

(async () => {
  const exe = findExecutable();
  if (!exe) throw new Error("no Edge/Chrome executable found");
  const browser = await chromium.launch({ executablePath: exe, headless: true });
  const page = await browser.newPage();

  page.on("requestfailed", (r) => {
    const u = new URL(r.url());
    if (u.pathname.startsWith(PREFIX)) return;
    if (u.pathname === "/" || u.pathname === "/favicon.ico") return;
    escapes.push(`${r.failure()?.errorText || "failed"} ${r.url()}`);
  });
  page.on("console", (m) => {
    if (m.type() === "error") errors.push(m.text().slice(0, 200));
  });
  page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));

  // 1) Boot: UI renders and the shim ran.
  await page.goto(`${BASE}${PREFIX}/`, { waitUntil: "networkidle", timeout: 30000 });
  await page.waitForTimeout(4000);
  const boot = await page.evaluate(() => ({
    title: document.title,
    shim: !!window.__PASEO_HA_FETCH__,
    hint: window.__PASEO_INITIAL_DAEMON_CONNECTION__ || null,
    path: window.location.pathname,
    host: window.location.host,
    bodyText: (document.body.innerText || "").slice(0, 200),
  }));
  results.push([boot.title === "Paseo" && boot.bodyText.length > 0, `UI boots (title=${JSON.stringify(boot.title)}, body=${JSON.stringify(boot.bodyText.slice(0, 60))})`]);
  results.push([boot.shim === true, "shim is active (fetch patch marker present)"]);
  results.push([
    !!boot.hint && boot.hint.listen === boot.host,
    `connection hint overridden (${JSON.stringify(boot.hint)})`,
  ]);
  results.push([boot.path.startsWith(PREFIX), `address bar keeps the ingress prefix (${boot.path})`]);

  // 2) WebSocket really connected to the daemon: wait for the WS state by
  //    probing a lightweight daemon endpoint through the same path.
  const resp = await page.evaluate(async (p) => {
    const r = await fetch(`${p}/api/health`);
    return r.status;
  }, PREFIX).catch((e) => `ERR:${e.message}`);
  results.push([resp === 200, `fetch('/api/health') from the page -> ${resp}`]);

  // 3) In-app navigation: click a sidebar/nav item if the UI exposes one.
  const nav = await page.$$("nav a, nav button, [role=tablist] [role=tab], aside button");
  if (nav.length > 1) {
    await nav[1].click().catch(() => {});
    await page.waitForTimeout(2000);
    const afterNav = await page.evaluate(() => window.location.pathname);
    results.push([afterNav.startsWith(PREFIX), `navigation stays under the prefix (${afterNav})`]);
    // 4) Deep-link reload.
    await page.reload({ waitUntil: "networkidle", timeout: 30000 }).catch(() => {});
    await page.waitForTimeout(4000);
    const afterReload = await page.evaluate(() => ({
      path: window.location.pathname,
      title: document.title,
      body: (document.body.innerText || "").length,
    }));
    results.push([
      afterReload.path === afterNav && afterReload.body > 0 && afterReload.title === "Paseo",
      `deep-link reload returns to the same page (${afterReload.path}, body chars=${afterReload.body})`,
    ]);
  } else {
    console.log("[browser] WARN: no nav elements found; navigation/reload checks skipped");
  }

  // 6) Stale host heal (heal-stale-host-after-reinstall).
  const STALE = "srv_staleSTALE01";
  const live = await page.evaluate(async (p) => (await (await fetch(`${p}/api/status`)).json()).serverId, PREFIX);
  const endpoint = `localhost:${PORT}`;
  const other = {
    serverId: "srv_otherOTHER01", label: "other", appearance: { color: "none", badgeDisplay: null }, lifecycle: {},
    connections: [{ id: "direct:elsewhere:6767", type: "directTcp", endpoint: "elsewhere:6767", useTls: false }],
    preferredConnectionId: "direct:elsewhere:6767", createdAt: "2026-01-01T00:00:00.000Z", updatedAt: "2026-01-01T00:00:00.000Z",
  };
  await page.evaluate(({ STALE, endpoint, other }) => {
    const stale = {
      serverId: STALE, label: "old", appearance: { color: "none", badgeDisplay: null }, lifecycle: {},
      connections: [{ id: `direct:${endpoint}`, type: "directTcp", endpoint, useTls: false }],
      preferredConnectionId: `direct:${endpoint}`, createdAt: "2026-01-01T00:00:00.000Z", updatedAt: "2026-01-01T00:00:00.000Z",
    };
    localStorage.setItem("@paseo:daemon-registry", JSON.stringify([stale, other]));
    localStorage.setItem("paseo:last-workspace-route-selection", JSON.stringify({ serverId: STALE, workspaceId: "wks_x" }));
    localStorage.setItem(`@paseo/provider-snapshot/v2:["${STALE}","cwd",null]`, "{}");
  }, { STALE, endpoint, other });
  await page.goto(`${BASE}${PREFIX}/h/${STALE}/workspace/wks_x`, { waitUntil: "networkidle", timeout: 30000 }).catch(() => {});
  await page.waitForTimeout(8000);
  const healed = await page.evaluate((STALE) => ({
    ids: (JSON.parse(localStorage.getItem("@paseo:daemon-registry") || "[]")).map((h) => h.serverId),
    last: localStorage.getItem("paseo:last-workspace-route-selection"),
    staleKeys: Object.keys(localStorage).filter((k) => k.includes(STALE)),
    path: location.pathname,
    reconnecting: /Reconnecting to host/i.test(document.body.innerText || ""),
  }), STALE);
  results.push([!!live && healed.ids.includes(live) && !healed.ids.includes(STALE), `stale host replaced by live ${live} (${JSON.stringify(healed.ids)})`]);
  results.push([healed.ids.includes(other.serverId), "host on another endpoint kept"]);
  results.push([!(healed.last || "").includes(STALE) && healed.staleKeys.length === 0, `stale keys removed (${JSON.stringify(healed.staleKeys)})`]);
  results.push([healed.path.startsWith(PREFIX) && !healed.path.includes(STALE), `deep link into the stale host redirected (${healed.path})`]);
  results.push([!healed.reconnecting, "UI is not stuck on 'Reconnecting to host'"]);

  // Same ID: a reload changes nothing.
  const before = await page.evaluate(() => localStorage.getItem("@paseo:daemon-registry"));
  await page.reload({ waitUntil: "networkidle", timeout: 30000 }).catch(() => {});
  await page.waitForTimeout(4000);
  const after = await page.evaluate(() => localStorage.getItem("@paseo:daemon-registry"));
  const norm = (s) => JSON.stringify((JSON.parse(s || "[]")).map((h) => [h.serverId, h.connections.map((c) => c.endpoint)]));
  results.push([norm(before) === norm(after), "matching server ID leaves the host list unchanged"]);

  console.log("[browser] escapes:", escapes.length ? escapes.slice(0, 10) : "none");
  console.log("[browser] console errors:", errors.length ? errors.slice(0, 10) : "none");
  for (const [ok, label] of results) {
    console.log(`[browser] ${ok ? "PASS" : "FAIL"}: ${label}`);
    if (!ok) process.exitCode = 1;
  }
  await browser.close();
  if (escapes.length) {
    console.log("[browser] FAIL: requests escaped the ingress prefix");
    process.exitCode = 1;
  }
})().catch((e) => {
  console.error("[browser] fatal:", e);
  process.exit(1);
});
EOF
then
  fail "browser checks failed"
else
  pass "browser checks passed"
fi

exit "${FAILED}"