#!/bin/bash
# Évite le gel du Pi quand la RAM sature (surtout Firefox / Lovelace).
# shellcheck source=kiosk-session-env.sh
. "$(dirname "$0")/kiosk-session-env.sh"
LOG="${HOME}/ram-guard.log"
COOLDOWN=/tmp/kiosk-ram-guard.cooldown
CRITICAL_COOLDOWN=/tmp/kiosk-ram-guard-critical.cooldown
export DISPLAY="${DISPLAY:-:0}"

log() { echo "$(date '+%F %T') $*" >>"$LOG"; }

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

if ! pgrep -x firefox-esr >/dev/null; then
  log "firefox absent → relance kiosque"
  "${HOME}/bin/ha-meteo-kiosk.sh" >>"$LOG" 2>&1
  echo "$now" >"$COOLDOWN"
  exit 0
fi

STAMP="${HOME}/.kiosk-last-recycle"
last_recycle=0
[ -f "$STAMP" ] && last_recycle=$(cat "$STAMP" 2>/dev/null || echo 0)
if [ $((now - last_recycle)) -ge 7200 ]; then
  log "recyclage préventif 4h (ff_rss=${ff_rss}kB)"
  "${HOME}/bin/ha-meteo-kiosk.sh" >>"$LOG" 2>&1
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
  log "CRITIQUE avail=${mem_avail}kB pct=${pct}% ff=${ff_rss}kB → veille+réveil"
  "${HOME}/bin/veille-ram.sh"
  sleep 3
  "${HOME}/bin/reveil-kiosk.sh" >>"$LOG" 2>&1
  echo "$now" >"$CRITICAL_COOLDOWN"
  echo "$now" >"$COOLDOWN"
  echo "$now" >"$STAMP"
  exit 0
fi

if [ "$ff_rss" -gt 950000 ] || [ "$mem_avail" -lt 450000 ] || [ "$pct" -ge 82 ]; then
  log "seuil ff_rss=${ff_rss}kB avail=${mem_avail}kB pct=${pct}% → recycle firefox"
  "${HOME}/bin/ha-meteo-kiosk.sh" >>"$LOG" 2>&1
  echo "$now" >"$COOLDOWN"
  echo "$now" >"$STAMP"
fi
