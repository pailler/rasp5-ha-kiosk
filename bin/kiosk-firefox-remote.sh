#!/bin/bash
# -remote UNIQUEMENT si l’instance kiosque répond au ping (sinon Firefox ouvre une nouvelle fenêtre).
set -uo pipefail
. "$(dirname "$0")/kiosk-session-env.sh"
PROFILE="${HOME}/.mozilla/kiosk-profile"
CMD="${1:-}"
[ -n "$CMD" ] || exit 1

"${HOME}/bin/kiosk-firefox-kiosk-running.sh" || exit 2
"${HOME}/bin/kiosk-wait-firefox-remote.sh" 3 1 || exit 2

out="$(timeout 8 /usr/bin/firefox-esr --profile "$PROFILE" -remote "$CMD" 2>&1)" || out="failed"
if echo "$out" | grep -qiE 'failed|not running|cannot|no running'; then
  exit 2
fi
exit 0
