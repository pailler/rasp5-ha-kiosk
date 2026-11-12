#!/bin/bash
# Dashboard HA plein écran via Chromium (repli si Firefox blanc après YouTube).
set -uo pipefail
. "$(dirname "$0")/kiosk-session-env.sh"
LOG="${HOME}/kiosk.log"
url="${1:-}"
[ -n "$url" ] || exit 1

command -v chromium >/dev/null 2>&1 || exit 1

export DISPLAY="${DISPLAY:-:0}"
export XAUTHORITY="${XAUTHORITY:-${HOME}/.Xauthority}"

CHR_PROFILE="${KIOSK_CHROMIUM_HA_PROFILE:-${HOME}/.config/chromium-ha-kiosk}"
EXT_DIR="${HOME}/.config/ha-kiosk-chromium-ext"
mkdir -p "$CHR_PROFILE"

KIOSK_USE_LEGACY_TOKEN=1 python3 "${HOME}/bin/ha-kiosk-chromium-extension.py" >>"$LOG" 2>&1 || true
KIOSK_USE_LEGACY_TOKEN=1 KIOSK_CHROMIUM_HA_PROFILE="$CHR_PROFILE" \
  python3 "${HOME}/bin/ha-kiosk-inject-chromium-auth.py" >>"$LOG" 2>&1 || true

pkill -x chromium 2>/dev/null || true
pkill -9 -f 'firefox-esr.*kiosk-profile' 2>/dev/null || pkill -9 -x firefox-esr 2>/dev/null || true
sleep 1

CHR=chromium
read -r -a CHR_EXTRA <<<"${KIOSK_CHROMIUM_HA_FLAGS:---ozone-platform=x11 --ignore-gpu-blocklist --use-gl=angle --use-angle=gl}"

CHR_LOAD=()
if [ -f "$EXT_DIR/manifest.json" ]; then
  CHR_LOAD=(--load-extension="$EXT_DIR")
fi

echo "ha-chromium: $url $(date)" >>"$LOG"
nohup "$CHR" --user-data-dir="$CHR_PROFILE" --kiosk --no-first-run --no-default-browser-check \
  --disable-session-crashed-bubble --disable-infobars \
  --check-for-update-interval=31536000 \
  "${CHR_EXTRA[@]}" "${CHR_LOAD[@]}" "$url" </dev/null >>"$LOG" 2>&1 &

for _ in $(seq 1 25); do
  pgrep -x chromium >/dev/null 2>&1 && exit 0
  sleep 1
done
exit 1
