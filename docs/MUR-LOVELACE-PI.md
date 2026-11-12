# Mur Pi — Home Assistant seul (1 onglet Lovelace)

## Principe

- Le Pi lance **un seul Firefox** sur le dashboard HA (`KIOSK_LOVELACE_PATH`).
- **YouTube** = une **vue Lovelace** (`mur-youtube`) avec iframe embed.
- **Aucun onglet 2**, pas de `kiosk-open-tab2-url.sh` dans le flux normal.
- Boutons HA : scripts `mural_afficher_youtube_lovelace` / `mural_retour_accueil_lovelace` qui appellent `POST /navigate` sur le Pi (même onglet).

## Pi

```bash
cd ~/src/rasp5-ha-kiosk && git pull
install -m755 bin/*.sh ~/bin/
sed -i 's/\r$//' ~/bin/*.sh
# ~/.config/ha-kiosk.env
#   KIOSK_FIREFOX_WAYLAND=0
#   KIOSK_LOVELACE_PATH=/lovelace/dashboard-principal
systemctl --user restart kiosk-url-receiver.service  # après mise à jour receiver
```

## Home Assistant

1. Copier `home-assistant/packages/kiosk_mur_lovelace.yaml` → `config/packages/`.
2. Vérifier `secrets.yaml` : `rasp5_kiosk_http_authorization`.
3. Charger le package (ou redémarrer HA).
4. Ajuster `input_text.mural_lovelace_path_youtube` si votre chemin diffère (`/lovelace/dashboard-principal/mur-youtube`).
5. Copier `home-assistant/www/mural-youtube-embed.html` → `config/www/`.
6. Créer la vue **mur-youtube** (optionnel, voir `home-assistant/lovelace/vue-mur-youtube.yaml`).
6. Coller la carte `mural-lovelace-control-card.yaml` sur l’accueil mural.

## Bose

Identique à avant : toggle *Son sur la Bose*, cast sur `media_player.musique_bose_2`. Ajuster `media_content_type` dans le script si votre intégration exige `youtube`.

## Ancien mode onglet 2

`kiosk_youtube_onglet2.yaml` et `/tab2` restent dans le dépôt mais ne sont plus recommandés. Désactivez le vieux package pour éviter les conflits d’`input_text.mural_youtube_url`.
