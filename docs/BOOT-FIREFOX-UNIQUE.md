# Boot : une seule fenêtre Firefox

## Symptômes

Au démarrage du Pi : **plusieurs fenêtres Firefox**, **gel / écran noir**, ou **plantage** avant d’afficher Home Assistant.

## Causes corrigées

1. `start-kiosk-boot.sh` relançait `ha-kiosk-legacy` **plusieurs fois** (boucle + double appel) pendant que le premier Firefox démarrait encore.
2. `check-firefox` pouvait relancer le kiosque pendant le boot.
3. Onglet 2 créé avant que Firefox soit prêt (`-remote` = **2ᵉ fenêtre** si le ping échoue).
4. `pkill -9 firefox` + suppression `sessionstore` alors que Firefox tournait encore.
5. `ha-kiosk-boot` (systemd) **et** `autostart` LXDE lançaient tous les deux le kiosque (garde-fous `flock` + n’en garder qu’un).
6. Timeout systemd 90 s sur un boot lent → kill au milieu du lancement.

## Comportement attendu

- **Un** `ha-kiosk-legacy` au boot → **un** Firefox `--no-remote`
- Fichier tampon `~/.cache` ou `/run/user/<uid>/kiosk-boot-once` : un seul passage par session
- `check-firefox` : pas avant **20 min** après boot et seulement si `kiosk-boot-once` existe

## Déploiement Pi

```bash
scp bin/*.sh rasp5:~/bin/
sudo cp systemd/usr-local/check-firefox.sh /usr/local/bin/
cp systemd/user/ha-kiosk-boot.service ~/.config/systemd/user/
systemctl --user daemon-reload
sudo systemctl daemon-reload
rm -f /run/user/$(id -u)/kiosk-boot-once   # une fois, si besoin de retester le boot
```

**Un seul déclencheur boot** : soit `systemctl --user enable ha-kiosk-boot.service`, soit une ligne `@~/bin/start-kiosk-boot.sh` dans `lxsession` — **pas les deux**.

```bash
# Vérifier lxsession
grep start-kiosk ~/.config/lxsession/LXDE-pi/autostart
systemctl --user is-enabled ha-kiosk-boot.service
```
