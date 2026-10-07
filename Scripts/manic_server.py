#!/usr/bin/env python3
"""
Lightweight Manic Server reference implementation.

Usage:
    python manic_server.py /path/to/Games --port 8080

Expected layout:
    Games/
      PS2/
        Fatal Frame.iso
      PS1/
        Silent Hill.chd
      PSP/
        Street Fighter Alpha 3 MAX.cso

This server is intentionally LAN-only in spirit: it performs no router
configuration and should not be exposed directly to the public internet.
"""

from __future__ import annotations

import argparse
import json
import mimetypes
import os
from pathlib import Path
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from urllib.parse import quote, unquote, urlparse

PROTOCOL_VERSION = 1

SUPPORTED_EXTENSIONS = {
    "3ds", "cia", "cci", "cxi", "3dsx",
    "gba", "gbc", "gb", "nds", "ds", "nes", "fc", "fds", "sfc", "smc",
    "ps1", "chd", "cue", "ccd", "pbp", "bin",
    "iso", "cso", "zso", "elf",
    "md", "gen", "smd", "32x", "gg", "sms", "ms",
    "ss", "n64", "v64", "z64", "vb", "vboy",
    "cdi", "gdi", "zip", "7z", "a26", "a52", "a78", "j64", "jag", "lnx",
    "jar", "dosz", "exe", "com", "bat", "img", "ima", "vhd", "conf",
    "gcm", "gcz", "rvz", "wbfs", "ciso", "wia", "dol", "wad",
    "pce", "sgx", "ngp", "ngc", "ngpc", "d64", "d71", "d81", "g64",
    "adf", "adz", "dms", "fdi", "ipf", "hdf", "lha", "rp9",
    "ws", "wsc", "swf",
}


def safe_relative(path: Path, root: Path) -> str:
    return path.relative_to(root).as_posix()


def scan_games(root: Path) -> list[dict]:
    games: list[dict] = []
    for path in sorted(root.rglob("*")):
        if not path.is_file():
            continue

        ext = path.suffix.lower().lstrip(".")
        if not ext or ext not in SUPPORTED_EXTENSIONS:
            continue

        relative = safe_relative(path, root)
        parts = Path(relative).parts
        if len(parts) < 2:
            # Manic needs an explicit system for ambiguous formats such as ISO/CHD.
            continue

        system = parts[0]
        games.append(
            {
                "id": relative,
                "system": system,
                "title": path.stem,
                "file": relative,
                "size": path.stat().st_size,
                "download": "games/" + quote(relative, safe="/"),
            }
        )
    return games


class ManicHandler(SimpleHTTPRequestHandler):
    server_version = "ManicServer/1"

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/library.json":
            self.send_catalog()
            return
        if parsed.path.startswith("/games/"):
            self.send_game(parsed.path[len("/games/"):])
            return
        self.send_error(404, "Not Found")

    def do_HEAD(self):
        parsed = urlparse(self.path)
        if parsed.path.startswith("/games/"):
            self.send_game(parsed.path[len("/games/"):], head_only=True)
            return
        if parsed.path == "/library.json":
            payload = self.catalog_bytes()
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(payload)))
            self.send_header("Cache-Control", "no-cache")
            self.end_headers()
            return
        self.send_error(404, "Not Found")

    def catalog_bytes(self) -> bytes:
        payload = {
            "version": PROTOCOL_VERSION,
            "name": self.server.display_name,
            "games": scan_games(self.server.games_root),
        }
        return json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")

    def send_catalog(self):
        payload = self.catalog_bytes()
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        self.wfile.write(payload)

    def resolve_game_path(self, encoded_relative: str) -> Path | None:
        relative = unquote(encoded_relative).lstrip("/")
        candidate = (self.server.games_root / relative).resolve()
        root = self.server.games_root.resolve()
        try:
            candidate.relative_to(root)
        except ValueError:
            return None
        if not candidate.is_file():
            return None
        return candidate

    def send_game(self, encoded_relative: str, head_only: bool = False):
        path = self.resolve_game_path(encoded_relative)
        if path is None:
            self.send_error(404, "Game not found")
            return

        size = path.stat().st_size
        content_type = mimetypes.guess_type(path.name)[0] or "application/octet-stream"
        range_header = self.headers.get("Range")

        start = 0
        end = size - 1
        partial = False

        if range_header and range_header.startswith("bytes="):
            try:
                spec = range_header[6:].split(",", 1)[0]
                left, right = spec.split("-", 1)
                if left:
                    start = int(left)
                if right:
                    end = int(right)
                else:
                    end = size - 1
                if start < 0 or end < start or start >= size:
                    raise ValueError
                end = min(end, size - 1)
                partial = True
            except (ValueError, TypeError):
                self.send_response(416)
                self.send_header("Content-Range", f"bytes */{size}")
                self.end_headers()
                return

        length = end - start + 1
        self.send_response(206 if partial else 200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(length))
        self.send_header("Accept-Ranges", "bytes")
        if partial:
            self.send_header("Content-Range", f"bytes {start}-{end}/{size}")
        self.end_headers()

        if head_only:
            return

        with path.open("rb") as handle:
            handle.seek(start)
            remaining = length
            while remaining > 0:
                chunk = handle.read(min(1024 * 1024, remaining))
                if not chunk:
                    break
                self.wfile.write(chunk)
                remaining -= len(chunk)

    def log_message(self, fmt, *args):
        print(f"[Manic Server] {self.address_string()} - {fmt % args}")


class ManicHTTPServer(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, address, handler, games_root: Path, display_name: str):
        super().__init__(address, handler)
        self.games_root = games_root
        self.display_name = display_name


def main():
    parser = argparse.ArgumentParser(description="Serve a ManicEMU remote game library over your local network.")
    parser.add_argument("games_root", type=Path, help="Folder containing system folders such as PS2/, PS1/, PSP/.")
    parser.add_argument("--port", type=int, default=8080, help="TCP port (default: 8080)")
    parser.add_argument("--name", default="Manic Server", help="Library name shown in ManicEMU")
    args = parser.parse_args()

    root = args.games_root.expanduser().resolve()
    if not root.is_dir():
        raise SystemExit(f"Game folder does not exist: {root}")

    server = ManicHTTPServer(("0.0.0.0", args.port), ManicHandler, root, args.name)
    count = len(scan_games(root))
    print(f"Manic Server: {args.name}")
    print(f"Games: {count}")
    print(f"Port: {args.port}")
    print("Open ManicEMU and add: http://<this-phone-LAN-IP>:%d" % args.port)
    print("Do not port-forward this development server to the public internet.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
