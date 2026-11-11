# rasp5-ha-kiosk

Kiosque **Home Assistant Lovelace** sur **Raspberry Pi 5** (écran mural tactile) : Firefox ESR plein écran, masquage du bureau, garde-fou RAM, veille selon présence et plage nocturne.

## Problème résolu

Firefox + tableau Lovelace consomment beaucoup de RAM (processus multiprocess). Sur un Pi 5 4 Go, la saturation provoque swap, gel de **Wayfire** et perte du **tactile**. Ce dépôt versionne les scripts et unités systemd déployés sur `rasp5`.

## Fonctions

| Composant | Rôle |
|-----------|------|
| `ha-meteo-kiosk.sh` | Lance Firefox kiosque (`ecranmural`), profil dédié, limite des processus content |
| `firefox-geometry-guard.sh` | Maintient la fenêtre en pleine résolution |
| `hide-desktop-loop.sh` | Empêche le retour du bureau LXDE |
| `kiosk-ram-guard.sh` | Recyclage 4 h, seuils RAM, veille d’urgence |
| `ha-veille-watch.sh` | Veille si absent (HA) ou nuit 01h–07h |
| `veille-ram.sh` / `reveil-kiosk.sh` | Arrêt Firefox + extinction écran / réveil |

Timers système : `check-ram-firefox`, `check-firefox` (toutes les 5 min).

## Prérequis sur le Pi

- Raspberry Pi OS avec session graphique (Wayfire / LXDE-pi)
- `firefox-esr`, `xdotool`, `xrandr`, `curl`
- Accès réseau à Home Assistant
- Fichier `~/.config/ha-api-token` (Bearer, chmod 600) pour la veille présence
- Fichier optionnel `~/.config/ha-kiosk.env` : `HA_ENTITY=device_tracker.xiaomi_13_lite` (présence **WiFi / routeur**, pas le GPS seul)

## Installation rapide

Depuis le PC (adapter l’utilisateur SSH) :

```bash
git clone https://github.com/pailler/rasp5-ha-kiosk.git
cd rasp5-ha-kiosk
./install/install-on-pi.sh rasp5@192.168.1.56
```

Ou sur le Pi après clone dans `~/src/rasp5-ha-kiosk` :

```bash
./install/install-on-pi.sh --local
```

Configurer l’URL Lovelace dans `bin/ha-meteo-kiosk.sh` si besoin, puis placer le jeton HA :

```bash
install -m 600 /dev/stdin ~/.config/ha-api-token   # coller le jeton, Ctrl-D
```

Activer les timers :

```bash
sudo systemctl enable --now check-ram-firefox.timer check-firefox.timer
systemctl --user enable --now hide-desktop.service firefox-geometry-guard.service kiosk-veille-watch.timer
```

## Surveillance

```bash
free -h
tail -f ~/ram-guard.log
systemctl is-active check-ram-firefox.timer
```

## Licence

MIT — utilisation à vos risques sur matériel personnel ; pas d’affiliation avec Home Assistant ou Mozilla.
