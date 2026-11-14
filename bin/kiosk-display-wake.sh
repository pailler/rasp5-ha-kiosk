#!/bin/bash
# Réveil sortie vidéo sur Pi + Wayfire/XWayland (DPMS souvent absent sur XWAYLAND0).
export DISPLAY="${DISPLAY:-:0}"
xset dpms force on 2>/dev/null || true
xset s reset 2>/dev/null || true
xset s off 2>/dev/null || true
xset -dpms 2>/dev/null || true
vcgencmd display_power 1 2>/dev/null || true
xrandr --query 2>/dev/null | sed -n 's/^\([^ ]*\) connected.*/\1/p' | while read -r out; do
  [ -n "$out" ] || continue
  xrandr --output "$out" --auto 2>/dev/null || true
  xrandr --output "$out" --brightness 1 2>/dev/null || true
done