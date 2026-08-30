#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


def render_response(path: str, app_name: str, app_version: str) -> tuple[int, str]:
    if path == "/healthz":
        return 200, "ok\n"

    if path == "/":
        return 200, f"{app_name} is running\nversion: {app_version}\n"

    return 404, "not found\n"


def build_handler(app_name: str, app_version: str) -> type[BaseHTTPRequestHandler]:
    class Handler(BaseHTTPRequestHandler):
        server_version = f"{app_name}/{app_version}"

        def _send_text(self, status: int, body: str) -> None:
            encoded = body.encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", str(len(encoded)))
            self.end_headers()
            self.wfile.write(encoded)

        def do_GET(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler API
            status, body = render_response(self.path, app_name, app_version)
            self._send_text(status, body)

        def log_message(self, format: str, *args) -> None:  # noqa: A003 - API name
            return

    return Handler


def main() -> None:
    parser = argparse.ArgumentParser(description="Run the tiny_cicd demo app.")
    parser.add_argument("--host", default=os.getenv("HOST", "0.0.0.0"))
    parser.add_argument("--port", type=int, default=int(os.getenv("PORT", "8080")))
    args = parser.parse_args()

    app_name = os.getenv("APP_NAME", "tiny_cicd")
    app_version = os.getenv("APP_VERSION", "1.0.0")
    handler = build_handler(app_name, app_version)

    server = ThreadingHTTPServer((args.host, args.port), handler)
    print(f"{app_name} listening on http://{args.host}:{args.port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
