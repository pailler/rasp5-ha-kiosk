#!/bin/bash
exec 9>/tmp/hide-desktop-loop.lock
flock -n 9 || exit 0
export DISPLAY="${DISPLAY:-:0}"
while true; do
  pkill -f "pcmanfm --desktop" 2>/dev/null
  pkill -x lxpanel 2>/dev/null
  pkill -f wf-panel-pi 2>/dev/null
  pkill -f wfrespawn 2>/dev/null
  sleep 2
done
