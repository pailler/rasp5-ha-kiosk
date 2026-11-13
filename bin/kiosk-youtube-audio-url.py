#!/usr/bin/env python3
"""URL audio YouTube (yt-dlp) pour lecture Chromecast / default media receiver."""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys

YTDLP = os.environ.get("KIOSK_YT_DLP", os.path.expanduser("~/bin/yt-dlp"))
YTDLP_TIMEOUT = int(os.environ.get("KIOSK_YT_DLP_TIMEOUT", "120"))


def _yt_dlp_argv() -> list[str]:
    argv = [YTDLP]
    runtime = (os.environ.get("KIOSK_YTDLP_JS_RUNTIME") or "").strip()
    if not runtime:
        for candidate in (
            os.path.expanduser("~/.deno/bin/deno"),
            "/usr/bin/deno",
        ):
            if os.path.isfile(candidate) and os.access(candidate, os.X_OK):
                runtime = f"deno:{candidate}"
                break
    if runtime:
        if ":" not in runtime:
            runtime = f"deno:{runtime}"
        argv.extend(["--js-runtimes", runtime])
    argv.extend(
        [
            "-f",
            "ba/bestaudio/best",
            "-g",
            "--no-playlist",
            "--no-warnings",
        ]
    )
    return argv


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


def resolve_stream_url(video_id: str) -> dict:
    if len(video_id) < 6:
        return {"ok": False, "error": "invalid_video_id"}
    if not os.path.isfile(YTDLP):
        return {"ok": False, "error": "yt_dlp_missing", "path": YTDLP}
    watch = f"https://www.youtube.com/watch?v={video_id}"
    try:
        out = subprocess.check_output(
            _yt_dlp_argv() + [watch],
            text=True,
            timeout=YTDLP_TIMEOUT,
            stderr=subprocess.STDOUT,
        ).strip()
    except subprocess.TimeoutExpired:
        return {"ok": False, "error": "yt_dlp_timeout"}
    except subprocess.CalledProcessError as e:
        detail = (e.output or str(e))[-500:] if e.output else str(e)
        return {"ok": False, "error": "yt_dlp_failed", "detail": detail}
    except OSError as e:
        return {"ok": False, "error": "yt_dlp_spawn", "detail": str(e)}

    stream = out.splitlines()[0].strip() if out else ""
    if not stream.startswith("http"):
        return {"ok": False, "error": "no_stream_url"}
    return {"ok": True, "video_id": video_id, "stream_url": stream}


def main() -> None:
    arg = sys.argv[1] if len(sys.argv) > 1 else ""
    vid = _video_id(arg)
    result = resolve_stream_url(vid)
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
