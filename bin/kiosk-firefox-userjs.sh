#!/bin/bash
# Préférences Firefox kiosque : scroll tactile + zoom (pinch / molette).
PROFILE="${1:-$HOME/.mozilla/kiosk-profile}"
START_URL="${2:-}"
mkdir -p "$PROFILE"

START_URL="$START_URL" PROFILE="$PROFILE" python3 <<'PY'
import html
import os
import pathlib

profile = pathlib.Path(os.environ["PROFILE"])
start_url = os.environ.get("START_URL", "").strip()
lines = [
    'user_pref("browser.sessionstore.resume_from_crash", false);',
    'user_pref("browser.sessionstore.resume_session_once", false);',
    'user_pref("browser.sessionstore.restore_on_demand", false);',
    'user_pref("toolkit.startup.max_resumed_crashes", -1);',
    'user_pref("full-screen-api.ignore-widgets", false);',
    'user_pref("dom.w3c_touch_events.enabled", 2);',
    'user_pref("layers.async-pan-zoom.enabled", true);',
    'user_pref("apz.allow_zooming", true);',
    'user_pref("apz.allow_double_tap_zooming", true);',
    'user_pref("apz.overscroll.enabled", true);',
    'user_pref("browser.ctrlMouseScroll.enabled", true);',
    'user_pref("general.meta_viewports.enabled", true);',
    'user_pref("general.meta_viewports.zoom", true);',
    'user_pref("general.smoothScroll", true);',
    'user_pref("general.autoScroll", false);',
    'user_pref("mousewheel.default.delta_multiplier_y", 175);',
    'user_pref("mousewheel.with_control.action", 3);',
    'user_pref("mousewheel.with_control.delta_multiplier_y", 200);',
    'user_pref("browser.gesture.pinch.in", "cmd_fullZoomEnlarge");',
    'user_pref("browser.gesture.pinch.out", "cmd_fullZoomReduce");',
    'user_pref("browser.gesture.pinch.threshold", 20);',
    'user_pref("browser.gesture.pinch.latched", false);',
    'user_pref("zoom.minPercent", 50);',
    'user_pref("zoom.maxPercent", 300);',
    'user_pref("privacy.resistFingerprinting", false);',
]
if start_url:
    esc = start_url.replace("\\", "\\\\").replace('"', '\\"')
    lines.append(f'user_pref("browser.startup.page", 1);')
    lines.append(f'user_pref("browser.startup.homepage", "{esc}");')
    lines.append('user_pref("startup.homepage_welcome_url", "");')
    lines.append('user_pref("startup.homepage_welcome_url.additional", "");')

(profile / "user.js").write_text("\n".join(lines) + "\n", encoding="utf-8")

if start_url:
    esc = html.escape(start_url, quote=True)
    (profile / "kiosk-start.html").write_text(
        "<!DOCTYPE html><html><head><meta charset=\"utf-8\">"
        f"<meta http-equiv=\"refresh\" content=\"0;url={esc}\">"
        "<title>Chargement Home Assistant…</title></head>"
        "<body><p>Chargement Home Assistant…</p></body></html>",
        encoding="utf-8",
    )
PY
