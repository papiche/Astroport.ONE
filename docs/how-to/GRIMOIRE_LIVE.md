# Grimoire Vidéo & LIVE UPLANET

Documentation des deux features vidéo de **MineLife** (`UPlanet/earth/minelife.html`) :

1. **Grimoire Vidéo** — Génération locale en navigateur d'une courte vidéo (Kind 22) après chaque craft WoTx2 réussi, via FFmpeg WASM.
2. **LIVE UPLANET** — Diffusion en direct via vdo.ninja (WebRTC P2P) + publication d'une Live Activity NOSTR (NIP-53 Kind 30311).

---

## 1. Grimoire Vidéo

### Architecture

```
┌─────────────────────────────────────────────┐
│              Station (BRO / IA)             │
│  ComfyUI → badge image (Kind 1063)          │
│  Orpheus  → narration TTS (Kind 1222)       │
│  Ollama   → texte skill (Kind 30504)        │
└──────────────────┬──────────────────────────┘
                   │ IPFS / NOSTR relay
┌──────────────────▼──────────────────────────┐
│         Navigateur du joueur                │
│  grimoire.js → FFmpeg WASM (earth/ffmpeg/)  │
│    badge + audio → Ken Burns + libx264      │
│    → Blob MP4                               │
│    → /api/fileupload → CID IPFS             │
│    → requireSigned({ kind: 22, … })         │
│       → NIP-71 vidéo courte sur relay       │
└─────────────────────────────────────────────┘
```

**Principe clé** : la station génère les assets lourds (badge image, narration), le navigateur assemble la vidéo MP4 localement — pas de transcodage côté serveur.

### Module `grimoire.js`

Fichier : `UPlanet/earth/grimoire.js`

Exposé globalement via `window.Grimoire`. Dégradation silencieuse si `earth/ffmpeg/` est absent.

#### API publique

| Méthode | Description |
|---------|-------------|
| `Grimoire.isAvailable()` | `true` si FFmpeg WASM chargé |
| `Grimoire.init()` | Charge FFmpeg WASM (HEAD check + inject scripts). Retourne `Promise<boolean>` |
| `Grimoire.generateSkillVideo(opts)` | Ken Burns sur badge + audio optionnel → `Blob` MP4 |
| `Grimoire.generateCVReel(mySkillsMap)` | Concatène N segments (3 s/skill) → `Blob` MP4 CV Reel |
| `Grimoire.triggerSkillShowcase(permitId, permitName)` | Flux complet post-craft : badge → vidéo → IPFS → Kind 22 |
| `Grimoire.trimAndPublish(opts)` | **Studio** : `{file, startSec, endSec, title, skillTag}` → trim → IPFS → Kind 21/22 |
| `Grimoire.concatSegments(segments)` | **VideoEditor** : encode + concat `[{file, from, to}]` → `Blob` MP4 final |
| `Grimoire._uploadVideoToIPFS(blob, filename)` | POST `/api/fileupload` → `{ cid, url }` |
| `Grimoire._publishVideoEvent(opts)` | Publie Kind 21 ou 22 (NIP-71) via `requireSigned()` |

#### Paramètres `generateSkillVideo`

```javascript
Grimoire.generateSkillVideo({
    badgeUrl: 'https://ipfs.../badge.jpg',  // URL IPFS du badge ComfyUI
    audioUrl: 'https://ipfs.../narr.mp3',   // optionnel — narration TTS Kind 1222
    skillName: 'Soudure TIG',
    duration: 10,                           // secondes (ignoré si audioUrl fourni)
});
```

#### Filtre Ken Burns (FFmpeg)

```
scale=1280:720:force_original_aspect_ratio=decrease,
pad=1280:720:(ow-iw)/2:(oh-ih)/2:color=black,
zoompan=z='min(zoom+0.0008,1.5)':d=FRAMES:x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)',
fps=25
```

### Intégration dans minelife.html

Le hook post-craft se trouve dans `synthesizeComposite()` :

```javascript
if (window.Grimoire) {
    window.Grimoire.init().then(ok => {
        if (ok) window.Grimoire.triggerSkillShowcase(permitId, permitName)
                               .catch(e => console.warn('[Grimoire]', e));
    });
}
```

Le bouton **🎬 CV Vidéo** dans l'onglet "Mes Compétences" appelle `generateCVVideoReel()` qui construit un reel de tous les badges du joueur (3 s par skill).

### Upload IPFS + uDRIVE Roaming

`/api/fileupload` (UPassport port 54321) :
- Reçoit `file` (Blob MP4) + `npub` du joueur
- Publie sur IPFS local
- Si le joueur est en **roaming** (connecté à une station tierce), déclenche automatiquement `_maybe_send_roaming_dm()` — NIP-04 DM vers la station d'origine — pour synchroniser la vidéo dans l'uDRIVE personnel.

### Événement NOSTR publié

**Kind 22 (NIP-71 — Short Video)** :

```json
{
  "kind": 22,
  "tags": [
    ["title", "Soudure TIG — Grimoire WoTx2"],
    ["url", "https://ipfs.copylaradio.com/ipfs/CID/grimoire_xxx.mp4"],
    ["m", "video/mp4"],
    ["t", "WoTx2"],
    ["t", "GrimoireVideo"],
    ["t", "soudure-tig"],
    ["published_at", "1700000000"],
    ["thumb", "https://ipfs.copylaradio.com/ipfs/CID/badge.jpg"],
    ["duration", "10"],
    ["l", "permitId", "permit_type"],
    ["imeta", "url https://…/grimoire.mp4", "m video/mp4", "image https://…/badge.jpg"]
  ]
}
```

### Build FFmpeg WASM

Le fork utilisé est `papiche/ffmpeg.wasm` branche `zen`. Les dist sont **committées** dans `UPlanet/earth/ffmpeg/` (ffmpeg.js, ffmpeg-util.js, ffmpeg-core.js, ffmpeg-core.wasm ~30 MB). Pour les rebuilder depuis les sources :

```bash
# Prérequis : Node.js ≥ 18, Docker + Emscripten (pour le core WASM)

cd /home/fred/workspace/AAA/ffmpeg.wasm
npm install

# TypeScript packages (rapide, ~2 min)
cd packages/ffmpeg && npm run build && cd ../..
cd packages/util   && npm run build && cd ../..

# Core WASM (nécessite Docker + Emscripten, ~30 min)
make prd

# Copier les dist dans earth/ffmpeg/
D=/home/fred/workspace/AAA/UPlanet/earth/ffmpeg && mkdir -p $D
cp packages/ffmpeg/dist/umd/ffmpeg.js          $D/ffmpeg.js
cp packages/util/dist/umd/index.js             $D/ffmpeg-util.js
cp packages/core/dist/umd/ffmpeg-core.js       $D/ffmpeg-core.js
cp packages/core/dist/umd/ffmpeg-core.wasm     $D/ffmpeg-core.wasm
```

**Dégradation gracieuse** : si `earth/ffmpeg/` est absent (fichiers non buildés), `grimoire.js` fait un HEAD check silencieux et retourne `false` depuis `isAvailable()`. Aucun message d'erreur visible — les crafts fonctionnent normalement sans la génération vidéo.

### Zone de dépôt vidéo (modal Formation)

Dans le modal "Mes médias" (`#modal-media-browser`), une zone drag-and-drop permet d'uploader manuellement une vidéo de formation :
- Upload vers `/api/fileupload` → CID IPFS
- Publication Kind **30504** (ressource de formation WoTx2) :
  ```json
  { "kind": 30504, "tags": [["d","training_skill_ts"],["t","skill"],["t","formation"],["r","ipfs_url","video"]] }
  ```

---

## 2. LIVE UPLANET

### Architecture

```
┌─────────────────────────────────────────────┐
│         Navigateur du joueur                │
│  minelife.html → bouton 🔴 LIVE topbar      │
│  startLiveSession()                         │
│    → Kind 30311 (NIP-53 Live Activity)      │
│       tag t: WoTx2, UPlanet, <skill>        │
│    → window.open(vdo.ninja studio)          │
└──────────────────┬──────────────────────────┘
                   │ WebRTC P2P (vdo.ninja)
           ┌───────▼────────┐
           │  Spectateurs   │
           │  (vdo.ninja    │
           │   viewer URL)  │
           └────────────────┘
                   │ NOSTR relay
           ┌───────▼────────┐
           │  index.html    │
           │  (home page)   │
           │  Kind 30311    │
           │  #t: UPlanet   │
           └────────────────┘
```

### Transport vidéo : vdo.ninja

Instance déployée sur la station : `https://vdo.copylaradio.com`

| Rôle | URL |
|------|-----|
| Studio (diffuseur) | `https://vdo.copylaradio.com/?room=<roomId>&effects&record` |
| Spectateur (viewer) | `https://vdo.copylaradio.com/?room=<roomId>&view` |
| Home UPlanet | `https://vdo.copylaradio.com/?room=UPLANET&effects&record` |

**Naming de la room** : si un craft est actif dans l'Atelier, la room est nommée `<skill>_<npub10>` (ex: `soudure_tig_npub1abc12`). Sinon : `uplanet_<npub10>`.

Cela crée un **canal vdo.ninja par compétence** tout en restant discoverable depuis l'accueil UPLANET via les tags NOSTR.

### NIP-53 — Live Activity (Kind 30311)

Spec : `nostr-nips/53.md`

#### Événement "live"

```json
{
  "kind": 30311,
  "tags": [
    ["d",         "live_soudure_tig_npub1abc12_1700000000"],
    ["title",     "Alice — LIVE WoTx2 · soudure_tig"],
    ["summary",   "Session LIVE UPlanet MineLife · Forge & Certification WoTx2"],
    ["streaming", "https://vdo.copylaradio.com/?room=soudure_tig_npub1abc12&effects&record"],
    ["recording", "https://vdo.copylaradio.com/?room=soudure_tig_npub1abc12&view"],
    ["starts",    "1700000000"],
    ["status",    "live"],
    ["t",         "WoTx2"],
    ["t",         "UPlanet"],
    ["t",         "MineLife"],
    ["t",         "soudure-tig"],
    ["relays",    "wss://relay.copylaradio.com"]
  ],
  "content": "🔴 LIVE UPlanet MineLife #WoTx2 #soudure-tig"
}
```

**Double diffusion** :
- Tag `t: UPlanet` → visible depuis la home page (Kind 30311 avec `#t: ['UPlanet']`)
- Tag `t: soudure-tig` → visible dans le canal de la compétence

#### Événement "ended"

Publié à l'arrêt (bouton "Arrêter" ou fermeture de l'onglet) :

```json
{
  "kind": 30311,
  "tags": [
    ["d", "live_soudure_tig_npub1abc12_1700000000"],
    ["status", "ended"],
    ["starts", "1700000000"],
    ["ends",   "1700003600"],
    ...
  ]
}
```

Le `d`-tag identique écrase l'événement `live` → les clients NIP-53 affichent "terminé".

### Kind 1311 — Live Chat Message

Les messages du chat live dans le panel LIVE sont publiés en Kind 1311, rattachés à la session via le tag `a` :

```json
{
  "kind": 1311,
  "tags": [
    ["a", "30311:<pubkey>:<sessionId>", "<relay>", "root"],
    ["t", "WoTx2"]
  ],
  "content": "Bravo pour ce craft !"
}
```

### Interface utilisateur

**Bouton topbar** (`id="btn-live"`) :
- État normal : `🔴 LIVE` gris
- État actif : `🔴 EN DIRECT` rouge pulsant (`@keyframes pulse-live`)

**Panel flottant** (`id="live-panel"`) :
- Badge statut (⚫ / 🔴 EN DIRECT)
- Champ lecture seule avec le lien spectateurs + bouton copier
- Bouton **Démarrer** → `startLiveSession()` + ouvre le studio vdo.ninja
- Bouton **Arrêter** → `stopLiveSession()` → Kind 30311 status: ended
- Bouton **Studio** → ouvre vdo.ninja dans un nouvel onglet
- Toggle **💬 Chat** → mini-chat Kind 1311 (visible seulement pendant le LIVE)

### Détection automatique du craft actif

`_detectActiveCraftSkill()` :
1. Vérifie si l'onglet "Atelier" est actif (`#tab-craft.active`)
2. Lit `STATE.craftGroupActive` pour trouver le premier groupe actif
3. Retourne le tag `result` ou `t` de la recette active
4. Retourne `null` si aucun craft n'est en cours

### Lien depuis index.html (home page)

Le lien `https://vdo.copylaradio.com/?room=UPLANET&effects&record` est déjà présent dans l'onglet Formation de `index.html` — c'est la porte d'entrée générale.

Pour découvrir les sessions LIVE actives depuis la home page, chercher Kind 30311 avec `status: live` et `#t: ['UPlanet']` sur le relay de la station.

---

## 3. Studio — Import & Découpe rapide

Accessible depuis le panel LIVE (bouton **✂ Studio**) ou l'onglet Formation (bouton **Ajouter une ressource**).

**Cas d'usage principal :** importer un enregistrement vdo.ninja (WebM) et couper les silences avant/après avant de publier.

### Interface

```
┌─ Studio ─────────────────────────────────── [✕] ┐
│  [Zone drag-and-drop : glissez votre WebM/MP4]   │
│                                                   │
│  ┌─ Prévisualisation ─────────────────────────┐  │
│  │          <video preview>                   │  │
│  └───────────────────────────────────────────┘  │
│                                                   │
│  Début ───●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  0:12   │
│  Fin   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━●───  3:45   │
│  Segment : 3:33 — Kind 22 (short)               │
│                                                   │
│  Titre  [Mon tutoriel Linux________________]     │
│  Skill  [linux__________________________]        │
│                                                   │
│            [Aperçu]  [✂ Couper & Publier]        │
└─────────────────────────────────────────────────┘
```

### Comportement technique

- **WebM → MP4** : re-encodage libx264 (vdo.ninja sort du VP8/VP9)
- **MP4 → MP4** : stream copy `-c copy` (sans re-encodage, rapide)
- Encodage 100 % dans le navigateur (FFmpeg WASM) — aucun serveur impliqué avant l'upload
- Upload via `/api/fileupload` → CID IPFS direct (`cidirect`)
- Publication **Kind 22** (≤ 60 s) ou **Kind 21** (> 60 s)
- Tag `["d", skillTag + "_" + timestamp]` si skill renseigné → lie à Kind 30504

---

## 4. Éditeur Vidéo — Dérusage & Montage Final Cut

Fichier : `UPlanet/earth/video-editor.js`

Accessible depuis **🎬 Éditeur** (onglet Formation ou panel LIVE).

### Concept

L'éditeur adopte le modèle de montage **non-destructif** : les fichiers source ne sont jamais modifiés. Tous les marqueurs, coupes et suppressions sont stockés dans une liste de segments `{from, to, keep}` en mémoire. L'encodage FFmpeg n'a lieu qu'à l'export final.

### Layout

```
┌── ÉDITEUR VIDÉO ─── [Titre] ──────── [raccourcis] ── [✕] ─┐
│                                                             │
│  ┌── 📂 Clips ──────┐   ┌── Prévisualisation ────────────┐ │
│  │  clip1.webm      │   │   <video>                      │ │
│  │  12:34           │   │                                │ │
│  │  clip2.mp4       │   │                                │ │
│  │  04:22           │   └────────────────────────────────┘ │
│  │                  │                                       │
│  │  [+ Ajouter]     │   ⏮ ◀ [▶ Play] ▶ ⏭  0:42.3/12:34   │
│  └──────────────────┘   [◀I] [O▶] [🗑 I→O] [✂ Couper] [⊘] │
│                                                             │
│  [↩ Annuler] [♻ Tout garder]  ✅ 3 seg — 8:12  Zoom ──●── │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ clip1 │ ████████░░░░░████████████░░░░░████████████  │   │
│  │ clip2 │ ████████████████████████████████████████    │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  Skill [linux___]  [Annuler]  [🎞 Exporter & Publier]      │
└─────────────────────────────────────────────────────────────┘
```

### Panneaux

| Panneau | Rôle |
|---------|------|
| **📂 Clips** | Liste des clips chargés (drag-and-drop ou file picker, multi-fichiers). Clic = charge dans le player. |
| **Prévisualisation** | Élément `<video>` natif. Synchronisé avec la tête de lecture de la timeline. |
| **Transport** | ⏮◀▶▶⏭ + timecode `m:ss.d / m:ss.d`. Boutons de marquage I/O et d'opération. |
| **Timeline** | Barre horizontale par clip. Segments 🟩 keep / 🟥 delete. |
| **Footer** | Champ skill, statut d'export, bouton Exporter. |

### Raccourcis clavier

| Touche | Action |
|--------|--------|
| `Espace` | Play / Pause |
| `I` | Marquer début de plage (marqueur violet) |
| `O` | Marquer fin de plage (marqueur orange) |
| `D` | Supprimer la plage I→O (marque les segments en 🟥) |
| `X` | Couper à la tête de lecture (split sans supprimer) |
| `←` / `→` | Reculer / avancer de 1 seconde |
| `Shift+←/→` | Reculer / avancer de 10 secondes |
| `Ctrl+Z` | Annuler (jusqu'à 40 niveaux) |

### Workflow de dérusage (cas standard)

```
1. Ouvrir l'Éditeur
2. Glisser l'enregistrement vdo.ninja (WebM ou MP4) → panel Clips
3. Appuyer Espace → la vidéo démarre
4. À l'entrée d'une séquence à couper : appuyer I
5. À la fin de la séquence à couper : appuyer O
6. Appuyer D → la plage devient rouge 🟥 dans la timeline
7. Répéter 3–6 pour chaque mauvaise séquence
8. Vérifier le résumé (✅ X seg gardés — durée totale)
9. Renseigner le skill si la vidéo correspond à une compétence
10. Cliquer "🎞 Exporter & Publier"
```

### Workflow montage multi-clips

```
1. Charger le premier clip (ex: introduction, 5 min)
2. Charger un second clip (ex: démonstration, 12 min)
3. Chaque clip apparaît comme une piste dans la timeline
4. Dérusager chaque piste indépendamment (I/O/D par clip actif)
5. L'export concatène les segments gardés de tous les clips dans l'ordre
```

### Pipeline d'export

```
VideoEditor.exportAndPublish()
  ├── Grimoire.init()                    [charge FFmpeg WASM si besoin]
  ├── Grimoire.concatSegments(segments)
  │     ├── Écriture des sources dans le FS virtuel (une fois par fichier)
  │     ├── Pour chaque segment {file, from, to} :
  │     │     └── ffmpeg -ss FROM -to TO -i src.ext [-c copy | libx264] seg_N.mp4
  │     ├── Si 1 segment → retourne directement le Blob
  │     └── Si N > 1 → concat demuxer → cs_final.mp4
  ├── Grimoire._uploadVideoToIPFS(blob, fname)
  │     └── POST /api/fileupload → { cid, url }
  ├── Calcul Kind : durée ≤ 60 s → Kind 22, > 60 s → Kind 21
  └── requireSigned({ kind, tags, content })
        tags: title, url, m, duration, t:MineLife, t:VideoEditor,
              t:<skillTag>, d:<skillTag_ts>, imeta
```

### État interne (`video-editor.js`)

```javascript
S = {
    clips:    [],    // [{file, name, url, duration, segs:[{from, to, keep}]}]
    active:   0,     // index du clip actif dans le player
    pxPerSec: 80,    // zoom timeline (px/seconde)
    inPt:     null,  // marqueur I (secondes)
    outPt:    null,  // marqueur O (secondes)
    undo:     [],    // pile d'annulation (max 40 snapshots)
    video:    null,  // <video> DOM element
    raf:      null,  // requestAnimationFrame handle
}
```

Chaque snapshot dans `undo` est une copie profonde de `clips[]` (seuls les segments sont copiés, pas les `File` ni les `ObjectURL`).

### API publique `window.VideoEditor`

| Méthode | Description |
|---------|-------------|
| `VideoEditor.open(opts)` | Ouvre le modal. `opts = {files, title, skillTag}` |
| `VideoEditor.close()` | Ferme et libère tous les ObjectURL |
| `VideoEditor.addClip(file)` | Ajoute un clip à la timeline (async, attend loadedmetadata) |
| `VideoEditor.removeClip(idx)` | Retire un clip |
| `VideoEditor.markIn()` | Pose le marqueur I à la position courante |
| `VideoEditor.markOut()` | Pose le marqueur O à la position courante |
| `VideoEditor.clearMarkers()` | Efface I et O |
| `VideoEditor.deleteRange()` | Marque la plage I→O en 🟥 delete |
| `VideoEditor.cutAtPlayhead()` | Split le segment courant à la tête de lecture |
| `VideoEditor.toggleSeg(ci, si)` | Bascule keep/delete du segment `si` du clip `ci` |
| `VideoEditor.restoreAll()` | Remet tous les segments en 🟩 keep |
| `VideoEditor.undoLast()` | Annule la dernière opération d'édition |
| `VideoEditor.setZoom(px)` | Ajuste le zoom (8–500 px/s) |
| `VideoEditor.exportAndPublish()` | Lance l'encodage FFmpeg + upload IPFS + publication NOSTR |

### Points d'entrée dans minelife.html

| Bouton | Localisation | Comportement |
|--------|-------------|-------------|
| **🎬 Éditeur** | Panel LIVE (à côté de Studio) | `VideoEditor.open()` |
| **✂ Éditeur** | Onglet Formation (section-header) | `VideoEditor.open()` |
| Badge **📹** double-clic | Mes Compétences (par skill) | `VideoEditor.open({ title: skill, skillTag: skill })` |

---

## 5. Fichiers modifiés / créés

| Fichier | Modifications |
|---------|---------------|
| `UPlanet/earth/grimoire.js` | +`trimAndPublish`, +`concatSegments`, fix tag `thumb` (NIP-71) |
| `UPlanet/earth/video-editor.js` | **NOUVEAU** — Module éditeur Final Cut (753 lignes) |
| `UPlanet/earth/minelife.html` | +Studio modal, +Éditeur boutons, +onboarding didactique, +badge 📹 Grimoire par skill, +Formation CTA |
| `how-to/GRIMOIRE_LIVE.md` | **CE FICHIER** — documentation |

Les fichiers `earth/ffmpeg/*.{js,wasm}` sont dans le repo (build inclus, ~30 MB).

---

## 4. Flows complets

### Flow Grimoire post-craft

```
synthesizeComposite() [WoTx2 craft réussi]
  └── triggerSkillShowcase(permitId, permitName)
        ├── _findBadgeForSkill(permitName)  [Kind 1063 relay query]
        │     └── pas de badge → notify "Demandez #badge à BRO"
        ├── fetchEvents({ kinds:[1222], #t:[skill] })  [narration TTS optionnelle]
        ├── generateSkillVideo({ badgeUrl, audioUrl, duration })
        │     ├── ffmpeg.writeFile('badge.jpg', ...)
        │     ├── ffmpeg.writeFile('narration.mp3', ...)  [si audio]
        │     └── ffmpeg.exec([Ken Burns, libx264, ...])  → output.mp4
        ├── _uploadVideoToIPFS(blob, 'grimoire_xxx.mp4')
        │     └── POST /api/fileupload → { cid, url }
        │           └── uDRIVE roaming DM si joueur en roaming
        └── _publishVideoEvent({ cid, url, thumbUrl, skillName, permitId, duration })
              └── requireSigned({ kind: 22, tags:[NIP-71], content })
```

### Flow LIVE

```
Clic "🔴 LIVE" topbar
  └── toggleLivePanel()
        └── _refreshLivePanel()  [met à jour URL, état boutons]

Clic "Démarrer"
  └── startLiveSession()
        ├── _detectActiveCraftSkill()  [skill depuis l'Atelier actif]
        ├── _liveRoomId(skill)          → room = "soudure_tig_npub1abc12"
        ├── _liveVdoUrl(null, skill)    → studio URL
        ├── _liveVdoUrl('view', skill)  → viewer URL
        ├── requireSigned({ kind: 30311, tags:[NIP-53 live], content })
        │     t: WoTx2, UPlanet, MineLife, soudure-tig
        ├── _subscribeLiveChat()        → Kind 1311 depuis relay
        └── window.open(studioUrl)      → vdo.ninja dans nouvel onglet

Clic "Arrêter" ou fermeture onglet (beforeunload)
  └── stopLiveSession()
        ├── requireSigned({ kind: 30311, tags:[status:ended] })
        └── _refreshLivePanel()         → état "⚫ Non diffusé"
```

---

## 5. NIP utilisés

| NIP | Kind | Usage |
|-----|------|-------|
| NIP-71 | 22 | Short video (Grimoire) |
| NIP-94 | 1063 | File metadata (badge image) |
| NIP-53 | 30311 | Live Activity |
| NIP-53 | 1311 | Live Chat Message |
| NIP-23 | 30504 | Formation resource (vidéo training) |
| NIP-01 | 1222 | Narration TTS (Kind custom) |
