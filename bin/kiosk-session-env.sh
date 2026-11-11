#!/bin/bash
# Variables pour timers systemd → session graphique (Wayfire / XWayland).
_uid="$(id -u)"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/${_uid}}"

# Hériter de la session graphique de l'utilisateur (Wayland + DBus).
if command -v systemctl >/dev/null 2>&1; then
  while IFS= read -r _line; do
    case "$_line" in
      DISPLAY=*|WAYLAND_*=*|XDG_RUNTIME_*=*|DBUS_*=*|XAUTHORITY=*|GDK_*=*|MOZ_*=*|GTK_*=*)
        export "$_line"
        ;;
    esac
  done < <(systemctl --user show-environment 2>/dev/null)
fi

export DISPLAY="${DISPLAY:-:0}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=${XDG_RUNTIME_DIR}/bus}"
# Kiosque stable via XWayland (évite les erreurs Firefox « channel error » hors session).
export MOZ_DISABLE_WAYLAND="${MOZ_DISABLE_WAYLAND:-1}"
