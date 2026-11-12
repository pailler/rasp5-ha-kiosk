#!/usr/bin/env python3
"""Lit / règle le volume PulseAudio (sortie HDMI du mur)."""
from __future__ import annotations

import re
import subprocess
import sys


def read_status() -> dict:
    try:
        vol = subprocess.check_output(
            ["pactl", "get-sink-volume", "@DEFAULT_SINK@"],
            text=True,
            timeout=4,
        )
        m = re.search(r"(\d+)%", vol)
        pct = int(m.group(1)) if m else 0
        mute = subprocess.check_output(
            ["pactl", "get-sink-mute", "@DEFAULT_SINK@"],
            text=True,
            timeout=4,
        )
        muted = bool(re.search(r"(?i)\b(yes|oui)\b", mute))
        return {"ok": True, "volume_percent": pct, "muted": muted}
    except (subprocess.SubprocessError, FileNotFoundError, ValueError):
        return {"ok": False, "volume_percent": 0, "muted": True}


def set_volume(percent: int | float, unmute: bool = True) -> dict:
    pct = max(0, min(100, int(round(float(percent)))))
    subprocess.run(
        ["pactl", "set-sink-volume", "@DEFAULT_SINK@", f"{pct}%"],
        check=False,
        timeout=4,
    )
    if unmute:
        subprocess.run(
            ["pactl", "set-sink-mute", "@DEFAULT_SINK@", "0"],
            check=False,
            timeout=4,
        )
    return read_status()


def set_muted(muted: bool) -> dict:
    subprocess.run(
        ["pactl", "set-sink-mute", "@DEFAULT_SINK@", "1" if muted else "0"],
        check=False,
        timeout=4,
    )
    return read_status()


def main() -> int:
    if len(sys.argv) < 2:
        import json

        print(json.dumps(read_status()))
        return 0
    if sys.argv[1] in {"set", "vol", "volume"}:
        if len(sys.argv) < 3:
            print(read_status())
            return 1
        import json

        print(json.dumps(set_volume(sys.argv[2])))
        return 0
    if sys.argv[1] in {"mute"}:
        import json

        print(
            json.dumps(
                set_muted(len(sys.argv) > 2 and sys.argv[2] in ("1", "true", "yes", "on"))
            )
        )
        return 0
    import json

    print(json.dumps(read_status()))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
