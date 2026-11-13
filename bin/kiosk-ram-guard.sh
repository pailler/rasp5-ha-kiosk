#!/bin/bash
# Évite le gel du Pi quand la RAM sature (surtout Firefox / Lovelace).
# shellcheck source=kiosk-session-env.sh
. "$(dirname "$0")/kiosk-session-env.sh"
LOG="${HOME}/ram-guard.log"
COOLDOWN=/tmp/kiosk-ram-guard.cooldown
CRITICAL_COOLDOWN=/tmp/kiosk-ram-guard-critical.cooldown
export DISPLAY="${DISPLAY:-:0}"

exec 9>/tmp/kiosk-ram-guard.lock
flock -n 9 || exit 0

log() { echo "$(date '+%F %T') $*" >>"$LOG"; }

CONF="${HOME}/.config/ha-kiosk.env"
[ -r "$CONF" ] && . "$CONF"
GRACE="${KIOSK_RAM_GUARD_GRACE_SEC:-900}"
uptime_s=$(awk '{print int($1)}' /proc/uptime)
if [ "$uptime_s" -lt "$GRACE" ]; then
  log "grace démarrage ${uptime_s}s/${GRACE}s — pas de recycle"
  exit 0
fi
STAMP_BOOT="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/kiosk-boot-once"
if [ ! -f "$STAMP_BOOT" ]; then
  log "boot kiosque pas terminé — pas de recycle"
  exit 0
fi
pgrep -f start-kiosk-boot\\.sh >/dev/null 2>&1 && exit 0
if [ -f /tmp/ha-kiosk-legacy.lock ] || [ -f /tmp/kiosk-open-tab2.lock ]; then
  log "kiosque en cours de lancement — skip"
  exit 0
fi

[ -f "${HOME}/.kiosk-veille-active" ] && exit 0

HOUR=$(date +%H)
HOUR=$((10#$HOUR))
if [ "$HOUR" -ge 1 ] && [ "$HOUR" -lt 7 ]; then
  exit 0
fi

now=$(date +%s)
if [ -f "$COOLDOWN" ]; then
  last=$(cat "$COOLDOWN" 2>/dev/null || echo 0)
  [ $((now - last)) -lt 600 ] && exit 0
fi

mem_avail=$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)
mem_total=$(awk '/MemTotal:/ {print $2}' /proc/meminfo)
ff_rss=0
while read -r rss; do
  [ -n "$rss" ] && ff_rss=$((ff_rss + rss))
done < <(ps -C firefox-esr -o rss= 2>/dev/null)
chr_rss=0
while read -r rss; do
  [ -n "$rss" ] && chr_rss=$((chr_rss + rss))
done < <(ps -C chromium -o rss= 2>/dev/null)
browser_rss=$((ff_rss + chr_rss))

ff_n=$(pgrep -af 'firefox-esr.*kiosk-profile.*--no-remote' 2>/dev/null | wc -l)
if [ "$ff_n" -gt 1 ]; then
  log "${ff_n} Firefox kiosque → élagage"
  "${HOME}/bin/kiosk-prune-extra-firefox.sh" >>"$LOG" 2>&1 || true
  exit 0
fi

if ! "${HOME}/bin/kiosk-ha-browser-active.sh"; then
  pkill -x onboard 2>/dev/null || true
  log "navigateur kiosque absent → relance"
  "${HOME}/bin/kiosk-launch.sh" >>"$LOG" 2>&1
  echo "$now" >"$COOLDOWN"
  exit 0
fi

STAMP="${HOME}/.kiosk-last-recycle"
last_recycle=0
[ -f "$STAMP" ] && last_recycle=$(cat "$STAMP" 2>/dev/null || echo 0)
if [ $((now - last_recycle)) -ge 7200 ]; then
  log "recyclage préventif 4h (ff_rss=${ff_rss}kB)"
  "${HOME}/bin/kiosk-launch.sh" >>"$LOG" 2>&1
  echo "$now" >"$STAMP"
  echo "$now" >"$COOLDOWN"
  exit 0
fi

pct=0
[ "$mem_total" -gt 0 ] && pct=$(( (mem_total - mem_avail) * 100 / mem_total ))

if [ "$mem_avail" -lt 120000 ] || [ "$pct" -ge 94 ]; then
  if [ -f "$CRITICAL_COOLDOWN" ]; then
    lc=$(cat "$CRITICAL_COOLDOWN" 2>/dev/null || echo 0)
    [ $((now - lc)) -lt 300 ] && exit 0
  fi
  log "CRITIQUE avail=${mem_avail}kB pct=${pct}% browser=${browser_rss}kB (ff=${ff_rss} chr=${chr_rss}) → veille+réveil"
  "${HOME}/bin/veille-ram.sh"
  sleep 3
  "${HOME}/bin/reveil-kiosk.sh" >>"$LOG" 2>&1
  echo "$now" >"$CRITICAL_COOLDOWN"
  echo "$now" >"$COOLDOWN"
  echo "$now" >"$STAMP"
  exit 0
fi

chr_limit="${KIOSK_RAM_CHROMIUM_RSS_KB:-1400000}"
if [ "$browser_rss" -gt "$chr_limit" ] || [ "$mem_avail" -lt 280000 ] || [ "$pct" -ge 92 ]; then
  log "seuil browser_rss=${browser_rss}kB avail=${mem_avail}kB pct=${pct}% → recycle kiosque"
  "${HOME}/bin/kiosk-launch.sh" >>"$LOG" 2>&1
  echo "$now" >"$COOLDOWN"
  echo "$now" >"$STAMP"
fi
