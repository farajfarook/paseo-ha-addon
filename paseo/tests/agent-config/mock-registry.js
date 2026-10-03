// Minimal npm registry for the Pi-package tests. Serves every <name>-<version>.tgz in
// REGISTRY_DIR (built with `npm pack`) as a package named <name> with that version.
//   GET /<name>                    -> packument (all versions, dist-tags.latest = highest)
//   GET /-/tarballs/<file>.tgz     -> the tarball
// Every request is logged to stdout as "<method> <path>".
const http = require("node:http");
const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");

const dir = process.env.REGISTRY_DIR || "/registry";
const port = Number(process.env.PORT || 80);

function index() {
  const pkgs = {};
  for (const file of fs.readdirSync(dir).filter((f) => f.endsWith(".tgz"))) {
    const m = file.match(/^(.+)-(\d+\.\d+\.\d+)\.tgz$/);
    if (!m) continue;
    const [, name, version] = m;
    const buf = fs.readFileSync(path.join(dir, file));
    (pkgs[name] ||= {})[version] = {
      name,
      version,
      dist: {
        tarball: `http://${process.env.REGISTRY_HOST || "registry"}/-/tarballs/${file}`,
        shasum: crypto.createHash("sha1").update(buf).digest("hex"),
        integrity: `sha512-${crypto.createHash("sha512").update(buf).digest("base64")}`,
      },
    };
  }
  return pkgs;
}

http
  .createServer((req, res) => {
    console.log(`${req.method} ${req.url}`);
    const url = decodeURIComponent(req.url.split("?")[0]);
    if (url.startsWith("/-/tarballs/")) {
      const file = path.join(dir, path.basename(url));
      if (!fs.existsSync(file)) return res.writeHead(404).end();
      res.writeHead(200, { "Content-Type": "application/octet-stream" });
      return res.end(fs.readFileSync(file));
    }
    const name = url.slice(1);
    const versions = index()[name];
    if (!versions) return res.writeHead(404, { "Content-Type": "application/json" }).end('{"error":"not found"}');
    const latest = Object.keys(versions).sort((x, y) => x.localeCompare(y, undefined, { numeric: true })).pop();
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ name, "dist-tags": { latest }, versions }));
  })
  .listen(port);
