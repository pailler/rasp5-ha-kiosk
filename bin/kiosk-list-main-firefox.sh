#!/bin/bash
# PIDs du processus principal Firefox kiosque (pas bash/grep, pas contentproc orphelins).
set -uo pipefail
while read -r pid args; do
  [ -z "$pid" ] && continue
  case "$args" in
    *kiosk-profile*)
      case "$args" in
        *--no-remote*|*--profile*) echo "$pid" ;;
      esac
      ;;
  esac
done < <(ps -C firefox-esr -o pid=,args= 2>/dev/null)
