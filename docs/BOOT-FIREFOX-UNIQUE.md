# Boot : une seule fenêtre Firefox

## Symptôme

Au démarrage du Pi : **plusieurs fenêtres Firefox**, puis écran noir avec souris.

## Causes corrigées

1. `start-kiosk-boot.sh` relançait `ha-kiosk-legacy` **plusieurs fois** (boucle + double appel) pendant que le premier Firefox démarrait encore.
2. `check-firefox` pouvait relancer le kiosque pendant le boot.
3. Onglet 2 créé avant que Firefox soit prêt (appels `-remote` prématurés).

## Comportement attendu

- **Un** `ha-kiosk-legacy` au boot → **un** Firefox `--no-remote`
- Fichier tampon `~/.cache` ou `/run/user/<uid>/kiosk-boot-once` : un seul passage par session
- `check-firefox` : pas avant **20 min** après boot et seulement si `kiosk-boot-once` existe

## Déploiement Pi

```bash
scp bin/start-kiosk-boot.sh bin/ha-kiosk-legacy.sh rasp5:~/bin/
sudo cp systemd/usr-local/check-firefox.sh /usr/local/bin/
sudo systemctl daemon-reload
rm -f /run/user/$(id -u)/kiosk-boot-once   # une fois, si besoin de retester le boot
systemctl --user restart ha-kiosk-boot.service  # ou re-login / reboot
```
