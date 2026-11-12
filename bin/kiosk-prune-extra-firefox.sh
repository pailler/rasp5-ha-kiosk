#!/bin/bash
# Garde une seule fenêtre Firefox kiosque (--no-remote + kiosk-profile).
set -uo pipefail
LOG="${HOME}/kiosk.log"

mapfile -t lines < <(pgrep -af 'firefox-esr.*kiosk-profile.*--no-remote' 2>/dev/null || true)
n=${#lines[@]}
[ "$n" -le 1 ] && exit 0

keep_pid=""
for line in "${lines[@]}"; do
  pid=${line%% *}
  [ -n "$pid" ] && keep_pid=$pid && break
done
[ -z "$keep_pid" ] && exit 0

echo "prune: ${n} Firefox kiosque → garde PID ${keep_pid} $(date)" >>"$LOG"
for line in "${lines[@]}"; do
  pid=${line%% *}
  [ "$pid" = "$keep_pid" ] && continue
  kill -TERM "$pid" 2>/dev/null || true
done
sleep 2
for line in "${lines[@]}"; do
  pid=${line%% *}
  [ "$pid" = "$keep_pid" ] && continue
  kill -9 "$pid" 2>/dev/null || true
done
