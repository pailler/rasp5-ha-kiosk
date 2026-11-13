#!/usr/bin/env python3
"""HTTP kiosque : navigation Lovelace (1 onglet) ; /tab2 conservé (déprécié)."""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HOST = os.environ.get("KIOSK_HTTP_HOST", "0.0.0.0")
PORT = int(os.environ.get("KIOSK_HTTP_PORT", "8765"))
TOKEN_PATH = os.path.expanduser("~/.config/kiosk-http-token")
OPEN_SCRIPT = os.path.expanduser("~/bin/kiosk-open-tab2-url.sh")
NAVIGATE_SCRIPT = os.path.expanduser("~/bin/kiosk-ha-navigate.sh")
SESSION_ENV = os.path.expanduser("~/bin/kiosk-session-env.sh")
_AUDIO_SCRIPT = os.path.expanduser("~/bin/kiosk-audio-status.py")
_YT_AUDIO_SCRIPT = os.path.expanduser("~/bin/kiosk-youtube-audio-url.py")
_YT_BOSE_SCRIPT = os.path.expanduser("~/bin/kiosk-youtube-bose-play.py")
_LAST_TAB2: tuple[str, float] = ("", 0.0)


def _audio_json() -> dict:
    if os.path.isfile(_AUDIO_SCRIPT):
        try:
            out = subprocess.check_output(
                ["python3", _AUDIO_SCRIPT],
                text=True,
                timeout=6,
            ).strip()
            data = json.loads(out)
            if isinstance(data, dict):
                return data
        except (subprocess.SubprocessError, json.JSONDecodeError, OSError):
            pass
    return {"ok": False, "volume_percent": 0, "muted": True}


def _audio_apply(body: dict) -> dict:
    if not os.path.isfile(_AUDIO_SCRIPT):
        return {"ok": False, "error": "audio_script_missing"}
    if "muted" in body:
        muted = body["muted"] in (True, "true", "1", 1, "on", "yes")
        cmd = ["python3", _AUDIO_SCRIPT, "mute", "1" if muted else "0"]
    elif "volume_percent" in body or "volume" in body:
        raw = body.get("volume_percent", body.get("volume", 0))
        cmd = ["python3", _AUDIO_SCRIPT, "set", str(raw)]
    else:
        return {"ok": False, "error": "missing_volume_or_muted"}
    try:
        out = subprocess.check_output(cmd, text=True, timeout=8).strip()
        data = json.loads(out)
        return data if isinstance(data, dict) else _audio_json()
    except (subprocess.SubprocessError, json.JSONDecodeError, OSError) as e:
        return {"ok": False, "error": str(e)}


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
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path.rstrip("/") == "/youtube":
            q = urllib.parse.parse_qs(parsed.query)
            vid = (q.get("v") or [""])[0].strip()
            if len(vid) < 6:
                self._json(400, {"error": "missing_v"})
                return
            mute = (q.get("mute") or [""])[0] in ("1", "true", "yes")
            origin_host = os.environ.get("KIOSK_YOUTUBE_ORIGIN_HOST", "127.0.0.1")
            origin = f"http://{origin_host}:{PORT}"
            qs = (
                f"autoplay=1&rel=0&playsinline=1&modestbranding=1"
                f"&origin={urllib.parse.quote(origin, safe='')}"
                f"&widget_referrer={urllib.parse.quote(origin, safe='')}"
            )
            if mute:
                qs += "&mute=1"
            embed = (
                f"https://www.youtube.com/embed/{urllib.parse.quote(vid, safe='')}?{qs}"
            )
            allow = (
                "accelerometer; autoplay; clipboard-write; encrypted-media; "
                "gyroscope; picture-in-picture; web-share; fullscreen"
            )
            body = (
                "<!DOCTYPE html><html><head><meta charset=utf-8>"
                '<meta name="referrer" content="strict-origin-when-cross-origin">'
                "<meta name=viewport content=\"width=device-width,initial-scale=1\">"
                "<style>html,body{margin:0;height:100%;background:#000}iframe{border:0;width:100%;height:100%}</style>"
                f"</head><body><iframe id=yt allow=\"{allow}\" allowfullscreen referrerpolicy=\"strict-origin-when-cross-origin\" "
                f'src="{embed}"></iframe>'
                "<script>document.getElementById('yt').focus();</script>"
                "</body></html>"
            ).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        if parsed.path.rstrip("/") == "/audio":
            token = load_token()
            if token and not authorized(self, token):
                self._json(401, {"error": "unauthorized"})
                return
            self._json(200, _audio_json())
            return
        if parsed.path.rstrip("/") == "/youtube-audio":
            token = load_token()
            if token and not authorized(self, token):
                self._json(401, {"error": "unauthorized"})
                return
            q = urllib.parse.parse_qs(parsed.query)
            vid = (q.get("v") or q.get("id") or [""])[0].strip()
            url_param = (q.get("url") or [""])[0].strip()
            if not vid and url_param:
                import re as _re

                m = _re.search(r"[?&]v=([\w-]{6,})", url_param) or _re.search(
                    r"youtu\.be/([\w-]{6,})", url_param
                )
                vid = m.group(1) if m else ""
            if len(vid) < 6:
                self._json(400, {"error": "missing_v"})
                return
            if not os.path.isfile(_YT_AUDIO_SCRIPT):
                self._json(503, {"error": "youtube_audio_script_missing"})
                return
            try:
                out = subprocess.check_output(
                    ["python3", _YT_AUDIO_SCRIPT, vid],
                    text=True,
                    timeout=130,
                ).strip()
                data = json.loads(out)
                if not isinstance(data, dict):
                    self._json(502, {"error": "invalid_script_output"})
                    return
                code = 200 if data.get("ok") else 502
                self._json(code, data)
            except subprocess.TimeoutExpired:
                self._json(504, {"error": "youtube_audio_timeout"})
            except (subprocess.CalledProcessError, json.JSONDecodeError, OSError) as e:
                self._json(502, {"error": "youtube_audio_failed", "detail": str(e)})
            return
        self._json(404, {"error": "not_found"})

    def do_POST(self) -> None:
        token = load_token()
        if not authorized(self, token):
            self._json(401, {"error": "unauthorized"})
            return

        path = self.path.rstrip("/") or "/"

        if path == "/youtube-bose":
            length = int(self.headers.get("Content-Length", "0"))
            raw = self.rfile.read(length) if length else b"{}"
            if not os.path.isfile(_YT_BOSE_SCRIPT):
                self._json(503, {"error": "youtube_bose_script_missing"})
                return
            try:
                out = subprocess.check_output(
                    ["python3", _YT_BOSE_SCRIPT],
                    input=raw.decode("utf-8") if raw else "{}",
                    text=True,
                    timeout=150,
                ).strip()
                data = json.loads(out)
                if not isinstance(data, dict):
                    self._json(502, {"error": "invalid_script_output"})
                    return
                code = 200 if data.get("ok") else 502
                self._json(code, data)
            except subprocess.TimeoutExpired:
                self._json(504, {"error": "youtube_bose_timeout"})
            except (subprocess.CalledProcessError, json.JSONDecodeError, OSError) as e:
                self._json(502, {"error": "youtube_bose_failed", "detail": str(e)})
            return

        if path == "/audio":
            length = int(self.headers.get("Content-Length", "0"))
            raw = self.rfile.read(length) if length else b"{}"
            try:
                data = json.loads(raw.decode("utf-8"))
            except json.JSONDecodeError:
                self._json(400, {"error": "invalid_json"})
                return
            result = _audio_apply(data)
            code = 200 if result.get("ok") else 502
            self._json(code, result)
            return

        if path == "/navigate":
            length = int(self.headers.get("Content-Length", "0"))
            raw = self.rfile.read(length) if length else b"{}"
            try:
                data = json.loads(raw.decode("utf-8"))
            except json.JSONDecodeError:
                self._json(400, {"error": "invalid_json"})
                return
            rel = (data.get("url") or data.get("path") or "").strip()
            if not rel:
                self._json(400, {"error": "missing_path_or_url"})
                return
            if not os.path.isfile(NAVIGATE_SCRIPT):
                self._json(503, {"error": "navigate_script_missing"})
                return
            nav_env = os.environ.copy()
            nav_env.setdefault("DISPLAY", ":0")
            nav_env.setdefault("WAYLAND_DISPLAY", "wayland-1")
            nav_env.setdefault("XAUTHORITY", os.path.expanduser("~/.Xauthority"))
            lock_path = "/tmp/kiosk-navigate.lock"
            try:
                import fcntl

                lock_fd = os.open(lock_path, os.O_CREAT | os.O_RDWR, 0o644)
                fcntl.flock(lock_fd, fcntl.LOCK_EX)
            except OSError:
                lock_fd = None

            cmd = (
                f". '{SESSION_ENV}' && export DISPLAY=:0 WAYLAND_DISPLAY=wayland-1 "
                f"XAUTHORITY=$HOME/.Xauthority && exec '{NAVIGATE_SCRIPT}' {json.dumps(rel)}"
            )
            try:
                proc = subprocess.Popen(
                    ["/bin/bash", "-lc", cmd],
                    env=nav_env,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.PIPE,
                    start_new_session=True,
                )
                try:
                    _, err = proc.communicate(timeout=120)
                except subprocess.TimeoutExpired:
                    proc.kill()
                    self._json(504, {"error": "navigate_timeout"})
                    return
                if proc.returncode != 0:
                    detail = (err or b"").decode("utf-8", errors="replace")[-400:]
                    self._json(
                        502,
                        {"error": "navigate_failed", "code": proc.returncode, "detail": detail},
                    )
                    return
            finally:
                if lock_fd is not None:
                    try:
                        fcntl.flock(lock_fd, fcntl.LOCK_UN)
                        os.close(lock_fd)
                    except OSError:
                        pass
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
