#!/usr/bin/env python3
"""Génère une URL Lovelace signée (authSig) pour le kiosque sans page de login."""
from __future__ import annotations

import json
import os
import sys
import urllib.parse

try:
    import websocket
except ImportError:
    print("Module websocket manquant (python3-websocket)", file=sys.stderr)
    raise SystemExit(1)

HASS_URL = os.environ.get("HA_URL", "http://192.168.1.51:8123").rstrip("/")
KIOSK_PATH = os.environ.get(
    "KIOSK_PATH",
    os.environ.get("KIOSK_LOVELACE_PATH", "/lovelace/ecranmural"),
)
if not KIOSK_PATH.startswith("/"):
    KIOSK_PATH = "/" + KIOSK_PATH
SIG_EXPIRES = int(os.environ.get("KIOSK_AUTHSIG_EXPIRES", "86400"))
TOKEN_FILE = os.environ.get("HA_TOKEN_FILE", os.path.expanduser("~/.config/ha-api-token"))
OAUTH_FILE = os.path.expanduser("~/.config/ha-frontend-tokens.json")
LOGIN_FILE = os.path.expanduser("~/.config/ha-kiosk-login")


def oauth_access_token() -> str | None:
    if not os.path.isfile(OAUTH_FILE):
        return None
    try:
        data = json.loads(open(OAUTH_FILE, encoding="utf-8").read())
        raw = data.get("raw") or {}
        if isinstance(raw.get("access_token"), str) and len(raw["access_token"]) > 20:
            return raw["access_token"]
        hass = data.get("hassTokens")
        if isinstance(hass, str):
            parsed = json.loads(hass)
            tok = parsed.get("access_token")
            if isinstance(tok, str) and len(tok) > 20:
                return tok
    except (json.JSONDecodeError, OSError, TypeError, KeyError):
        return None
    return None


def read_token() -> str:
    if os.environ.get("KIOSK_USE_LEGACY_TOKEN") == "1":
        if os.path.isfile(TOKEN_FILE):
            token = open(TOKEN_FILE, encoding="utf-8").read().strip().replace("\r", "").replace("\n", "")
            if len(token) >= 20:
                return token
        raise FileNotFoundError(TOKEN_FILE)
    # Compte Kiosk : authSig et localStorage doivent utiliser le même jeton.
    if os.path.isfile(LOGIN_FILE):
        kiosk_tok = oauth_access_token()
        if kiosk_tok:
            return kiosk_tok
    if os.path.isfile(TOKEN_FILE):
        token = open(TOKEN_FILE, encoding="utf-8").read().strip().replace("\r", "").replace("\n", "")
        if len(token) >= 20:
            return token
    kiosk_tok = oauth_access_token()
    if kiosk_tok:
        return kiosk_tok
    raise FileNotFoundError(f"Jeton manquant ({TOKEN_FILE} ou {OAUTH_FILE})")


def ws_url(hass_url: str) -> str:
    parsed = urllib.parse.urlparse(hass_url)
    scheme = "wss" if parsed.scheme == "https" else "ws"
    netloc = parsed.netloc or parsed.path
    return f"{scheme}://{netloc}/api/websocket"


def sign_path(hass_url: str, path: str, token: str, expires: int) -> str:
    ws = websocket.create_connection(ws_url(hass_url), timeout=20)
    try:
        ws.recv()
        ws.send(json.dumps({"type": "auth", "access_token": token}))
        auth = json.loads(ws.recv())
        if auth.get("type") != "auth_ok":
            raise RuntimeError(f"Auth WS échouée: {auth}")
        req = {
            "id": 1,
            "type": "auth/sign_path",
            "path": path.split("?")[0],
            "expires": expires,
        }
        ws.send(json.dumps(req))
        while True:
            msg = json.loads(ws.recv())
            if msg.get("id") == 1:
                if not msg.get("success"):
                    raise RuntimeError(msg)
                return msg["result"]["path"]
    finally:
        ws.close()


def main() -> int:
    try:
        token = read_token()
    except FileNotFoundError as e:
        print(str(e), file=sys.stderr)
        return 1
    signed = sign_path(HASS_URL, KIOSK_PATH, token, SIG_EXPIRES)
    if not signed.startswith("/"):
        signed = "/" + signed
    print(f"{HASS_URL}{signed}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
