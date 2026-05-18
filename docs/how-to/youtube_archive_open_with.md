# Archiver YouTube directement dans son uDRIVE (extension "Open With")

**Problème :** Vous voulez sauvegarder une vidéo YouTube dans votre uDRIVE IPFS personnel en un clic depuis Firefox, sans passer par la ligne de commande.
**Solution :** L'extension Firefox "Open With" + la configuration générée à l'installation.

**Durée :** 5 minutes.

---

## Prérequis

- Station Astroport.ONE installée (le fichier de configuration a été généré automatiquement)
- Firefox installé
- yt-dlp installé (`which yt-dlp` doit répondre)

---

## Étape 1 — Installer l'extension Firefox "Open With"

Ouvrez Firefox et installez l'extension :

**[addons.mozilla.org/firefox/addon/open-with](https://addons.mozilla.org/firefox/addon/open-with)**

Ou depuis le terminal :
```bash
firefox "https://addons.mozilla.org/firefox/addon/open-with"
```

---

## Étape 2 — Lire le fichier de configuration généré

L'installation a créé le fichier de configuration pour vous :

```bash
cat ~/.zen/open_with_yt-dlp.txt
```

Ou pour l'ouvrir dans un éditeur graphique :
```bash
xed ~/.zen/open_with_yt-dlp.txt
```

Vous verrez un bloc de configuration JSON décrivant comment appeler yt-dlp avec les bons paramètres pour archiver vers votre uDRIVE.

---

## Étape 3 — Importer la configuration dans l'extension

1. Dans Firefox, cliquez sur l'icône "Open With" dans la barre d'outils (ou allez dans **Extensions → Open With → Options**)
2. Dans la section **Applications**, cliquez **Importer**
3. Copiez-collez le contenu de `~/.zen/open_with_yt-dlp.txt`
4. Cliquez **Sauvegarder**

---

## Utilisation

Sur n'importe quelle page YouTube :

1. Clic droit sur la page → **Open With → yt-dlp uDRIVE** (ou le nom configuré)
2. Le terminal s'ouvre, yt-dlp télécharge la vidéo et la publie sur votre uDRIVE IPFS
3. La vidéo apparaît dans votre uDRIVE (`http://localhost:12345`) et est accessible via son CID IPFS

---

## Vérifier le résultat

```bash
# Voir les dernières vidéos archivées
ls -lt ~/.zen/game/players/$(cat ~/.zen/game/players/.current/.player 2>/dev/null)/uDRIVE/video/ | head -10

# Ou via IPFS
ipfs files ls /$(cat ~/.zen/game/players/.current/.player 2>/dev/null)/uDRIVE/video/
```

---

## En cas de problème

Si le fichier de configuration est absent ou vide :
```bash
# Le régénérer manuellement
bash ~/.zen/Astroport.ONE/open_with_yt-dlp.show.conf.sh > ~/.zen/open_with_yt-dlp.txt
cat ~/.zen/open_with_yt-dlp.txt
```

Si yt-dlp ne télécharge pas (anti-bot YouTube) :
```bash
# Vérifier la config anti-bot
cat ~/.config/yt-dlp/config

# Activer le module anti-bot via astrosystemctl
astrosystemctl local install youtube-antibot
```

---

## Voir aussi

- [how-to/README_YOUTUBE.md](README_YOUTUBE.md) — gestion vidéo avancée (sync auto, webcam, yt-dlp config)
- [explanation/BRO_RAG_PERSONAL.md](../explanation/BRO_RAG_PERSONAL.md) — #BRO peut aussi archiver via `#BRO archive <URL>`
