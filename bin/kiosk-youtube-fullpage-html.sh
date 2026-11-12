#!/bin/bash
# Génère une page locale plein écran (iframe YouTube) — évite youtube.com/watch lourd / blanc.
set -uo pipefail
url="${1:-}"
[ -n "$url" ] || exit 1
out="${2:-/tmp/kiosk-youtube-page.html}"

html_path="$(VID_SOURCE="$url" OUT_PATH="$out" python3 - <<'PY'
import html
import os
import re
import urllib.parse

src = os.environ["VID_SOURCE"].strip()
vid = ""
if "youtu.be/" in src:
    vid = src.split("youtu.be/", 1)[1].split("?")[0].split("/")[0]
else:
    m = re.search(r"[?&]v=([^&]+)", src)
    if m:
        vid = m.group(1)
    m2 = re.search(r"/embed/([^?&/]+)", src)
    if not vid and m2:
        vid = m2.group(1)
vid = vid.strip()
if len(vid) < 6:
    raise SystemExit(1)
mute = "mute=1" in src or "mute=true" in src.lower()
qs = "autoplay=1&rel=0&playsinline=1&modestbranding=1"
if mute:
    qs += "&mute=1"
embed = f"https://www.youtube-nocookie.com/embed/{urllib.parse.quote(vid, safe='')}?{qs}"
out_path = os.environ["OUT_PATH"]
body = f"""<!DOCTYPE html>
<html lang="fr"><head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>YouTube mur</title>
<style>html,body{{margin:0;height:100%;background:#000;overflow:hidden}}
iframe{{border:0;width:100%;height:100%}}</style>
</head><body>
<iframe src="{html.escape(embed, quote=True)}" allow="autoplay; fullscreen; encrypted-media" allowfullscreen></iframe>
</body></html>
"""
open(out_path, "w", encoding="utf-8").write(body)
print(out_path)
PY
)" || exit 1

printf 'file://%s\n' "$html_path"
