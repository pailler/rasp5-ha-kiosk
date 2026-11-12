#!/bin/bash
# Navigation dans le même onglet Firefox (recharge URL complète).
set -uo pipefail
. "$(dirname "$0")/kiosk-session-env.sh"
CONF="${HOME}/.config/ha-kiosk.env"
[ -r "$CONF" ] && . "$CONF"

PATH_REL="${1:-}"
LOG="${HOME}/kiosk.log"
HA_BASE="${HA_URL:-http://192.168.1.51:8123}"
HA_BASE="${HA_BASE%/}"

[ -n "$PATH_REL" ] || { echo "usage: $0 /local/... | https://..." >&2; exit 1; }

if [[ "$PATH_REL" == http://* ]] || [[ "$PATH_REL" == https://* ]]; then
  target="$PATH_REL"
elif [[ "$PATH_REL" == /* ]]; then
  target="${HA_BASE}${PATH_REL}"
else
  PATH_REL="/${PATH_REL}"
  target="${HA_BASE}${PATH_REL}"
fi

if [[ "$PATH_REL" == *mural-youtube-embed.html* ]] || [[ "$target" == *mural-youtube-embed.html* ]]; then
  yt_target="$(NAV_RAW="$PATH_REL" python3 - <<'PY'
import os, urllib.parse
raw = os.environ.get("NAV_RAW", "")
q = raw.split("?", 1)[1] if "?" in raw else ""
params = urllib.parse.parse_qs(q, keep_blank_values=True)
vid = (params.get("v") or [""])[0]
if len(vid) < 6:
    raise SystemExit(1)
mute = (params.get("mute") or [""])[0] in ("1", "true", "yes")
url = f"https://www.youtube.com/watch?v={vid}"
if mute:
    url += "&mute=1"
print(url)
PY
)" && target="$yt_target"
  echo "navigate: embed → YouTube direct $(date)" >>"$LOG"
fi
if [[ "$PATH_REL" == /lovelace/* ]]; then
  signed="$(KIOSK_USE_LEGACY_TOKEN=1 HA_URL="$HA_BASE" KIOSK_PATH="$PATH_REL" \
    python3 "${HOME}/bin/ha-kiosk-signed-url.py" 2>>"$LOG")" || signed=""
  [[ "$signed" == *authSig=* ]] && target="$signed"
fi

if "${HOME}/bin/kiosk-firefox-goto-url.sh" "$target"; then
  echo "navigate: ${PATH_REL} $(date)" >>"$LOG"
  exit 0
fi

echo "navigate échec: ${PATH_REL} $(date)" >>"$LOG"
exit 1
