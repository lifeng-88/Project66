#!/usr/bin/env node
const http = require("http");
const fs = require("fs");
const path = require("path");

const PORT = Number(process.env.BRIDGE_TEST_PORT || 5188);
const ROOT = path.resolve(__dirname, "../Web/bridge-test");

const server = http.createServer((req, res) => {
  const urlPath = req.url === "/" ? "/index.html" : req.url.split("?")[0];
  const filePath = path.join(ROOT, urlPath);
  if (!filePath.startsWith(ROOT)) {
    res.writeHead(403);
    res.end("Forbidden");
    return;
  }
  fs.readFile(filePath, (err, data) => {
    if (err) {
      res.writeHead(404);
      res.end("Not found");
      return;
    }
    const ext = path.extname(filePath).toLowerCase();
    const type = ext === ".html" ? "text/html; charset=utf-8" : "application/octet-stream";
    res.writeHead(200, { "Content-Type": type });
    res.end(data);
  });
});

server.listen(PORT, "127.0.0.1", () => {
  console.log(`bridge-test server listening on http://127.0.0.1:${PORT}/`);
});
