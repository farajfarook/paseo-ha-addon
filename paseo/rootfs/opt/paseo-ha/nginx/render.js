#!/usr/bin/env node
// Renders the nginx ingress config (design D3 + D4 seam). Called by
// /etc/paseo-ha/init.d/50-nginx.sh. Done in node because the password has to be
// escaped for nginx conf strings, which is fragile with sed.
//
// Usage: node render.js <template> <output>
// Env:   PASEO_HA_NGINX_PASSWORD  set when the direct port is enabled with a
//                                 password (PASEO_PASSWORD is exported); empty
//                                 means the daemon upstream needs no auth.
"use strict";

const fs = require("fs");

function escapeNginxString(value) {
  return String(value)
    .replace(/\\/g, "\\\\")
    .replace(/"/g, '\\"')
    .replace(/[\r\n]+/g, " ")
    .replace(/#/g, "\\#");
}

const [tplPath, outPath] = process.argv.slice(2);
if (!tplPath || !outPath) {
  console.error("usage: render.js <template> <output>");
  process.exit(2);
}

let tpl;
try {
  tpl = fs.readFileSync(tplPath, "utf8");
} catch (err) {
  console.error(`render.js: cannot read ${tplPath}: ${err.message}`);
  process.exit(1);
}

const password = escapeNginxString(process.env.PASEO_HA_NGINX_PASSWORD || "");
let authHttp = "";
let wsMap = "";
let wsHeader = "";
if (password) {
  // HTTP: plain bearer on every proxied request. The browser never sends its
  // own Authorization, so an unconditional override is safe.
  authHttp = `        proxy_set_header Authorization "Bearer ${password}";`;
  // WebSocket: bearer goes in the paseo.bearer.* subprotocol. Keep whatever
  // protocol list the client sent and append ours.
  wsMap = [
    "map $http_sec_websocket_protocol $paseo_ws_protocols {",
    `    default "$http_sec_websocket_protocol, paseo.bearer.${password}";`,
    `    ""      "paseo.bearer.${password}";`,
    "}",
  ].join("\n");
  wsHeader = "        proxy_set_header Sec-WebSocket-Protocol $paseo_ws_protocols;";
}

const conf = tpl
  .replace(/@UPSTREAM_AUTH_HTTP@/g, authHttp)
  .replace(/@WS_PROTOCOLS_MAP@/g, wsMap)
  .replace(/@WS_PROTOCOLS_HEADER@/g, wsHeader);

try {
  fs.writeFileSync(outPath, conf, { mode: 0o600 });
  fs.chmodSync(outPath, 0o600);
} catch (err) {
  console.error(`render.js: cannot write ${outPath}: ${err.message}`);
  process.exit(1);
}