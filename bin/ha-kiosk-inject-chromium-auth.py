#!/usr/bin/env python3
"""Injecte hassTokens dans le profil Chromium kiosque (même format que Firefox)."""
from __future__ import annotations

import json
import os
import sqlite3
from pathlib import Path

CHR_PROFILE = Path.home() / ".config" / "chromium-kiosk"
FRONT = Path.home() / ".config" / "ha-frontend-tokens.json"
HASS_URL = os.environ.get("HA_URL", "http://192.168.1.51:8123").rstrip("/")
LS_DB = (
    CHR_PROFILE
    / "Default"
    / "Local Storage"
    / "leveldb"
)


def payload_from_file() -> str | None:
    if not FRONT.is_file():
        return None
    data = json.loads(FRONT.read_text(encoding="utf-8"))
    p = data.get("hassTokens")
    return p if isinstance(p, str) and len(p) > 50 else None


def inject_sqlite(db_path: Path, payload: str) -> None:
    # Ancien Chromium : fichier Local Storage SQLite par origine
    origin_db = (
        CHR_PROFILE
        / "Default"
        / "Local Storage"
        / f"http_{HASS_URL.replace('http://', '').replace(':', '_')}.localstorage"
    )
    origin_key = HASS_URL.replace("http://", "").replace(":", "_")
    for path in (origin_db, db_path):
        if not path.parent.exists():
            path.parent.mkdir(parents=True, exist_ok=True)
        con = sqlite3.connect(str(path))
        try:
            con.execute(
                "CREATE TABLE IF NOT EXISTS ItemTable (key TEXT UNIQUE ON CONFLICT REPLACE, value BLOB NOT NULL)"
            )
            con.execute(
                "INSERT OR REPLACE INTO ItemTable(key, value) VALUES (?, ?)",
                ("hassTokens", payload.encode("utf-8")),
            )
            con.commit()
        finally:
            con.close()
    # Nom de fichier alternatif
    alt = CHR_PROFILE / "Default" / "Local Storage" / f"http_{origin_key}.localstorage"
    if alt != origin_db and payload:
        con = sqlite3.connect(str(alt))
        try:
            con.execute(
                "CREATE TABLE IF NOT EXISTS ItemTable (key TEXT UNIQUE ON CONFLICT REPLACE, value BLOB NOT NULL)"
            )
            con.execute(
                "INSERT OR REPLACE INTO ItemTable(key, value) VALUES (?, ?)",
                ("hassTokens", payload.encode("utf-8")),
            )
            con.commit()
        finally:
            con.close()


def main() -> int:
    payload = payload_from_file()
    if not payload:
        print("Pas de ha-frontend-tokens.json", flush=True)
        return 1
    inject_sqlite(LS_DB, payload)
    print("Auth Chromium injectée", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
