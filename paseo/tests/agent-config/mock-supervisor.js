// Minimal stand-in for the Supervisor's Core proxy (http://supervisor/core/...)
// used by the lane C tests. Run it with node in a container aliased `supervisor`.
//   MOCK_MCP=200|404|401  -> behaviour of POST /core/api/mcp (default 200)
//   MOCK_TOKEN            -> expected bearer token (default "test-supervisor-token")
// Every request is logged to stdout as "<method> <path> auth=<ok|bad|none>".
const http = require("node:http");

const mode = process.env.MOCK_MCP || "200";
const token = process.env.MOCK_TOKEN || "test-supervisor-token";
const port = Number(process.env.PORT || 80);

function send(res, status, body, type = "application/json") {
  res.writeHead(status, { "Content-Type": type });
  res.end(typeof body === "string" ? body : JSON.stringify(body));
}

http
  .createServer((req, res) => {
    const auth = req.headers.authorization;
    const authState = !auth ? "none" : auth === `Bearer ${token}` ? "ok" : "bad";
    const path = req.url.replace(/^\/core/, "");
    let raw = "";
    req.on("data", (c) => (raw += c));
    req.on("end", () => {
      let rpc = null;
      try {
        rpc = raw ? JSON.parse(raw) : null;
      } catch {}
      console.log(`${req.method} ${req.url} auth=${authState}${rpc && rpc.method ? ` rpc=${rpc.method}` : ""}`);
      if (authState !== "ok") return send(res, 401, "401: Unauthorized", "text/plain");
      if (path === "/api/") return send(res, 200, { message: "API running." });
      if (path === "/api/config/core/check_config" && req.method === "POST")
        return send(res, 200, { result: "valid", errors: null, warnings: null });
      if (path === "/api/mcp") {
        if (mode === "404") return send(res, 404, "Model Context Protocol server is not configured", "text/plain");
        if (mode === "401") return send(res, 401, "401: Unauthorized", "text/plain");
        if (req.method !== "POST") return send(res, 405, "405: Method Not Allowed", "text/plain");
        if (!rpc || rpc.id === undefined) {
          res.writeHead(202);
          return res.end();
        }
        const reply = (result) => send(res, 200, { jsonrpc: "2.0", id: rpc.id, result });
        switch (rpc.method) {
          case "initialize":
            return reply({
              protocolVersion: (rpc.params && rpc.params.protocolVersion) || "2025-03-26",
              capabilities: { tools: { listChanged: false }, prompts: {} },
              serverInfo: { name: "home-assistant", version: "mock" },
            });
          case "tools/list":
            return reply({
              tools: [
                {
                  name: "HassTurnOn",
                  description: "Turns on/opens a device or entity",
                  inputSchema: { type: "object", properties: { name: { type: "string" } } },
                },
              ],
            });
          case "prompts/list":
            return reply({ prompts: [] });
          case "resources/list":
            return reply({ resources: [] });
          case "ping":
            return reply({});
          default:
            return send(res, 200, {
              jsonrpc: "2.0",
              id: rpc.id,
              error: { code: -32601, message: "Method not found" },
            });
        }
      }
      return send(res, 404, "404: Not Found", "text/plain");
    });
  })
  .listen(port, () => console.log(`mock supervisor listening on ${port} (mcp=${mode})`));
