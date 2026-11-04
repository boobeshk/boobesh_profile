"""Tiny HTTP service used to demonstrate the secure delivery pipeline (standard library only)."""

import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

VERSION = os.environ.get("APP_VERSION", "dev")


class Handler(BaseHTTPRequestHandler):
    def _send(self, status, body):
        payload = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def do_GET(self):
        if self.path == "/healthz":
            self._send(200, {"status": "ok"})
        elif self.path == "/":
            self._send(200, {"service": "secure-app", "version": VERSION})
        else:
            self._send(404, {"error": "not found"})

    def log_message(self, fmt, *args):
        # One JSON line per request, easy for Loki or CloudWatch to parse.
        print(json.dumps({"client": self.client_address[0], "request": fmt % args}), flush=True)


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
