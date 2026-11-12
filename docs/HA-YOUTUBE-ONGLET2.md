# YouTube sur l’onglet 2 (bouton Lovelace)

Permet de coller une URL **YouTube** dans Home Assistant et de la lancer sur le **2ᵉ onglet** du **même Firefox** kiosque (onglet 1 = Home Assistant). On ne lance jamais un second navigateur : uniquement `-remote` sur l’instance démarrée par `ha-kiosk-legacy.sh` (`--no-remote`).

Au boot, l’onglet 2 est créé vide (`about:blank`) et on reste sur l’onglet 1. Le bouton HA charge YouTube **dans l’onglet 2** puis bascule dessus.

Option **Bose** : même vidéo (Chromecast pour le son, vidéo muette sur le mur) — ce n’est pas un 2ᵉ lecteur web sur le Pi.

## 1. Pi (`rasp5`)

Depuis le dépôt à jour :

```bash
./install/install-on-pi.sh --local
```

Créer le jeton HTTP (une seule ligne, gardez-la secrète) :

```bash
TOKEN=$(openssl rand -hex 24)
echo "$TOKEN" | install -m 600 /dev/stdin ~/.config/kiosk-http-token
echo "Jeton pour HA secrets : Bearer $TOKEN"
```

Activer le service (session utilisateur `rasp5`) :

```bash
systemctl --user daemon-reload
systemctl --user enable --now kiosk-url-receiver.service
curl -s -H "Authorization: Bearer $TOKEN" http://127.0.0.1:8765/health
```

Test manuel :

```bash
~/bin/kiosk-open-tab2-url.sh 'https://www.youtube.com/watch?v=jNQXAC9IVRw'
```

## 2. Home Assistant

Dans `secrets.yaml` :

```yaml
rasp5_kiosk_http_authorization: "Bearer VOTRE_JETON_ICI"
```

Copier `home-assistant/packages/kiosk-youtube-onglet2.yaml` dans le dossier `packages/` de HA, recharger les entrées YAML.

Adapter si besoin l’IP du Pi dans `rest_command` (`192.168.1.56`).

## 3. Dashboard

Dans la vue **ecranmural** (ou autre), ajouter une carte : coller le contenu de  
`home-assistant/lovelace/mural-youtube-card.yaml` (éditeur YAML).

Utilisation : saisir l’URL dans le champ → activer **Audio sur la Bose** si besoin → **Lancer sur le mur (onglet 2)**.

Avec **Audio sur la Bose** activé : la vidéo s’affiche sur le mur (onglet 2 Firefox, muet), le son part sur l’enceinte via Chromecast (`media_player.musique_bose_2`, type `youtube`). La multiprise Chromecast est allumée automatiquement si besoin.

Revenir à l’onglet HA (`Revenir à Home Assistant`) réactive le son du Pi.

## 4. Retour onglet HA

- Touche physique / raccourci sur le Pi : `~/bin/kiosk-focus-tab.sh 1`
- Ou carte optionnelle SSH : `kiosk-youtube-onglet2-optional-ssh.yaml`

## Sécurité

- Port **8765** uniquement en LAN ; jeton obligatoire.
- Seules les URLs `youtube.com` / `youtu.be` sont acceptées.
