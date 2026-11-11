#!/usr/bin/env python3
"""Génère une extension Chromium MV3 qui injecte hassTokens (sans saisie clavier)."""
from __future__ import annotations

import json
import os
from pathlib import Path

EXT_DIR = Path.home() / ".config" / "ha-kiosk-chromium-ext"
FRONT = Path.home() / ".config" / "ha-frontend-tokens.json"
HASS_URL = os.environ.get("HA_URL", "http://192.168.1.51:8123").rstrip("/")
HOST = HASS_URL.replace("https://", "").replace("http://", "")


def main() -> int:
    if not FRONT.is_file():
        print("Pas de ha-frontend-tokens.json")
        return 1
    data = json.loads(FRONT.read_text(encoding="utf-8"))
    payload = data.get("hassTokens")
    if not isinstance(payload, str) or len(payload) < 50:
        print("hassTokens manquant")
        return 1

    EXT_DIR.mkdir(parents=True, exist_ok=True)
    manifest = {
        "manifest_version": 3,
        "name": "HA Kiosk Auth",
        "version": "1",
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
        "    const cur = localStorage.getItem('hassTokens');\n"
        "    if (!cur || cur.length < 50) localStorage.setItem('hassTokens', v);\n"
        "  } catch (e) {}\n"
        "})();\n"
    )
    (EXT_DIR / "inject.js").write_text(js, encoding="utf-8")
    print(str(EXT_DIR))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
