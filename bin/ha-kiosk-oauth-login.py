#!/usr/bin/env python3
"""Connexion HA classique (login + mot de passe) → jetons frontend pour Firefox."""
from __future__ import annotations

import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

HASS_URL = os.environ.get("HA_URL", "http://192.168.1.51:8123").rstrip("/")
LOGIN_FILE = os.path.expanduser("~/.config/ha-kiosk-login")
OUT_FILE = os.path.expanduser("~/.config/ha-frontend-tokens.json")


def load_login() -> tuple[str, str]:
    if not os.path.isfile(LOGIN_FILE):
        raise FileNotFoundError(LOGIN_FILE)
    data: dict[str, str] = {}
    for line in open(LOGIN_FILE, encoding="utf-8"):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" in line:
            k, v = line.split("=", 1)
            data[k.strip().upper()] = v.strip()
    user = data.get("KIOSK_USER") or data.get("HA_USER") or data.get("USERNAME")
    password = data.get("KIOSK_PASSWORD") or data.get("HA_PASSWORD") or data.get("PASSWORD")
    if not user or not password:
        raise ValueError("KIOSK_USER et KIOSK_PASSWORD requis dans ha-kiosk-login")
    return user, password


def post(path: str, payload: dict) -> dict:
    req = urllib.request.Request(
        f"{HASS_URL}{path}",
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=20) as resp:
        return json.loads(resp.read().decode())


def login(hass_url: str, username: str, password: str) -> dict:
    client_id = f"{hass_url}/"
    flow = post(
        "/auth/login_flow",
        {
            "client_id": client_id,
            "handler": ["homeassistant", None],
            "redirect_uri": client_id,
        },
    )
    flow_id = flow["flow_id"]
    step = post(
        f"/auth/login_flow/{flow_id}",
        {
            "client_id": client_id,
            "username": username,
            "password": password,
        },
    )
    if step.get("type") != "create_entry":
        raise RuntimeError(f"Login incomplet: {step}")
    result = step.get("result") or {}
    if not result.get("refresh_token"):
        raise RuntimeError(f"Pas de refresh_token: {result}")
    return result


def build_hass_tokens(hass_url: str, result: dict) -> str:
    expires = int(time.time() * 1000) + int(result.get("expires_in", 3600)) * 1000
    data = {
        "hassUrl": hass_url,
        "clientId": f"{hass_url}/",
        "access_token": result.get("access_token", ""),
        "refresh_token": result.get("refresh_token", ""),
        "expires": expires,
        "expires_in": int(result.get("expires_in", 3600)),
    }
    return json.dumps(data, separators=(",", ":"))


def main() -> int:
    try:
        user, password = load_login()
    except (FileNotFoundError, ValueError) as e:
        print(str(e), file=sys.stderr)
        return 2
    try:
        result = login(HASS_URL, user, password)
    except urllib.error.HTTPError as e:
        print(f"Login HTTP {e.code}", e.read().decode()[:200], file=sys.stderr)
        return 1
    except Exception as e:
        print(f"Login échoué: {e}", file=sys.stderr)
        return 1
    payload = build_hass_tokens(HASS_URL, result)
    with open(OUT_FILE, "w", encoding="utf-8") as f:
        json.dump({"hassTokens": payload, "raw": result}, f)
    os.chmod(OUT_FILE, 0o600)
    print("OK", OUT_FILE)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
