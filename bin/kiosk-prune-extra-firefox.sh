#!/bin/bash
# Garde une seule fenêtre Firefox kiosque (--no-remote + kiosk-profile).
set -uo pipefail
LOG="${HOME}/kiosk.log"

mapfile -t pids < <("$(dirname "$0")/kiosk-list-main-firefox.sh")
n=${#pids[@]}
[ "$n" -le 1 ] && exit 0

keep="${pids[0]}"
echo "prune: ${n} Firefox kiosque → garde PID ${keep} $(date)" >>"$LOG"
for pid in "${pids[@]}"; do
  [ "$pid" = "$keep" ] && continue
  kill -TERM "$pid" 2>/dev/null || true
done
sleep 2
for pid in "${pids[@]}"; do
  [ "$pid" = "$keep" ] && continue
  kill -9 "$pid" 2>/dev/null || true
done
