#!/usr/bin/env python3
"""Petit serveur HTTP : Home Assistant → ouvre une URL dans l’onglet 2 du kiosque."""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HOST = os.environ.get("KIOSK_HTTP_HOST", "0.0.0.0")
PORT = int(os.environ.get("KIOSK_HTTP_PORT", "8765"))
TOKEN_PATH = os.path.expanduser("~/.config/kiosk-http-token")
OPEN_SCRIPT = os.path.expanduser("~/bin/kiosk-open-tab2-url.sh")


def load_token() -> str:
    if not os.path.isfile(TOKEN_PATH):
        return ""
    with open(TOKEN_PATH, encoding="utf-8") as f:
        return f.read().strip()


def authorized(handler: BaseHTTPRequestHandler, token: str) -> bool:
    if not token:
        return False
    auth = handler.headers.get("Authorization", "")
    if auth == token or auth == f"Bearer {token}":
        return True
    if handler.headers.get("X-Kiosk-Token", "") == token:
        return True
    return False


def valid_youtube_url(url: str) -> bool:
    if not re.match(
        r"^https?://([a-z0-9-]+\.)?(youtube\.com|youtu\.be)/",
        url,
        re.I,
    ):
        return False
    if re.search(r"youtu\.be/", url, re.I):
        return len(url.split("youtu.be/", 1)[-1].split("?")[0].strip("/")) >= 6
    if "list=" in url:
        return True
    m = re.search(r"[?&]v=([^&]+)", url, re.I)
    return bool(m and len(m.group(1)) >= 6)


class KioskHandler(BaseHTTPRequestHandler):
    server_version = "kiosk-url-receiver/1.0"

    def log_message(self, fmt: str, *args) -> None:
        sys.stderr.write(f"kiosk-http: {self.address_string()} {fmt % args}\n")

    def _json(self, code: int, body: dict) -> None:
        payload = json.dumps(body).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def do_GET(self) -> None:
        if self.path.rstrip("/") == "/health":
            self._json(200, {"ok": True})
            return
        self._json(404, {"error": "not_found"})

    def do_POST(self) -> None:
        token = load_token()
        if not authorized(self, token):
            self._json(401, {"error": "unauthorized"})
            return

        path = self.path.rstrip("/") or "/"

        if path == "/tab1":
            env = os.environ.copy()
            env.setdefault("DISPLAY", ":0")
            env.setdefault("WAYLAND_DISPLAY", "wayland-1")
            env.setdefault("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
            focus = os.path.expanduser("~/bin/kiosk-focus-tab.sh")
            try:
                subprocess.run(
                    [focus, "1"],
                    env=env,
                    check=True,
                    timeout=15,
                )
            except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as e:
                self._json(502, {"error": "focus_failed", "detail": str(e)})
                return
            self._json(200, {"ok": True, "tab": 1})
            return

        if path != "/tab2":
            self._json(404, {"error": "not_found"})
            return

        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length) if length else b"{}"
        try:
            data = json.loads(raw.decode("utf-8"))
        except json.JSONDecodeError:
            self._json(400, {"error": "invalid_json"})
            return

        url = (data.get("url") or "").strip()
        if not url or not valid_youtube_url(url):
            self._json(400, {"error": "invalid_youtube_url"})
            return

        mute_local = bool(data.get("mute_local"))

        env = os.environ.copy()
        env.setdefault("DISPLAY", ":0")
        env.setdefault("WAYLAND_DISPLAY", "wayland-1")
        env.setdefault(
            "XDG_RUNTIME_DIR",
            f"/run/user/{os.getuid()}",
        )
        if mute_local:
            env["KIOSK_MUTE_LOCAL"] = "1"
        try:
            subprocess.run(
                [OPEN_SCRIPT, url],
                env=env,
                check=True,
                timeout=60,
            )
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as e:
            self._json(502, {"error": "firefox_failed", "detail": str(e)})
            return

        self._json(200, {"ok": True, "url": url})


def main() -> None:
    if not os.path.isfile(OPEN_SCRIPT):
        sys.stderr.write(f"missing {OPEN_SCRIPT}\n")
        sys.exit(1)
    if not load_token():
        sys.stderr.write(f"create {TOKEN_PATH} (chmod 600)\n")
        sys.exit(1)
    httpd = ThreadingHTTPServer((HOST, PORT), KioskHandler)
    sys.stderr.write(f"listening on {HOST}:{PORT}\n")
    httpd.serve_forever()


if __name__ == "__main__":
    main()
