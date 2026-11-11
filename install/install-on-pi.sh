#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KIOSK_USER="${KIOSK_USER:-rasp5}"
KIOSK_HOME="/home/${KIOSK_USER}"

usage() {
  echo "Usage: $0 [user@host | --local]"
  echo "  KIOSK_USER=rasp5 par défaut pour --local"
  exit 1
}

install_local() {
  echo "→ bin/"
  install -d -m 755 "${KIOSK_HOME}/bin"
  for f in "${REPO_ROOT}"/bin/*.sh; do
    install -m 755 "$f" "${KIOSK_HOME}/bin/$(basename "$f")"
  done

  echo "→ /usr/local/bin (wrappers systemd root)"
  sudo install -m 755 "${REPO_ROOT}/systemd/usr-local/check-ram-firefox.sh" /usr/local/bin/check-ram-firefox.sh
  sudo install -m 755 "${REPO_ROOT}/systemd/usr-local/check-firefox.sh" /usr/local/bin/check-firefox.sh
  sudo install -m 755 "${REPO_ROOT}/systemd/usr-local/restart-firefox.sh" /usr/local/bin/restart-firefox.sh
  for f in check-ram-firefox check-firefox; do
    sudo sed -i "s|/home/rasp5|${KIOSK_HOME}|g" "/usr/local/bin/${f}.sh"
  done
  sudo sed -i "s|/home/rasp5|${KIOSK_HOME}|g" /usr/local/bin/restart-firefox.sh

  echo "→ systemd system"
  for u in check-ram-firefox check-firefox; do
    sudo cp "${REPO_ROOT}/systemd/system/${u}.service" /etc/systemd/system/
    sudo cp "${REPO_ROOT}/systemd/system/${u}.timer" /etc/systemd/system/
  done
  sudo systemctl daemon-reload
  sudo systemctl enable --now check-ram-firefox.timer check-firefox.timer

  echo "→ systemd user (${KIOSK_USER})"
  runuser -u "$KIOSK_USER" -- mkdir -p "${KIOSK_HOME}/.config/systemd/user"
  cp "${REPO_ROOT}/systemd/user/hide-desktop.service" "${KIOSK_HOME}/.config/systemd/user/"
  cp "${REPO_ROOT}/systemd/user/firefox-geometry-guard.service" "${KIOSK_HOME}/.config/systemd/user/"
  cp "${REPO_ROOT}/systemd/user/kiosk-veille-watch.service" "${KIOSK_HOME}/.config/systemd/user/"
  cp "${REPO_ROOT}/systemd/user/kiosk-veille-watch.timer" "${KIOSK_HOME}/.config/systemd/user/"
  chown -R "${KIOSK_USER}:${KIOSK_USER}" "${KIOSK_HOME}/.config/systemd/user"
  runuser -u "$KIOSK_USER" -- systemctl --user daemon-reload
  runuser -u "$KIOSK_USER" -- systemctl --user enable --now hide-desktop.service firefox-geometry-guard.service kiosk-veille-watch.timer

  echo "OK. Jeton HA : ${KIOSK_HOME}/.config/ha-api-token (chmod 600)"
}

if [ "${1:-}" = "--local" ]; then
  install_local
elif [ -n "${1:-}" ]; then
  rsync -av --exclude .git "${REPO_ROOT}/" "${1}:~/src/rasp5-ha-kiosk/"
  ssh "$1" "cd ~/src/rasp5-ha-kiosk && KIOSK_USER=\$(whoami) ./install/install-on-pi.sh --local"
else
  usage
fi
