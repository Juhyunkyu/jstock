#!/usr/bin/env python3
"""
No-cache HTTP server for Flutter Web development.

Serves static files from build/web/ with Cache-Control headers that
prevent the browser from caching responses. This solves the problem
where Playwright MCP's persistent browser profile caches old builds
of main.dart.js and other assets.

Usage:
    python3 serve_nocache.py [port]

    Default port: 8080
    Serves from: build/web/ (relative to this script's location)
"""

import os
import sys
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from functools import partial


class NoCacheHTTPRequestHandler(SimpleHTTPRequestHandler):
    """HTTP request handler that disables all caching."""

    def end_headers(self):
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()


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
    print(f"  Cache-Control: no-cache, no-store, must-revalidate")
    print(f"  Press Ctrl+C to stop")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nServer stopped.")
        server.server_close()


if __name__ == "__main__":
    main()
