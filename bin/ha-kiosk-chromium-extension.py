#!/usr/bin/env python3
"""Extension Chromium : injecte hassTokens (kiosk OAuth ou jeton long API)."""
from __future__ import annotations

import json
import os
import time
from pathlib import Path

EXT_DIR = Path.home() / ".config" / "ha-kiosk-chromium-ext"
FRONT = Path.home() / ".config" / "ha-frontend-tokens.json"
TOKEN_FILE = Path.home() / ".config" / "ha-api-token"
HASS_URL = os.environ.get("HA_URL", "http://192.168.1.51:8123").rstrip("/")


def payload_from_api_token() -> str | None:
    if not TOKEN_FILE.is_file():
        return None
    access = TOKEN_FILE.read_text(encoding="utf-8").strip().replace("\r", "").replace("\n", "")
    if len(access) < 20:
        return None
    expires = int(time.time() * 1000) + 31_536_000_000
    data = {
        "hassUrl": HASS_URL,
        "clientId": f"{HASS_URL}/",
        "access_token": access,
        "refresh_token": "",
        "expires": expires,
        "expires_in": 31_536_000,
    }
    return json.dumps(data, separators=(",", ":"))


def resolve_payload() -> str | None:
    if os.environ.get("KIOSK_USE_LEGACY_TOKEN", "1") == "1":
        p = payload_from_api_token()
        if p:
            return p
    if FRONT.is_file():
        try:
            data = json.loads(FRONT.read_text(encoding="utf-8"))
            payload = data.get("hassTokens")
            if isinstance(payload, str) and len(payload) > 50:
                return payload
        except (json.JSONDecodeError, OSError):
            pass
    return payload_from_api_token()


def main() -> int:
    payload = resolve_payload()
    if not payload:
        print("Jeton hassTokens introuvable")
        return 1

    EXT_DIR.mkdir(parents=True, exist_ok=True)
    manifest = {
        "manifest_version": 3,
        "name": "HA Kiosk Auth",
        "version": "1",
        "host_permissions": [f"{HASS_URL}/*"],
        "content_scripts": [
            {
                "matches": [f"{HASS_URL}/*"],
                "js": ["inject.js"],
                "run_at": "document_start",
                "world": "MAIN",
            }
        ],
    }
    (EXT_DIR / "manifest.json").write_text(
        json.dumps(manifest, indent=2), encoding="utf-8"
    )
    js = (
        "(() => {\n"
        "  try {\n"
        f"    const v = {json.dumps(payload)};\n"
        "    localStorage.setItem('hassTokens', v);\n"
        "  } catch (e) {}\n"
        "})();\n"
    )
    (EXT_DIR / "inject.js").write_text(js, encoding="utf-8")
    print(str(EXT_DIR))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
