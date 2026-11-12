#!/bin/bash
# Vérifie les scripts, nettoie, lance 1 Firefox kiosque, affiche le diagnostic.
set -uo pipefail
REPO="${HOME}/src/rasp5-ha-kiosk"
LOG="${HOME}/kiosk.log"

need=(
  kiosk-firefox-remote.sh
  kiosk-firefox-launch-once.sh
  kiosk-prune-extra-firefox.sh
  kiosk-wait-firefox-remote.sh
  ha-kiosk-legacy.sh
  kiosk-fix-duplicate-boot.sh
)
missing=0
for f in "${need[@]}"; do
  if [ ! -x "${HOME}/bin/${f}" ]; then
    echo "MANQUE: ~/bin/${f}"
    missing=1
  fi
done
if [ "$missing" = "1" ] && [ -d "$REPO" ]; then
  echo "→ mise à jour depuis ${REPO}"
  (cd "$REPO" && git pull) && install -m755 "${REPO}"/bin/*.sh "${HOME}/bin/"
fi
for f in "${need[@]}"; do
  [ -x "${HOME}/bin/${f}" ] || { echo "Échec: toujours sans ${f}"; exit 1; }
done

pkill -f 'firefox-esr.*kiosk-profile' 2>/dev/null || true
sleep 2
rm -f /tmp/ha-kiosk-legacy.lock /tmp/kiosk-firefox-launch.lock /tmp/start-kiosk-boot.lock /tmp/kiosk-launch.lock

"${HOME}/bin/kiosk-fix-duplicate-boot.sh" || true

export DISPLAY="${DISPLAY:-:0}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
# shellcheck source=/dev/null
. "${HOME}/bin/kiosk-session-env.sh"

echo "=== doctor $(date) ===" >>"$LOG"
"${HOME}/bin/ha-kiosk-legacy.sh" >>"$LOG" 2>&1 || true

for wait in 15 25 35; do
  sleep "$wait"
  n=$(pgrep -af 'firefox-esr.*kiosk-profile.*--no-remote' 2>/dev/null | wc -l)
  echo "firefox_instances=${n} (après ${wait}s)"
  [ "$n" -ge 1 ] && break
done

n=$(pgrep -af 'firefox-esr.*kiosk-profile.*--no-remote' 2>/dev/null | wc -l)
if [ "$n" -eq 0 ]; then
  echo "ÉCHEC: toujours 0 Firefox — voir tail ~/kiosk.log"
  tail -25 "$LOG"
  exit 1
fi
if [ "$n" -gt 1 ]; then
  "${HOME}/bin/kiosk-prune-extra-firefox.sh" || true
fi
"${HOME}/bin/kiosk-focus-tab.sh" 1 2>/dev/null || true
n=$(pgrep -af 'firefox-esr.*kiosk-profile.*--no-remote' 2>/dev/null | wc -l)
echo "OK: firefox_instances=${n}"
pgrep -af 'firefox-esr.*kiosk-profile.*--no-remote' | head -3
