#!/usr/bin/env python3
"""HTTP kiosque : navigation Lovelace (1 onglet) ; /tab2 conservé (déprécié)."""
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
NAVIGATE_SCRIPT = os.path.expanduser("~/bin/kiosk-ha-navigate.sh")
SESSION_ENV = os.path.expanduser("~/bin/kiosk-session-env.sh")
_LAST_TAB2: tuple[str, float] = ("", 0.0)


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


def spawn_tab2(url: str, mute_local: bool) -> subprocess.Popen[bytes]:
    """Lance le script dans la session graphique (hérite de l’env du service systemd)."""
    mute = "1" if mute_local else "0"
    cmd = (
        f"set -a; [ -r '{SESSION_ENV}' ] && . '{SESSION_ENV}'; "
        f"set +a; export KIOSK_MUTE_LOCAL={mute}; "
        f"exec '{OPEN_SCRIPT}' {json.dumps(url)}"
    )
    return subprocess.Popen(
        ["/bin/bash", "-lc", cmd],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )


class KioskHandler(BaseHTTPRequestHandler):
    server_version = "kiosk-url-receiver/1.1"

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

        if path == "/navigate":
            length = int(self.headers.get("Content-Length", "0"))
            raw = self.rfile.read(length) if length else b"{}"
            try:
                data = json.loads(raw.decode("utf-8"))
            except json.JSONDecodeError:
                self._json(400, {"error": "invalid_json"})
                return
            rel = (data.get("path") or "").strip()
            if not rel:
                self._json(400, {"error": "missing_path"})
                return
            if not os.path.isfile(NAVIGATE_SCRIPT):
                self._json(503, {"error": "navigate_script_missing"})
                return
            nav_env = os.environ.copy()
            nav_env.setdefault("DISPLAY", ":0")
            nav_env.setdefault("WAYLAND_DISPLAY", "wayland-1")
            nav_env.setdefault("XAUTHORITY", os.path.expanduser("~/.Xauthority"))
            try:
                subprocess.run(
                    [
                        "/bin/bash",
                        "-lc",
                        f". '{SESSION_ENV}' && export DISPLAY=:0 XAUTHORITY=$HOME/.Xauthority && "
                        f"exec '{NAVIGATE_SCRIPT}' {json.dumps(rel)}",
                    ],
                    check=True,
                    timeout=45,
                    env=nav_env,
                )
            except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as e:
                self._json(502, {"error": "navigate_failed", "detail": str(e)})
                return
            self._json(200, {"ok": True, "path": rel})
            return

        if path == "/tab1":
            focus = os.path.expanduser("~/bin/kiosk-focus-tab.sh")
            try:
                subprocess.run(
                    ["/bin/bash", "-lc", f". '{SESSION_ENV}' && exec '{focus}' 1"],
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

        import time as _time
        global _LAST_TAB2
        now = _time.monotonic()
        if url == _LAST_TAB2[0] and (now - _LAST_TAB2[1]) < 8.0:
            self._json(202, {"ok": True, "deduped": True, "url": url})
            return
        _LAST_TAB2 = (url, now)

        lock_path = "/tmp/kiosk-open-tab2.lock"
        try:
            import fcntl

            lock_fd = os.open(lock_path, os.O_CREAT | os.O_RDWR, 0o644)
            try:
                fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                self._json(503, {"error": "busy", "detail": "tab2_in_progress"})
                return
        except OSError as e:
            self._json(503, {"error": "busy", "detail": str(e)})
            return

        try:
            spawn_tab2(url, mute_local)
        except OSError as e:
            self._json(502, {"error": "spawn_failed", "detail": str(e)})
            return

        self._json(202, {"ok": True, "accepted": True, "url": url})


def main() -> None:
    if not os.path.isfile(NAVIGATE_SCRIPT):
        sys.stderr.write(f"missing {NAVIGATE_SCRIPT}\n")
        sys.exit(1)
    if not load_token():
        sys.stderr.write(f"create {TOKEN_PATH} (chmod 600)\n")
        sys.exit(1)
    httpd = ThreadingHTTPServer((HOST, PORT), KioskHandler)
    sys.stderr.write(f"listening on {HOST}:{PORT}\n")
    httpd.serve_forever()


if __name__ == "__main__":
    main()
