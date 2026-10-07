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
import re
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


def download_path(relative: str) -> str:
    return "games/" + quote(relative, safe="/")


def cue_files(cue_path: Path, root: Path) -> list[dict]:
    """Return the cue itself plus safe, existing files referenced by FILE lines."""
    try:
        text = cue_path.read_text(encoding="utf-8-sig", errors="replace")
    except OSError:
        return []

    members: list[dict] = []
    seen: set[str] = set()
    cue_relative = safe_relative(cue_path, root)
    members.append({
        "name": cue_path.name,
        "file": cue_relative,
        "size": cue_path.stat().st_size,
        "download": download_path(cue_relative),
    })
    seen.add(cue_relative)

    pattern = re.compile(
        r'^\s*FILE\s+(?:"([^"]+)"|(.+?))\s+(?:BINARY|MOTOROLA|WAVE|AIFF|MP3)\s*$',
        re.IGNORECASE | re.MULTILINE,
    )
    root_resolved = root.resolve()
    cue_dir = cue_path.parent.resolve()

    for match in pattern.finditer(text):
        raw_name = (match.group(1) or match.group(2) or "").strip()
        if not raw_name:
            continue

        normalized_name = raw_name.replace("\\", "/")
        if any(part == ".." for part in Path(normalized_name).parts):
            print(f"[Manic Server] ignoring unsafe CUE reference: {cue_relative} -> {raw_name}")
            continue

        candidate = (cue_dir / Path(normalized_name)).resolve()
        try:
            candidate.relative_to(root_resolved)
        except ValueError:
            print(f"[Manic Server] ignoring CUE reference outside game root: {raw_name}")
            continue
        if not candidate.is_file():
            print(f"[Manic Server] missing CUE track: {cue_relative} -> {raw_name}")
            continue

        relative = safe_relative(candidate, root_resolved)
        if relative in seen:
            continue
        seen.add(relative)

        try:
            local_name = candidate.relative_to(cue_dir).as_posix()
        except ValueError:
            local_name = candidate.name

        members.append({
            "name": local_name,
            "file": relative,
            "size": candidate.stat().st_size,
            "download": download_path(relative),
        })

    return members


def scan_games(root: Path) -> list[dict]:
    games: list[dict] = []
    all_files = [path for path in sorted(root.rglob("*")) if path.is_file()]

    cue_bundles: dict[str, list[dict]] = {}
    cue_referenced_files: set[str] = set()
    for path in all_files:
        if path.suffix.lower() != ".cue":
            continue
        relative = safe_relative(path, root)
        members = cue_files(path, root)
        if len(members) > 1:
            cue_bundles[relative] = members
            cue_referenced_files.update(member["file"] for member in members[1:])

    # Some disc dumps have broken/mismatched FILE references. When a CUE
    # exists beside a BIN with the same basename, prefer the CUE entry even
    # if its FILE declaration could not be resolved. Never drop unrelated BINs.
    cue_stems = {str(path.with_suffix("")).casefold() for path in all_files
                 if path.suffix.lower() == ".cue"}

    for path in all_files:
        ext = path.suffix.lower().lstrip(".")
        if not ext or ext not in SUPPORTED_EXTENSIONS:
            continue
        if ext == "bin" and str(path.with_suffix("")).casefold() in cue_stems:
            continue

        relative = safe_relative(path, root)
        parts = Path(relative).parts
        if len(parts) < 2:
            continue

        # A track referenced by a valid CUE belongs to that CUE bundle and should
        # never appear as a second game in the library.
        if relative in cue_referenced_files:
            continue

        game = {
            "id": relative,
            "system": parts[0],
            "title": path.stem,
            "file": relative,
            "size": path.stat().st_size,
            "download": download_path(relative),
        }

        members = cue_bundles.get(relative)
        if members:
            game["files"] = members
            game["size"] = sum(int(member.get("size") or 0) for member in members)

        games.append(game)

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
