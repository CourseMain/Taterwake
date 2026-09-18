#!/usr/bin/env python3
"""Preview the exported game on this computer, without any dependencies."""
from __future__ import annotations

import argparse
import errno
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import sys
import webbrowser


class WebGameHandler(SimpleHTTPRequestHandler):
    extensions_map = {
        **SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
        ".pck": "application/octet-stream",
        ".js": "application/javascript",
        ".mjs": "application/javascript",
        ".json": "application/json",
        ".webmanifest": "application/manifest+json",
    }

    def end_headers(self) -> None:
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Resource-Policy", "same-origin")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Service-Worker-Allowed", "/")
        super().end_headers()

    def translate_path(self, path: str) -> str:
        translated = Path(super().translate_path(path)).resolve()
        document_root = Path(self.directory).resolve()
        try:
            translated.relative_to(document_root)
        except ValueError:
            return str(document_root / "__outside_web_root_not_available__")
        return str(translated)

    def list_directory(self, path: str):
        self.send_error(404, "Open the game's index.html instead.")
        return None


def default_directory() -> Path:
    here = Path(__file__).resolve().parent
    return here if (here / "index.html").is_file() else here.parent / "dist" / "web"


def create_server(directory: Path, first_port: int = 8080) -> ThreadingHTTPServer:
    handler = partial(WebGameHandler, directory=str(directory.resolve()))
    attempts = [0] if first_port == 0 else range(first_port, min(65536, first_port + 100))
    for port in attempts:
        try:
            server = ThreadingHTTPServer(("127.0.0.1", port), handler)
            server.daemon_threads = True
            return server
        except OSError as error:
            if error.errno != errno.EADDRINUSE:
                raise
    raise OSError(f"No available local port between {first_port} and {min(65535, first_port + 99)}.")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, default=default_directory(), help="Folder containing index.html")
    parser.add_argument("--port", type=int, default=8080, help="First localhost port to try; default: 8080")
    parser.add_argument("--open", action="store_true", help="Open the game in your default browser")
    args = parser.parse_args(argv)
    if not 0 <= args.port <= 65535:
        parser.error("--port must be between 0 and 65535")
    directory = args.directory.expanduser().resolve()
    if not (directory / "index.html").is_file():
        parser.error(f"No index.html in {directory}. Build with tools/export_web.py first.")
    try:
        with create_server(directory, args.port) as server:
            # Godot's PWA cache keys its start page as index.html, not '/'.
            url = f"http://127.0.0.1:{server.server_port}/index.html"
            print(f"Serving Taterwake at {url}", flush=True)
            print("Keep this terminal open while playing. Press Ctrl+C to stop.", flush=True)
            if args.open:
                webbrowser.open(url)
            try:
                server.serve_forever(poll_interval=0.25)
            except KeyboardInterrupt:
                print("\nLocal preview stopped.")
    except OSError as error:
        print(f"Could not start the local preview: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
