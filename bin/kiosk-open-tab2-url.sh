#!/bin/bash
# Ouvre une URL (YouTube, etc.) dans l’onglet 2 Firefox kiosque et affiche cet onglet.
set -euo pipefail
. "$(dirname "$0")/kiosk-session-env.sh"
CONF="${HOME}/.config/ha-kiosk.env"
[ -r "$CONF" ] && . "$CONF"

URL="${1:-}"
LOG="${HOME}/kiosk.log"
PROFILE="${HOME}/.mozilla/kiosk-profile"

[ -n "$URL" ] || { echo "usage: $0 <url>" >&2; exit 1; }

export DISPLAY="${DISPLAY:-:0}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"

pgrep -x firefox-esr >/dev/null || { echo "Firefox inactif" >&2; exit 1; }

python3 - "$URL" "$PROFILE" <<'PY'
import json
import subprocess
import sys
import re

url, profile = sys.argv[1], sys.argv[2]
if not re.match(
    r"^https?://([a-z0-9-]+\.)?(youtube\.com|youtu\.be)/", url, re.I
):
    print("URL YouTube requise (youtube.com ou youtu.be)", file=sys.stderr)
    sys.exit(2)

js = (
    "javascript:(function(){"
    f"var u={json.dumps(url)};"
    "var w=Services.wm.getMostRecentBrowserWindow();"
    "if(!w||!w.gBrowser)return;"
    "var g=w.gBrowser;"
    "while(g.tabs.length<2)g.addTrustedTab('about:blank');"
    "g.tabs[1].linkedBrowser.loadURI(u);"
    "g.selectedTab=g.tabs[1];"
    "})();"
)

cmd = [
    "/usr/bin/firefox-esr",
    "--profile",
    profile,
    "-remote",
    js,
]
r = subprocess.run(cmd, capture_output=True, text=True)
if r.returncode != 0:
    fallback = [
        "/usr/bin/firefox-esr",
        "--profile",
        profile,
        "-new-tab",
        url,
    ]
    subprocess.run(fallback, check=False)
    import os

    subprocess.run(
        [os.path.expanduser("~/bin/kiosk-focus-tab.sh"), "2"],
        check=False,
    )
PY

echo "onglet 2 YouTube: $URL ($(date))" >>"$LOG"
