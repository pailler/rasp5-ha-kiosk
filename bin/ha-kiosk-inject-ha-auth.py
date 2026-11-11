#!/usr/bin/env python3
"""Injecte le jeton HA dans le profil Firefox (localStorage) pour connexion WebSocket."""
from __future__ import annotations

import json
import os
import sqlite3
import time
from pathlib import Path

HASS_URL = os.environ.get("HA_URL", "http://192.168.1.51:8123").rstrip("/")
TOKEN_FILE = Path.home() / ".config" / "ha-api-token"
PROFILE = Path.home() / ".mozilla" / "ha-kiosk-profile"
ORIGIN_DIR = PROFILE / "storage" / "default" / "http+++192.168.1.51+8123"
LS_DB = ORIGIN_DIR / "ls" / "data.sqlite"
WEBAPPS = PROFILE / "webappsstore.sqlite"


def read_token() -> str:
    raw = TOKEN_FILE.read_text(encoding="utf-8")
    return raw.strip().replace("\r", "").replace("\n", "")


def build_payload(access_token: str) -> str:
    expires = int(time.time() * 1000) + 31_536_000_000
    data = {
        "hassUrl": HASS_URL,
        "clientId": f"{HASS_URL}/",
        "access_token": access_token,
        "refresh_token": "",
        "expires": expires,
        "expires_in": 31_536_000,
    }
    return json.dumps(data, separators=(",", ":"))


def write_ls(db_path: Path, payload: str) -> None:
    db_path.parent.mkdir(parents=True, exist_ok=True)
    con = sqlite3.connect(db_path)
    try:
        con.execute("DROP TABLE IF EXISTS data")
        con.execute(
            "CREATE TABLE data ("
            "key TEXT PRIMARY KEY UNIQUE ON CONFLICT REPLACE, "
            "utf16_length INTEGER NOT NULL DEFAULT 0, "
            "value BLOB NOT NULL)"
        )
        blob = payload.encode("utf-8")
        con.execute(
            "INSERT OR REPLACE INTO data(key, utf16_length, value) VALUES (?, ?, ?)",
            ("hassTokens", len(payload), blob),
        )
        con.commit()
    finally:
        con.close()


def write_webapps(db_path: Path, payload: str) -> None:
    if not db_path.exists():
        return
    con = sqlite3.connect(db_path)
    try:
        con.execute(
            'INSERT OR REPLACE INTO webappsstore2'
            '(originAttributes, originKey, scope, "key", value) '
            "VALUES ('', ?, '', 'hassTokens', ?)",
            (f"{HASS_URL}", payload),
        )
        con.commit()
    finally:
        con.close()


def main() -> int:
    if not TOKEN_FILE.is_file():
        print(f"Jeton manquant: {TOKEN_FILE}")
        return 1
    token = read_token()
    if len(token) < 20:
        print("Jeton HA invalide")
        return 1
    payload = build_payload(token)
    write_ls(LS_DB, payload)
    write_webapps(WEBAPPS, payload)
    print(f"Auth HA injectée ({len(payload)} octets)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
