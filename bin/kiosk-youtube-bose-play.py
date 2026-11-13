#!/usr/bin/env python3
"""Extrait l’audio YouTube et lance play_media sur Home Assistant (Chromecast Bose)."""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
AUDIO_URL_SCRIPT = os.path.join(SCRIPT_DIR, "kiosk-youtube-audio-url.py")
HA_TOKEN_PATH = os.path.expanduser("~/.config/ha-api-token")
HA_ENV_PATH = os.path.expanduser("~/.config/ha-kiosk.env")
DEFAULT_ENTITY = "media_player.musique_bose_2"


def _load_ha_url() -> str:
    url = (os.environ.get("HA_URL") or os.environ.get("KIOSK_HA_URL") or "").strip()
    if url:
        return url.rstrip("/")
    if os.path.isfile(HA_ENV_PATH):
        with open(HA_ENV_PATH, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line.startswith("HA_URL="):
                    return line.split("=", 1)[1].strip().rstrip("/")
    return "http://192.168.1.51:8123"


def _ha_token() -> str:
    if os.path.isfile(HA_TOKEN_PATH):
        return open(HA_TOKEN_PATH, encoding="utf-8").read().strip()
    return (os.environ.get("HA_API_TOKEN") or "").strip()


def _video_id(raw: str) -> str:
    raw = (raw or "").strip()
    if re.fullmatch(r"[\w-]{6,}", raw):
        return raw
    m = re.search(r"[?&]v=([\w-]{6,})", raw)
    if m:
        return m.group(1)
    m = re.search(r"youtu\.be/([\w-]{6,})", raw)
    if m:
        return m.group(1)
    return ""


def _stream_for_video(video_id: str) -> dict:
    if not os.path.isfile(AUDIO_URL_SCRIPT):
        return {"ok": False, "error": "audio_script_missing"}
    try:
        out = subprocess.check_output(
            ["python3", AUDIO_URL_SCRIPT, video_id],
            text=True,
            timeout=130,
        ).strip()
        data = json.loads(out)
        return data if isinstance(data, dict) else {"ok": False, "error": "invalid_json"}
    except subprocess.TimeoutExpired:
        return {"ok": False, "error": "audio_timeout"}
    except (subprocess.CalledProcessError, json.JSONDecodeError, OSError) as e:
        return {"ok": False, "error": "audio_failed", "detail": str(e)}


def _ha_service(
    ha_url: str, token: str, domain: str, service: str, payload: dict
) -> dict:
    body = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        f"{ha_url}/api/services/{domain}/{service}",
        data=body,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=45) as resp:
            raw = resp.read().decode("utf-8")
            return {"ok": True, "status": resp.status, "body": raw[:400]}
    except urllib.error.HTTPError as e:
        detail = e.read().decode("utf-8", errors="replace")[:400]
        return {"ok": False, "error": f"ha_http_{e.code}", "detail": detail}
    except urllib.error.URLError as e:
        return {"ok": False, "error": "ha_unreachable", "detail": str(e.reason)}


def _entity_state(ha_url: str, token: str, entity_id: str) -> str:
    req = urllib.request.Request(
        f"{ha_url}/api/states/{urllib.parse.quote(entity_id, safe='')}",
        headers={"Authorization": f"Bearer {token}"},
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            return str(data.get("state", ""))
    except (urllib.error.URLError, json.JSONDecodeError, KeyError):
        return ""


def play_youtube_on_cast(
    video_id: str,
    entity_id: str = DEFAULT_ENTITY,
    volume_percent: int = 55,
) -> dict:
    vid = _video_id(video_id)
    if len(vid) < 6:
        return {"ok": False, "error": "invalid_video_id"}

    token = _ha_token()
    if not token:
        return {"ok": False, "error": "ha_token_missing"}

    ha_url = _load_ha_url()
    stream = _stream_for_video(vid)
    if not stream.get("ok"):
        return {"ok": False, "error": "stream_unavailable", "detail": stream}

    volume = max(0.0, min(1.0, volume_percent / 100.0))
    for domain, service, payload in (
        ("media_player", "turn_on", {"entity_id": entity_id}),
        (
            "media_player",
            "volume_set",
            {"entity_id": entity_id, "volume_level": round(volume, 2)},
        ),
        (
            "media_player",
            "volume_mute",
            {"entity_id": entity_id, "is_volume_muted": False},
        ),
        (
            "media_player",
            "play_media",
            {
                "entity_id": entity_id,
                "media_content_type": "music",
                "media_content_id": stream["stream_url"],
            },
        ),
        ("media_player", "media_play", {"entity_id": entity_id}),
    ):
        step = _ha_service(ha_url, token, domain, service, payload)
        if not step.get("ok"):
            return {
                "ok": False,
                "error": f"{domain}.{service}_failed",
                "detail": step,
            }

    state = _entity_state(ha_url, token, entity_id)
    return {
        "ok": state == "playing",
        "video_id": vid,
        "entity_id": entity_id,
        "player_state": state,
        "used_default_media_receiver": True,
    }


def main() -> None:
    raw = sys.stdin.read().strip() if not sys.argv[1:] else ""
    if sys.argv[1:]:
        if sys.argv[1].startswith("{"):
            raw = sys.argv[1]
        else:
            vid = _video_id(sys.argv[1])
            vol = int(sys.argv[2]) if len(sys.argv) > 2 else 55
            ent = sys.argv[3] if len(sys.argv) > 3 else DEFAULT_ENTITY
            result = play_youtube_on_cast(vid, ent, vol)
            print(json.dumps(result, ensure_ascii=False))
            return
    try:
        data = json.loads(raw) if raw else {}
    except json.JSONDecodeError:
        data = {"video_id": raw}
    vid = data.get("video_id") or data.get("id") or data.get("url") or ""
    entity = (data.get("entity_id") or DEFAULT_ENTITY).strip()
    vol = int(data.get("volume_percent", data.get("volume", 55)))
    result = play_youtube_on_cast(vid, entity, vol)
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
