#!/usr/bin/env python3
"""
No-cache HTTP server for Flutter Web development.

Serves static files from build/web/ with Cache-Control headers that
prevent the browser from caching responses. Also provides a reverse
proxy for DeepL API to avoid CORS issues in the browser.

Usage:
    python3 serve_nocache.py [port]

    Default port: 8080
    Serves from: build/web/ (relative to this script's location)
"""

import json
import os
import sys
import urllib.request
import urllib.error
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from functools import partial


class NoCacheHTTPRequestHandler(SimpleHTTPRequestHandler):
    """HTTP request handler that disables all caching and proxies DeepL API."""

    def end_headers(self):
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()

    def do_GET(self):
        """Handle GET requests — proxy FRED API or serve static files."""
        if self.path.startswith("/api/fred/"):
            self._proxy_fred()
        else:
            super().do_GET()

    def do_POST(self):
        """Handle POST requests — proxy DeepL API calls."""
        if self.path == "/api/deepl/translate":
            self._proxy_deepl()
        else:
            self.send_error(404)

    def _proxy_deepl(self):
        """Forward translation request to DeepL API."""
        try:
            content_length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_length)
            auth_header = self.headers.get("Authorization", "")

            req = urllib.request.Request(
                "https://api-free.deepl.com/v2/translate",
                data=body,
                headers={
                    "Authorization": auth_header,
                    "Content-Type": "application/json",
                },
                method="POST",
            )

            with urllib.request.urlopen(req, timeout=30) as resp:
                result = resp.read()
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Access-Control-Allow-Origin", "*")
                self.end_headers()
                self.wfile.write(result)
        except urllib.error.HTTPError as e:
            error_body = e.read().decode("utf-8", errors="replace")
            self.send_response(e.code)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(error_body.encode())
        except Exception as e:
            self.send_response(502)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(json.dumps({"error": str(e)}).encode())

    def _proxy_fred(self):
        """Forward GET request to FRED API."""
        try:
            # /api/fred/series/observations?... → https://api.stlouisfed.org/fred/series/observations?...
            fred_path = self.path[len("/api/fred"):]  # e.g. /series/observations?...
            url = f"https://api.stlouisfed.org/fred{fred_path}"

            req = urllib.request.Request(url, method="GET")
            with urllib.request.urlopen(req, timeout=30) as resp:
                result = resp.read()
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Access-Control-Allow-Origin", "*")
                self.end_headers()
                self.wfile.write(result)
        except urllib.error.HTTPError as e:
            error_body = e.read().decode("utf-8", errors="replace")
            self.send_response(e.code)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(error_body.encode())
        except Exception as e:
            self.send_response(502)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(json.dumps({"error": str(e)}).encode())

    def do_OPTIONS(self):
        """Handle CORS preflight requests."""
        if self.path.startswith("/api/"):
            self.send_response(204)
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Access-Control-Allow-Methods", "POST, OPTIONS")
            self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
            self.send_header("Access-Control-Max-Age", "86400")
            self.end_headers()
        else:
            self.send_error(404)


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8080

    # Serve from build/web/ relative to this script
    script_dir = os.path.dirname(os.path.abspath(__file__))
    serve_dir = os.path.join(script_dir, "build", "web")

    if not os.path.isdir(serve_dir):
        print(f"Error: {serve_dir} does not exist.")
        print("Run 'flutter build web --release' first.")
        sys.exit(1)

    handler = partial(NoCacheHTTPRequestHandler, directory=serve_dir)
    server = ThreadingHTTPServer(("0.0.0.0", port), handler)

    print(f"Serving {serve_dir}")
    print(f"  http://localhost:{port}")
    print(f"  DeepL proxy: /api/deepl/translate")
    print(f"  FRED proxy:  /api/fred/*")
    print(f"  Cache-Control: no-cache, no-store, must-revalidate")
    print(f"  Press Ctrl+C to stop")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nServer stopped.")
        server.server_close()


if __name__ == "__main__":
    main()
