---
description: Mise à Jour des Clés Géographiques
---

# UPLANET.refresh.sh

Le nouveau script `UPLANET.refresh.sh` est le cœur de la mise à jour géographique UPlanet côté station.  
Il ne lit plus directement les TiddlyWiki pour les coordonnées ni ne publie via IPNS : il s’appuie sur le cache UPLANET rempli par `TW.refresh.sh` et sur Nostr comme couche d’état.

#### Rôle dans le pipeline

- `PLAYER.refresh.sh` et `TW.refresh.sh`:
  - forcent le GPS de chaque MULTIPASS à partir de `~/.zen/game/nostr/EMAIL/GPS`,
  - mettent à jour `~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_RLAT_RLON/_SLAT_SLON/_LAT_LON/{TW,RSS,_index.html,...}`.
- `UPLANET.refresh.sh`:
  - parcourt ces UMAP locales pour:
    - consolider les métadonnées (G1PUB, SECTOR/REGION, HEX, etc. via `setUMAP_ENV.sh`),
    - générer ou réutiliser les images cartographiques (Umap/Usat, zoom et full) en appelant `Unation/Umap/Usat` (HTML) + `page_screenshot.py`,
    - ajouter les images dans IPFS (`ipfs add`) et obtenir les CIDs.
  - met à jour les profils Nostr UMAP:
    - via `nostr_setup_profile.py` avec:
      - les CIDs des images (`--umap_cid`, `--usat_cid`, `--umap_full_cid`, `--usat_full_cid`),
      - le CID racine de la tuile (`--umaproot`),
      - la date de rafraîchissement (`--umap_updated`),
      - les URL publiques (gateway IPFS) pour profil/bannière.
  - n’utilise plus IPNS UMAP: la “résolution” se fait via les événements Nostr (profils + kind 30023).

#### Points clés actuels

1. **Source de vérité GPS**  
   - Les coordonnées sont définies dans `~/.zen/game/nostr/EMAIL/GPS` (et recopiées dans le tiddler `GPS` par `TW.refresh.sh`).
   - `UPLANET.refresh.sh` travaille uniquement à partir du cache UPLANET (déjà aligné sur ces valeurs Nostr).

2. **Images et IPFS**  
   - Pour chaque UMAP, le script:
     - décide si les images doivent être régénérées (âge > 30/60 jours ou CIDs invalides),
     - appelle `Unation/Umap.html` et `Unation/Usat.html` pour produire des captures,
     - ajoute les images dans IPFS et conserve uniquement les CIDs (pas de fichiers `.jpg` locaux).

3. **Profils Nostr UMAP**  
   - Chaque UMAP a sa clé Nostr dédiée (`UPLANETNAME+LAT/LON`).
   - `UPLANET.refresh.sh` met à jour son profil avec:
     - wallet Ğ1 UMAP,
     - URLs vers le contenu IPFS (HTML + images),
     - métadonnées UPlanet (zencard, tags, visio, etc.).

4. **Intégration avec NOSTR.UMAP.refresh.sh**  
   - `NOSTR.UMAP.refresh.sh` se concentre sur le contenu Nostr (messages, likes, commons) et les journaux kind 30023.  
   - `UPLANET.refresh.sh` se concentre sur la **géographie + médias** (HTML, images, CIDs) et le profil UMAP.

Les anciennes méthodes basées sur `_UPLANET.refresh.sh` (reconstruction complète depuis IPNS, IPNS journalières, NEXTNS, etc.) ont été supprimées ou désactivées au profit de ce modèle :  
**IPFS stocke, Nostr référence.**
