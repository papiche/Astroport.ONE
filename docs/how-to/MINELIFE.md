# MineLife — Guide d'utilisation de l'interface WoTx2

Interface : `UPlanet/earth/minelife.html`

> Pour la philosophie et le "pourquoi", voir [explanation/minelife_wikipedia_wot.md](../explanation/minelife_wikipedia_wot.md).
> Pour les schémas complets des Kinds NOSTR, voir [reference/NOSTR_EVENTS_REFERENCE.md](../reference/NOSTR_EVENTS_REFERENCE.md).

---

## Hiérarchie de confiance (Trust Levels)

Chaque skill est validé à un niveau de confiance qui détermine si le joueur peut l'utiliser comme ingrédient d'un craft composite :

| Source | Trust Level | Kind émis |
|--------|-------------|-----------|
| Oracle certifié (Master WoT) | 3 | Kind 30503 |
| Attestation P2P (pair X1+ du skill) | 2 | Kind 30502 |
| Aspiration / auto-déclaration | 1 | Kind 30501 |

La définition d'un Permit (Kind 30500) fixe un seuil `minTrust` par ingrédient. Le bouton **Craftr** ne s'active que si chaque skill de la recette atteint ce seuil.

---

## Comment créer un nouveau Permit (recette de craft)

Un **Permit** est la définition d'une compétence composite — ses ingrédients requis, leur niveau minimal, et les ressources de formation associées. Seuls les Maîtres WoT (pubkeys autorisées sur le relay) peuvent en publier.

### 1. Ouvrir l'éditeur de craft

- Dans MineLife, cliquer sur **✏️ Éditer** (topbar) pour activer le mode édition
- Puis cliquer sur **⚒ Nouveau craft**

### 2. Remplir la grille WYSIWYG

```
ÉDITEUR — Clic & Drag
┌────────────────────┬──────────────────────────┬──────────────────┐
│   PALETTE          │     GRILLE 3×3           │   RESSOURCES     │
│   (skills dispo)   │                          │                  │
│                    │  linux x1 │docker x1│    │  📄 devops.pdf   │
│  [🐧 linux  x1]   │  ─────────┼─────────┤    │  🎬 tuto.mp4    │
│  [🐋 docker x1]   │           │         │    │                  │
│  [📜 bash   x1]   │  ─────────┼─────────┤    │  [📁 Mes médias] │
│                    │           │         │    │                  │
└────────────────────┴──────────────────────────┴──────────────────┘
```

**Interactions :**
- **Glisser** un skill de la palette → slot de la grille
- **Boutons `+`/`−`** sur un slot → ajuster le niveau requis (1 à 5)
- **Double-clic** sur un slot rempli → vider le slot
- **Glisser** un média depuis "Mes médias" → zone Ressources

### 3. Ajouter des ressources de formation (optionnel)

Cliquer **[📁 Mes médias]** pour ouvrir le navigateur NOSTR du joueur (Kind 21/22/1063/1222/30023).
Glisser un fichier vers la zone Ressources.

### 4. Publier

Cliquer **[☁ Publier]** → publie un Kind 30500 sur le relay strfry.
Si le `d` tag existe déjà (même `d`), l'event est mis à jour (Replaceable Event NIP-33).

---

## Comment importer une URL avec l'IA (Import URL → Craft IA)

L'éditeur de craft intègre un champ **Import URL** :

1. Ouvrir l'éditeur (bouton ⚒ ou "Nouveau craft")
2. Coller une URL (Instructables, Wikipedia, tutoriel…)
3. Cliquer **🤖 IA** → BRO analyse la page et propose automatiquement :
   - Nom du craft
   - Icône
   - Ingrédients (skills + niveaux)
4. Ajuster dans la grille WYSIWYG
5. Cliquer **[☁ Publier]**

**Exemple de réponse BRO :**
```json
{
  "name": "Arduino TV-B-Gone",
  "icon": "📺",
  "ingredients": [
    {"skill": "arduino",           "level": 1},
    {"skill": "electronique_base", "level": 1},
    {"skill": "soudure",           "level": 1}
  ]
}
```

---

## Comment explorer les crafts disponibles

L'onglet **Explorer** liste tous les Permits (Kind 30500) publiés sur le relay local.

Chaque card affiche :
- Nom du permis, icône, description
- Ingrédients requis et leur niveau minimal
- Bouton **📩 Aspirer** (si le joueur ne possède pas encore ce skill)

---

## Comment soumettre une demande X1 (Aspiration)

Pour exprimer publiquement qu'on veut apprendre un skill :

1. Dans l'onglet **Explorer**, repérer le Permit souhaité
2. Cliquer **📩 Aspirer à ce skill** → publie un Kind 30501
3. Le bouton **📩 Contacter les porteurs** affiche les détenteurs N² du skill
4. Envoyer un DM Kind 4 directement depuis l'interface pour organiser une session

---

## Comment valider un apprenti (émettre une attestation)

**Règle A — Par réaction (3 validations suffisent) :**

1. Dans l'onglet **Explorer**, localiser la demande X1 d'un apprenti (Kind 30501)
2. Cliquer **👍 Valider** → publie un Kind 7 avec `content: "+"` (réaction NIP-25)
3. Quand 3 pairs distincts ont validé, l'apprenti peut auto-signer son Kind 30503

**Règle B — Par adoubement direct (si vous êtes X1+ du skill) :**

1. Cliquer sur la demande Kind 30501 de l'apprenti
2. Cliquer **🏅 Adouber directement** → publie un Kind 30502
3. L'apprenti peut immédiatement auto-signer son Kind 30503

> **Note :** un Kind 7 avec `content: "+N"` (N = montant ẐEN) déclenche un paiement G1 via le relay `7.sh` — c'est distinct de la validation WoTx2 ci-dessus.

---

## Comment ajouter une ressource dans l'onglet Formation

Trois voies disponibles selon le contexte :

### Via le Studio (import clip + trim rapide)

1. Onglet **Formation** → bouton **Ajouter une ressource** (ou panel LIVE → **✂ Studio**)
2. Glisser un fichier WebM (enregistrement vdo.ninja) ou MP4
3. Ajuster les sliders Début / Fin pour garder la partie utile
4. Renseigner un skill (optionnel) → **✂ Couper & Publier**
5. → Encodage FFmpeg WASM local → upload IPFS → Kind 21/22 publié sur le relay

### Via l'Éditeur Vidéo (dérusage & montage multi-clips)

Pour les contenus plus longs ou composés de plusieurs prises :

1. Onglet **Formation** → bouton **✂ Éditeur** (ou panel LIVE → **🎬 Éditeur**)
2. Charger un ou plusieurs clips dans le panel Clips
3. Utiliser les marqueurs I/O et la commande D pour marquer les plages à supprimer
4. Vérifier la timeline (segments 🟩 garder / 🟥 supprimer)
5. Renseigner titre et skill → **🎞 Exporter & Publier**

Voir [GRIMOIRE_LIVE.md — Éditeur Vidéo](GRIMOIRE_LIVE.md#4-éditeur-vidéo--dérusage--montage-final-cut) pour le détail complet.

### Depuis le navigateur de médias (Mode Édition)

1. Activer **✏️ Éditer** (topbar)
2. Aller dans l'onglet **Formation**
3. Cliquer **[📁 Mes médias]** → navigateur des médias NOSTR du joueur
4. Sélectionner un fichier → glisser vers la zone Formation du skill
5. → publie automatiquement un Kind 30504 avec `["r", "https://ipfs.../CID", "video"]`

### En CLI

```bash
python3 tools/nostr_node_intercom.py publish \
    --nsec "$NSEC" --kind 30504 \
    --tags '[["d","training_linux_<timestamp>"],
             ["t","linux"],["t","formation"],
             ["r","https://ipfs.copylaradio.com/ipfs/QmXxx/guide.pdf","document"],
             ["title","Guide Linux Debian"]]' \
    --content '{"skill":"linux","resource_type":"document"}' \
    --relays "ws://localhost:7777"
```

Puis indexer pour BRO :
```bash
./admin/ia_db/knowledge_index.sh --index-nostr
```

---

## Comment révoquer une compétence

Dans l'onglet **Mes Compétences** :

1. Localiser le Kind 30503 à révoquer
2. Cliquer **Révoquer** → publie un Kind 5 (NIP-09)

---

## Grimoire vidéo — après un craft réussi

Après chaque craft réussi, MineLife génère automatiquement une courte vidéo "Grimoire" si les fichiers FFmpeg WASM sont présents (`earth/ffmpeg/`).

**Ce qui se passe :**
1. Recherche du badge ComfyUI (Kind 1063) lié au skill → image IPFS
2. Recherche d'une narration TTS (Kind 1222) optionnelle → audio MP3
3. Génération locale en navigateur via FFmpeg WASM : effet Ken Burns sur le badge, 10–20 s, libx264
4. Upload vers `/api/fileupload` (UPassport port 54321) → CID IPFS direct (`cidirect`)
5. Publication Kind 22 (NIP-71 Short Video) sur le relay

**Indicateur 📹 dans Mes Compétences :** si une vidéo Grimoire existe pour un skill (Kind 21/22 avec `#t: GrimoireVideo`), un badge 📹 apparaît à côté du skill. Clic = ouvrir la vidéo. Double-clic = ouvrir l'Éditeur Vidéo pour l'améliorer.

**Préparer le Grimoire avant le craft :**
- Demander à BRO `#badge linux` → génère le badge image via ComfyUI
- Demander à BRO `#tts linux` → génère la narration Orpheus (Kind 1222)
- Le Grimoire utilisera automatiquement ces assets lors du prochain craft réussi

**Si la vidéo ne se génère pas :**
- Vérifier que le serveur renvoie les headers HTTP requis par SharedArrayBuffer :
  ```
  Cross-Origin-Opener-Policy: same-origin
  Cross-Origin-Embedder-Policy: require-corp
  ```
- Vérifier que `earth/ffmpeg/ffmpeg-core.wasm` est accessible (~30 MB, inclus dans le repo).
- Si aucun badge n'est trouvé : demander à BRO `#badge <skill>`.

La génération est **silencieuse en cas d'échec** — le craft est validé même sans vidéo.

---

## Comment démarrer un LIVE

MineLife intègre la diffusion en direct via vdo.ninja (WebRTC P2P) + publication NIP-53.

### Démarrer

1. Cliquer **🔴 LIVE** (topbar) → ouvre le panel LIVE
2. Cliquer **Démarrer** :
   - Si l'onglet **Atelier** est actif sur un craft, la room est nommée `<skill>_<npub10>` (ex : `soudure_tig_npub1abc12`)
   - Sinon : `uplanet_<npub10>`
3. → Publie un Kind 30311 (NIP-53 Live Activity) avec `status: live`
4. → Ouvre le studio vdo.ninja dans un nouvel onglet
5. Copier le **lien spectateur** depuis le panel pour le partager

### Arrêter

Cliquer **Arrêter** → publie le même Kind 30311 (même `d`-tag) avec `status: ended`. Les clients NIP-53 affichent automatiquement la session comme terminée.

### Chat live

Pendant le LIVE, activer **💬 Chat** dans le panel → les messages sont publiés en Kind 1311, rattachés à la session.

**Découverte depuis la home page :** les sessions actives (`status: live`, `#t: UPlanet`) sont visibles via Kind 30311 sur le relay de la station.

---

## Flux complet : de la découverte à la certification

```
[Onglet Explorer]
Parcourir les crafts disponibles (Kind 30500) sur le relay local

       ↓

[Aspirer X1]
Kind 30501 auto-signé → contacter les porteurs via DM Kind 4

       ↓

[Session de craft]
Règle A : 3× Kind 7 reaction "+" de pairs distincts
Règle B : 1× Kind 30502 d'un pair X1+

       ↓

[Auto-signer le certificat]
Kind 30503 publié → visible dans Mes Compétences
→ débloque les crafts composites qui requièrent ce skill

       ↓

[Grimoire vidéo] (automatique si FFmpeg WASM disponible)
badge + narration → MP4 Ken Burns → IPFS → Kind 22
```

---

## Kinds NOSTR utilisés

| Kind | NIP | Usage dans MineLife |
|------|-----|---------------------|
| 0 | NIP-01 | Profil joueur (avatar, nom) |
| 4 | NIP-04 | DM vers pair (demande d'attestation) |
| 5 | NIP-09 | Révocation de credential |
| 7 | NIP-25 | Réaction validation (`+`) ou paiement ẐEN (`+N`) |
| 21 | NIP-71 | Long video (> 60 s) — Studio / VideoEditor |
| 22 | NIP-71 | Short video (≤ 60 s) — Grimoire post-craft, Studio, VideoEditor |
| 1063 | NIP-94 | Métadonnées fichier IPFS (badge image) |
| 1222 | NIP-A0 | Narration TTS (audio Grimoire) |
| 1311 | NIP-53 | Live chat message |
| 30311 | NIP-53 | Live Activity (start/end) |
| 30500 | WoTx2 | Définition de permis composite |
| 30501 | WoTx2 | Aspiration / demande de certification |
| 30502 | WoTx2 | Attestation P2P |
| 30503 | WoTx2 | Credential (permis émis) |
| 30504 | WoTx2 | Ressource de formation (vidéo, PDF, lien lié à un skill) |

---

## Fichiers de référence

| Fichier | Rôle |
|---------|------|
| `UPlanet/earth/install_craft.html` | Activation post-installation (joindre preuve + signer x1) |
| `UPlanet/earth/skills.html` | Nuage de compétences p5.js — explorer la constellation, switch API/Relay, sélecteur constellation |
| `UPlanet/earth/skills.js` | Widget SkillCloud réutilisable (p5.js, relay Kind 30503/30504, découverte oracle via tag `l permit_type`) |
| `UPlanet/earth/relay.js` | Module RelaySelector — peuplement <select> depuis constellation, isLocal(), toApiBase() |
| `UPlanet/earth/minelife.html` | Interface principale MineLife |
| `UPlanet/earth/minelife.js` | Widget crafting (`MineLife.init`) |
| `UPlanet/earth/grimoire.js` | Module Grimoire : Ken Burns, Studio trim, concatSegments |
| `UPlanet/earth/video-editor.js` | Éditeur vidéo Final Cut (dérusage, multi-clips, timeline) |
| `Astroport.ONE/tools/oracle_init_captain_wotx2.sh` | Bootstrap Kind 30500 capitaines |
| `Astroport.ONE/RUNTIME/ORACLE.refresh.sh` | Émet Kind 30503 Oracle (cron) |
| `Astroport.ONE/IA/bro_dm_daemon.sh` | Daemon Kind 4 BRO |
| `Astroport.ONE/admin/ia_db/knowledge_index.sh` | Index vectoriel Qdrant |

---

## Voir aussi

- [GRIMOIRE_LIVE.md](GRIMOIRE_LIVE.md) — architecture Grimoire vidéo et LIVE en détail
- [KNOWLEDGE_EMBEDDINGS.md](KNOWLEDGE_EMBEDDINGS.md) — indexer les ressources dans Qdrant
- [tutorials/setup_learning_hub.md](../tutorials/setup_learning_hub.md) — configurer sa station hub
- [explanation/minelife_wikipedia_wot.md](../explanation/minelife_wikipedia_wot.md) — la philosophie WoT
- [reference/NOSTR_EVENTS_REFERENCE.md](../reference/NOSTR_EVENTS_REFERENCE.md) — spec Kind 30500–30504
