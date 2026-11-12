# Stabilité Pi — garde RAM au démarrage

## Symptôme

Écran noir / kiosque qui plante **quelques minutes après le boot** : souvent `kiosk-ram-guard.sh` (timer `check-ram-firefox`) qui **recycle Firefox** trop tôt alors que la RAM est encore en train de monter (Lovelace + onglet 2).

## Correctifs (dépôt)

- **15 min de grâce** après boot (`KIOSK_RAM_GUARD_GRACE_SEC`, défaut 900)
- Pas de recycle si `ha-kiosk-legacy` ou `open-tab2` en cours
- Seuils RAM assouplis (92 %, ~1,2 Go RSS Firefox)
- Timer système : première passe à **20 min**, puis **10 min**
- Timer user `kiosk-ram-guard` **désactivé** à l’install (doublon avec le timer système)
- `check-firefox` : pas de relance les **10 premières minutes** ni pendant `ha-kiosk-legacy`

## Après mise à jour sur le Pi

```bash
sudo cp ~/bin/kiosk-ram-guard.sh /home/rasp5/bin/  # si installé ailleurs
sudo cp /chemin/vers/check-firefox.sh /usr/local/bin/check-firefox.sh
sudo cp systemd/system/check-ram-firefox.timer /etc/systemd/system/
sudo systemctl daemon-reload
systemctl --user disable --now kiosk-ram-guard.timer 2>/dev/null || true
sudo systemctl restart check-ram-firefox.timer
systemctl --user restart kiosk-url-receiver.service
```

Optionnel dans `~/.config/ha-kiosk.env` :

```bash
KIOSK_RAM_GUARD_GRACE_SEC=1200
```
