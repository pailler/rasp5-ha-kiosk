#!/bin/bash
# Préférences Firefox kiosque : scroll tactile + zoom (pinch / molette).
PROFILE="${1:-$HOME/.mozilla/kiosk-profile}"
mkdir -p "$PROFILE"
cat >"$PROFILE/user.js" <<'USERJS'
user_pref("browser.sessionstore.resume_from_crash", false);
user_pref("toolkit.startup.max_resumed_crashes", -1);
user_pref("full-screen-api.ignore-widgets", false);
user_pref("dom.w3c_touch_events.enabled", 2);
user_pref("layers.async-pan-zoom.enabled", true);
user_pref("apz.allow_zooming", true);
user_pref("apz.allow_double_tap_zooming", true);
user_pref("apz.overscroll.enabled", true);
user_pref("browser.ctrlMouseScroll.enabled", true);
user_pref("general.meta_viewports.enabled", true);
user_pref("general.meta_viewports.zoom", true);
user_pref("general.smoothScroll", true);
user_pref("general.autoScroll", false);
user_pref("mousewheel.default.delta_multiplier_y", 175);
user_pref("mousewheel.with_control.action", 3);
user_pref("mousewheel.with_control.delta_multiplier_y", 200);
user_pref("browser.gesture.pinch.in", "cmd_fullZoomEnlarge");
user_pref("browser.gesture.pinch.out", "cmd_fullZoomReduce");
user_pref("browser.gesture.pinch.threshold", 20);
user_pref("browser.gesture.pinch.latched", false);
user_pref("zoom.minPercent", 50);
user_pref("zoom.maxPercent", 300);
user_pref("privacy.resistFingerprinting", false);
USERJS
