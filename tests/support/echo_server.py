#!/usr/bin/env python3
"""Tiny local HTTP server for the integration tests (stdlib only).

Usage: python echo_server.py [port]        (default 18080, binds 127.0.0.1)

Endpoints
  /echo[?...]            any method (aliases: /get /post /put /patch /delete) -> JSON {method, path, query, headers, body}
  /status/<code>         responds with that status code
  /redirect/<n>          n x 302, finally lands on /echo
  /redirect-307          307 -> /echo (body must be re-sent)
  /delay/<ms>            answers after <ms> milliseconds
  /cookies/set?a=1&b=2   Set-Cookie for every query pair
  /cookies/delete?a      expires the cookie
  /gzip                  gzip encoded JSON
  /bytes/<n>             n bytes of 'x'
  /headers               response with a duplicate header (X-Multi: one / two)
  /upload                multipart/form-data or raw body -> JSON summary:
                         {content_type, size, fields{}, files[{field, filename,
                          content_type, size, sum}]}  or  {raw{size, sum}}
                         (sum = sum of all payload bytes mod 2**32)
  /__shutdown            stops the server
"""
import gzip
from email.parser import BytesParser
from email.policy import HTTP as HTTP_POLICY
import json
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit, parse_qsl


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "EchoTest/1.0"

    def log_message(self, fmt, *args):  # keep test output quiet
        pass

    def _upload_summary(self, body):
        ctype = self.headers.get("Content-Type", "")
        out = {"method": self.command, "content_type": ctype.split(";")[0].strip(), "size": len(body)}
        if ctype.lower().startswith("multipart/form-data"):
            msg = BytesParser(policy=HTTP_POLICY).parsebytes(
                b"Content-Type: " + ctype.encode("latin-1") + b"\r\n\r\n" + body)
            fields, files = {}, []
            for part in msg.iter_parts():
                name = part.get_param("name", header="content-disposition")
                filename = part.get_filename()
                payload = part.get_payload(decode=True) or b""
                if filename is None:
                    fields[name] = payload.decode("utf-8", "replace")
                else:
                    files.append({"field": name, "filename": filename,
                                  "content_type": part.get_content_type(),
                                  "size": len(payload), "sum": sum(payload) & 0xFFFFFFFF})
            out["fields"] = fields
            out["files"] = files
        else:
            out["raw"] = {"size": len(body), "sum": sum(body) & 0xFFFFFFFF}
        return out

    # -- helpers ---------------------------------------------------------
    def _body(self):
        n = int(self.headers.get("Content-Length") or 0)
        return self.rfile.read(n) if n else b""

    def _send(self, status, payload=b"", ctype="application/json", extra=None):
        if isinstance(payload, str):
            payload = payload.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(payload)))
        for k, v in (extra or []):
            self.send_header(k, v)
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(payload)

    def _route(self):
        body = self._body()
        url = urlsplit(self.path)
        path, query = url.path, parse_qsl(url.query, keep_blank_values=True)

        if path == "/__shutdown":
            self._send(200, "bye", "text/plain")
            threading.Thread(target=self.server.shutdown, daemon=True).start()
        elif path in ("/echo", "/get", "/post", "/put", "/patch", "/delete"):  # httpbin-style aliases
            doc = {
                "method": self.command,
                "version": self.request_version,
                "path": path,
                "query": dict(query),
                "headers": {k.lower(): v for k, v in self.headers.items()},
                "body": body.decode("utf-8", "replace"),
            }
            self._send(200, json.dumps(doc, ensure_ascii=False), extra=[("X-Echo", "yes")])
        elif path == "/upload":
            self._send(200, json.dumps(self._upload_summary(body), ensure_ascii=False))
        elif path.startswith("/status/"):
            code = int(path.rsplit("/", 1)[1])
            self._send(code, "status %d" % code, "text/plain")
        elif path.startswith("/redirect/"):
            n = int(path.rsplit("/", 1)[1])
            target = "/echo" if n <= 1 else "/redirect/%d" % (n - 1)
            self._send(302, "", "text/plain", [("Location", target)])
        elif path == "/redirect-307":
            self._send(307, "", "text/plain", [("Location", "/echo")])
        elif path.startswith("/delay/"):
            time.sleep(int(path.rsplit("/", 1)[1]) / 1000.0)
            self._send(200, "late", "text/plain")
        elif path == "/cookies/set":
            extra = [("Set-Cookie", "%s=%s; Path=/" % kv) for kv in query]
            self._send(200, "ok", "text/plain", extra)
        elif path == "/cookies/delete":
            extra = [("Set-Cookie", "%s=; Max-Age=0; Path=/" % k) for k, _ in query]
            self._send(200, "ok", "text/plain", extra)
        elif path == "/gzip":
            raw = json.dumps({"gzipped": True}).encode()
            self._send(200, gzip.compress(raw), extra=[("Content-Encoding", "gzip")])
        elif path.startswith("/bytes/"):
            self._send(200, b"x" * int(path.rsplit("/", 1)[1]), "application/octet-stream")
        elif path == "/headers":
            self._send(200, "ok", "text/plain",
                       [("X-Multi", "one"), ("X-Multi", "two"), ("X-Case", "Value")])
        else:
            self._send(404, "not found", "text/plain")

    do_GET = do_POST = do_PUT = do_PATCH = do_DELETE = do_OPTIONS = do_HEAD = _route


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 18080
    server = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    server.daemon_threads = True
    print("echo server listening on http://127.0.0.1:%d" % port, flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
