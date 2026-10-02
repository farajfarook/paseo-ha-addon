// Minimal Home Assistant WebSocket API mock for testing paseo-ha-ws.
// Serves ws://<host>:<PORT>/core/websocket, expects token MOCK_TOKEN.
const http = require("node:http");
const crypto = require("node:crypto");
const token = process.env.MOCK_TOKEN || "test-supervisor-token";
const port = Number(process.env.PORT || 8124);

function frame(text) {
  const payload = Buffer.from(text);
  const len = payload.length;
  const header = len < 126 ? Buffer.from([0x81, len]) : Buffer.from([0x81, 126, len >> 8, len & 255]);
  return Buffer.concat([header, payload]);
}
function parse(buf) {
  let len = buf[1] & 127, off = 2;
  if (len === 126) { len = buf.readUInt16BE(2); off = 4; }
  const mask = buf.subarray(off, off + 4);
  const data = buf.subarray(off + 4, off + 4 + len).map((b, i) => b ^ mask[i % 4]);
  return Buffer.from(data).toString();
}
const server = http.createServer((_, res) => res.end());
server.on("upgrade", (req, socket) => {
  const accept = crypto.createHash("sha1").update(req.headers["sec-websocket-key"] + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").digest("base64");
  socket.write(`HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: ${accept}\r\n\r\n`);
  socket.write(frame(JSON.stringify({ type: "auth_required", ha_version: "mock" })));
  socket.on("data", (buf) => {
    if ((buf[0] & 15) === 8) return socket.end();
    const msg = JSON.parse(parse(buf));
    console.log("recv", msg.type);
    if (msg.type === "auth") {
      socket.write(frame(JSON.stringify(msg.access_token === token ? { type: "auth_ok" } : { type: "auth_invalid" })));
    } else if (msg.type === "config/area_registry/list") {
      socket.write(frame(JSON.stringify({ id: msg.id, type: "result", success: true, result: [{ area_id: "office", name: "Office" }] })));
    } else {
      socket.write(frame(JSON.stringify({ id: msg.id, type: "result", success: false, error: { code: "unknown_command", message: "Unknown command." } })));
    }
  });
});
server.listen(port, () => console.log(`mock ha ws on ${port}`));
