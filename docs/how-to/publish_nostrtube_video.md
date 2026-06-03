# Publier une vidéo sur NostrTube

**Problème :** vous avez une vidéo locale (ou une URL YouTube) et souhaitez la publier sur NostrTube via votre station Astroport.
**Solution :** uploader sur IPFS via UPassport et publier l'événement NOSTR kind 21/22.

---

## Prérequis

- Station Astroport.ONE opérationnelle avec IPFS actif
- UPassport API accessible (`http://localhost:54321`)
- Votre MULTIPASS créé (clé NOSTR disponible)
- Fichier vidéo : MP4/WebM, résolution max recommandée 1080p

---

## Option A — Depuis YouTube (automatique)

```bash
# Télécharger et publier une vidéo YouTube sur votre uDRIVE NOSTR
cd ~/.zen/Astroport.ONE
./ASTROBOT/Z/G1CopierYoutube.sh "https://www.youtube.com/watch?v=XXXXXXXXXXX" "email@exemple.fr"
```

Le script :
1. Télécharge la vidéo avec yt-dlp
2. L'ajoute sur IPFS (`ipfs add`)
3. Publie un événement kind 21 (vidéo courte) ou kind 22 (live) sur le relay strfry

---

## Option B — Upload via API UPassport

### 1. Uploader le fichier vidéo

```bash
curl -X POST http://localhost:54321/api/upload \
  -F "file=@mavideo.mp4" \
  -F "email=email@exemple.fr" \
  -F "title=Titre de ma vidéo" \
  -F "description=Description de la vidéo"
```

### 2. Récupérer le CID IPFS retourné

```json
{
  "cid": "QmXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
  "url": "http://localhost:8080/ipfs/QmXXX"
}
```

### 3. Vérifier la publication NOSTR

```bash
# Chercher les événements kind 21 publiés par votre clé
cd ~/.zen/strfry
./strfry scan '{"kinds":[21],"authors":["<votre-npub-hex>"],"limit":5}'
```

---

## Option C — Publication manuelle (kind 21)

```bash
# Construire et publier l'événement NOSTR manuellement
NSEC=$(cat ~/.zen/game/players/email@exemple.fr/.nostr/secret.nostr)
CID="QmXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

# Via UPassport
curl -X POST http://localhost:54321/nostr/publish \
  -H "Content-Type: application/json" \
  -d "{
    \"kind\": 21,
    \"content\": \"Titre de ma vidéo\",
    \"tags\": [
      [\"url\", \"http://localhost:8080/ipfs/$CID\"],
      [\"m\", \"video/mp4\"]
    ]
  }"
```

---

## Résultat attendu

La vidéo apparaît dans NostrTube (`http://localhost:12345/nostrtube`) et est accessible à tous les nœuds de la constellation via son CID IPFS.

---

## Voir aussi

- [README_YOUTUBE.md](README_YOUTUBE.md) — gestion avancée YouTube + yt-dlp
- [NOSTR_EVENTS_REFERENCE.md](../reference/NOSTR_EVENTS_REFERENCE.md) — kinds 21/22 et leurs champs
- [explanation/README.NostrTube.md](../explanation/README.NostrTube.md) — vision de la plateforme
