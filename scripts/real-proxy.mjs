// Dev-only same-origin proxy to the real Flackle API.
// Serves the Flutter web build, forwards /api/* to https://flackle.com, proxies
// media (CDN) and tunnels the gateway WebSocket. No demo data.
import http from "node:http";
import https from "node:https";
import { createReadStream } from "node:fs";
import { stat } from "node:fs/promises";
import path from "node:path";
import { WebSocketServer, WebSocket } from "ws";

const ROOT = path.resolve(import.meta.dirname, "..", "build", "web");
const PORT = Number(process.env.PORT ?? 8787);
const HOST = "127.0.0.1";
const UPSTREAM = "flackle.com";
const WS_UPSTREAM = "ws.flackle.com";

const MEDIA_HOSTS = [
  "flackle.com",
  "cdn.flackle.com",
  "cloudflarestorage.com",
  "ytimg.com",
  "picsum.photos",
  "klipy.com",
  "tenor.com",
  "giphy.com",
  "imgur.com",
];

let csrfToken = null;

const mime = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".gif": "image/gif",
  ".webp": "image/webp",
  ".svg": "image/svg+xml",
  ".woff2": "font/woff2",
  ".ttf": "font/ttf",
  ".ico": "image/x-icon",
  ".wasm": "application/wasm",
  ".map": "application/json",
};

function mediaAllowed(hostname) {
  if (!hostname) return false;
  if (hostname === "localhost" || hostname === "127.0.0.1" || hostname.endsWith(".local")) {
    return false;
  }
  if (/^10\./.test(hostname) || /^192\.168\./.test(hostname)) return false;
  if (/^172\.(1[6-9]|2\d|3[01])\./.test(hostname)) return false;
  return true;
}

function proxyMedia(request, response, target) {
  let url;
  try {
    url = new URL(target.replace(/&amp;/g, "&"));
  } catch {
    response.writeHead(400);
    response.end("Bad media URL");
    return;
  }
  if (url.protocol !== "https:" || !mediaAllowed(url.hostname)) {
    response.writeHead(403);
    response.end("Media host not allowed");
    return;
  }
  const headers = { ...request.headers };
  delete headers.host;
  delete headers.cookie;
  delete headers.authorization;
  headers.host = url.host;
  const upstream = https.request(
    {
      host: url.hostname,
      path: `${url.pathname}${url.search}`,
      method: "GET",
      headers,
    },
    (upstreamResponse) => {
      const out = { ...upstreamResponse.headers };
      delete out["set-cookie"];
      delete out["content-security-policy"];
      delete out["access-control-allow-origin"];
      out["cache-control"] = out["cache-control"] ?? "public, max-age=300";
      response.writeHead(upstreamResponse.statusCode ?? 502, out);
      upstreamResponse.pipe(response);
    },
  );
  upstream.on("error", () => {
    response.writeHead(502);
    response.end();
  });
  upstream.end();
}

const server = http.createServer(async (request, response) => {
  const url = new URL(request.url, `http://${request.headers.host}`);
  const { pathname, searchParams } = url;

  if (pathname === "/media") {
    proxyMedia(request, response, searchParams.get("url") ?? "");
    return;
  }

  if (pathname.startsWith("/api/")) {
    const headers = { ...request.headers };
    delete headers.host;
    delete headers.connection;
    delete headers["accept-encoding"];
    headers.host = UPSTREAM;
    headers.origin = `https://${UPSTREAM}`;
    headers.referer = `https://${UPSTREAM}/app`;
    const cookies = (headers.cookie ?? "")
      .split(";")
      .map((part) => part.trim())
      .filter(Boolean)
      .filter((part) => !part.toLowerCase().startsWith("__host-csrf="));
    if (csrfToken) cookies.push(`__Host-csrf=${csrfToken}`);
    if (cookies.length > 0) headers.cookie = cookies.join("; ");
    else delete headers.cookie;
    // The proxy owns the rotating CSRF pair, so always send the matching token.
    if (csrfToken) headers["x-csrf-token"] = csrfToken;

    const upstream = https.request(
      {
        host: UPSTREAM,
        port: 443,
        path: request.url,
        method: request.method,
        headers,
      },
      (upstreamResponse) => {
        const setCookies = Array.isArray(upstreamResponse.headers["set-cookie"])
          ? upstreamResponse.headers["set-cookie"]
          : upstreamResponse.headers["set-cookie"]
            ? [upstreamResponse.headers["set-cookie"]]
            : [];
        for (const cookie of setCookies) {
          const pair = cookie.split(";")[0];
          if (pair.toLowerCase().startsWith("__host-csrf=")) {
            csrfToken = pair.substring(pair.indexOf("=") + 1);
          }
        }
        const browserCookies = setCookies
          .filter((cookie) => !cookie.toLowerCase().startsWith("__host-csrf="))
          .map((cookie) =>
            cookie
              .replace(/;\s*Domain=[^;]+/gi, "")
              .replace(/;\s*Secure/gi, "")
              .replace(/;\s*SameSite=None/gi, "; SameSite=Lax"),
          );

        const outHeaders = { ...upstreamResponse.headers };
        for (const name of [
          "access-control-allow-origin",
          "access-control-allow-credentials",
          "access-control-allow-headers",
          "access-control-allow-methods",
          "access-control-expose-headers",
          "content-security-policy",
          "content-security-policy-report-only",
        ]) {
          delete outHeaders[name];
        }
        delete outHeaders["set-cookie"];
        if (browserCookies.length > 0) outHeaders["set-cookie"] = browserCookies;
        if (csrfToken) outHeaders["x-csrf-token"] = csrfToken;
        outHeaders["cache-control"] = "no-store";

        if (pathname === "/api/ws/url") {
          const chunks = [];
          upstreamResponse.on("data", (chunk) => chunks.push(chunk));
          upstreamResponse.on("end", () => {
            let body = Buffer.concat(chunks).toString("utf8");
            try {
              const parsed = JSON.parse(body);
              parsed.url = `ws://${HOST}:${PORT}/ws`;
              body = JSON.stringify(parsed);
            } catch {
              // Leave unexpected bodies untouched.
            }
            delete outHeaders["content-encoding"];
            outHeaders["content-type"] = "application/json; charset=utf-8";
            outHeaders["content-length"] = Buffer.byteLength(body);
            response.writeHead(upstreamResponse.statusCode ?? 502, outHeaders);
            response.end(body);
          });
          return;
        }

        response.writeHead(upstreamResponse.statusCode ?? 502, outHeaders);
        upstreamResponse.pipe(response);
      },
    );
    upstream.on("error", (error) => {
      response.writeHead(502, { "Content-Type": "application/json" });
      response.end(JSON.stringify({ message: `Upstream error: ${error.message}` }));
    });
    request.pipe(upstream);
    return;
  }

  const safe = path.normalize(pathname).replace(/^(\.\.[/\\])+/, "");
  let filePath = path.join(ROOT, safe);
  try {
    const info = await stat(filePath);
    if (info.isDirectory()) filePath = path.join(filePath, "index.html");
  } catch {
    filePath = path.join(ROOT, "index.html");
  }
  try {
    const info = await stat(filePath);
    response.writeHead(200, {
      "Content-Type": mime[path.extname(filePath)] ?? "application/octet-stream",
      "Content-Length": info.size,
      "Cache-Control": "no-store",
    });
    createReadStream(filePath).pipe(response);
  } catch {
    response.writeHead(404);
    response.end("Not found");
  }
});

const wss = new WebSocketServer({ noServer: true });

server.on("upgrade", (request, socket, head) => {
  const url = new URL(request.url, `http://${HOST}:${PORT}`);
  if (url.pathname !== "/ws") {
    socket.destroy();
    return;
  }
  const upstream = new WebSocket(`wss://${WS_UPSTREAM}/ws${url.search}`, {
    headers: {
      Origin: `https://${UPSTREAM}`,
      "User-Agent": request.headers["user-agent"] ?? "FlackleMobileDev",
    },
  });
  const pending = [];

  wss.handleUpgrade(request, socket, head, (client) => {
    client.on("message", (data, isBinary) => {
      if (upstream.readyState === WebSocket.OPEN) upstream.send(data, { binary: isBinary });
      else pending.push([data, isBinary]);
    });
    upstream.on("open", () => {
      console.log("gateway connected");
      for (const [data, isBinary] of pending) upstream.send(data, { binary: isBinary });
      pending.length = 0;
    });
    upstream.on("message", (data, isBinary) => {
      if (client.readyState === WebSocket.OPEN) client.send(data, { binary: isBinary });
    });
    upstream.on("close", (code, reason) => {
      console.log("gateway closed", code, String(reason ?? ""));
      try {
        client.close(code, reason);
      } catch {
        client.terminate();
      }
    });
    upstream.on("error", (error) => {
      console.log("gateway error", error?.message ?? error);
      client.terminate();
    });
    client.on("close", () => {
      try {
        upstream.close();
      } catch {
        upstream.terminate();
      }
    });
  });
  upstream.on("error", () => socket.destroy());
});

server.listen(PORT, HOST, () => {
  console.log(`Flackle web proxy: http://${HOST}:${PORT} -> https://${UPSTREAM}`);
  console.log(`Gateway tunnel: /ws -> wss://${WS_UPSTREAM}`);
  console.log(`Serving ${ROOT}`);
});
