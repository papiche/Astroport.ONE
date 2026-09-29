# Produire une vidéo explicative avec MiniMax H3

## Problème

Fabriquer, sur une station Astroport équipée d'un GPU, une vidéo de 1 à 2 minutes
qui explique une fonctionnalité d'UPlanet : acteurs récurrents qui parlent français
(lipsync natif), captures d'écran des applications, titres et carton final à QR
codes. Sortie 720p (16:9 ou vertical 9:16), publiée sur IPFS.

C'est ainsi qu'ont été produits les épisodes 1 à 5 de la série UPlanet (MULTIPASS,
Ẑen, clé LOVE, genèse du code, constellation) et le spot « L'Appel de la
Constellation ».

## Prérequis

### Matériel

- GPU NVIDIA 24 Go (mesures faites sur RTX 3090), 64 Go de RAM, ~80 Go de disque
  pour les modèles.

### ComfyUI

- ComfyUI ≥ 0.36, service systemd `comfyui` lancé **sans `--highvram`** (mode
  NORMAL_VRAM). En HIGH_VRAM, le déchargement des modèles ne libère rien et le
  décodage VAE part en OOM.
- Pack **ComfyUI-MultiGPU désactivé** (`custom_nodes/comfyui-multigpu.disabled`) :
  son patch de `ModelPatcher` casse le déchargement et fait planter le thread
  d'exécution de ComfyUI au workflow suivant.
- Pack **ComfyUI-KJNodes** (node `VRAM_Debug`, utilisé pour décharger le DiT avant le
  décodage).

### Modèles (dans `ComfyUI/models/`)

| Rôle | Fichier | Taille | Source |
|---|---|---|---|
| Vidéo (t2v / i2v) | `diffusion_models/minimax_h3_fl2va_pruned_int8_convrot.safetensors` | 21 Go | [Comfy-Org/MiniMax-H3](https://huggingface.co/Comfy-Org/MiniMax-H3) |
| Vidéo avec références (acteurs) | `diffusion_models/minimax_h3_ref2va_pruned_int8_convrot.safetensors` | 21 Go | idem |
| Encodeur texte | `text_encoders/qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors` (ou `clip/`) | 15,7 Go | idem |
| VAE vidéo / audio | `vae/minimax_h3_video_vae_fp16.safetensors`, `vae/minimax_h3_audio_vae_fp32.safetensors` | 5,2 + 0,6 Go | idem |
| Images (portraits, 1ʳᵉ image) | `diffusion_models/z_image_turbo_int8_convrot.safetensors`, `text_encoders/qwen_3_4b_fp8_mixed.safetensors`, `vae/ae.safetensors` | 12 Go | [Comfy-Org/z_image_turbo](https://huggingface.co/Comfy-Org/z_image_turbo) |
| Upscale (optionnel, lent) | `diffusion_models/seedvr2_3b_int8_convrot.safetensors`, `vae/seedvr2_ema_vae_fp16.safetensors` | 4 Go | [Comfy-Org/SeedVR2](https://huggingface.co/Comfy-Org/SeedVR2) |

### Outils

- `ffmpeg` : celui de `/usr/local/bin` sert aux montages ; celui du système
  (`/usr/bin/ffmpeg`) est utilisé pour les titres car il a le filtre `drawtext`.
- `qrencode`, `jq`, `ipfs`.
- Playwright + Chromium dans `~/.astro` (captures d'écran).
- Facultatif : Orpheus TTS (`IA/services/orpheus.me.sh`, local ou via la
  constellation) pour les plans en voix-off.

## Étapes

### 1. Écrire le scénario à partir du code, pas de mémoire

Les chiffres et les parcours doivent venir des sources : pages `earth/*.html`,
`docs/`, scripts (`UPLANET.official.sh`, `oc2uplanet.sh`, `make_NOSTRCARD.sh`…).
Quand deux documents se contredisent (PAF, tarif Constellation…), ne pas citer de
chiffre : les tarifs varient d'une station à l'autre.

Règles d'écriture qui ont fonctionné :

- un plan = une action + une réplique de ~2,5 mots/s (5 s ≈ 12 mots, 9 s ≈ 22 mots) ;
- **un seul acteur par plan** (champ / contrechamp pour un dialogue) ;
- gros plans ou plans rapprochés pour les visages ;
- décrire le son dans chaque prompt (voix, bruitages, musique), sinon le plan est muet ;
- aucun texte à l'écran demandé au modèle : utiliser `title` et `card`.

### 2. Créer les acteurs (une fois pour toute la série)

Dans le storyboard, un acteur se déclare par un prompt de portrait et une phrase
de voix (`voice_line`). Au premier rendu, `generate_scene.sh` :

1. génère le portrait avec Z-Image (1024×1024) en ajoutant au prompt :
   `head and shoulders portrait, plain neutral light grey studio background, soft
   even lighting, looking at the camera` ;
2. fait dire `voice_line` au portrait par MiniMax (i2v, 1:1, 0,25 MP, 8 s), puis
   extrait la piste audio en `voice.wav` (mono, 48 kHz).

Pour réutiliser les acteurs dans d'autres épisodes, copier le dossier
`cast/<nom>/` (portrait.png + voice.wav) dans un emplacement durable. Les épisodes
UPlanet utilisent `~/.zen/workspace/scenes/cast/{lea,malik}/`, et leurs storyboards
les référencent par `"image"` et `"voice"`.

> Le fond neutre est indispensable : ref2va recopie tout ce qu'il voit dans la
> photo de référence (un globe holographique sur le portrait réapparaissait dans
> chaque plan). N'utiliser le visage ou la voix d'une personne réelle qu'avec son
> consentement.

### 3. Préparer les écrans

Un plan `screen` accepte une URL (capturée par Playwright à la taille finale, page
entière) ou un PNG déjà préparé.

- Onglets et assistants : `screen_js` exécute du JavaScript avant la capture, par exemple
  `document.querySelector('[data-bs-target="#tab-aide"]').click()`, ou remplir une
  date fictive puis appeler `_wzGoTo(3)` dans `atomic.html`.
- Pages très longues (OpenCollective, GitHub) : capturer puis recadrer le haut
  (`ffmpeg -vf crop=1280:2000:0:0`) pour un défilement court.
- Frises d'historique git : `lib/git_timeline.py <dépôt> <sortie.html> --from --to
  --milestone "AAAA-MM-JJ|texte"`, puis capture du fichier HTML.
- Écarter les pages qui exposent des données personnelles : le JSON de
  `:12345` affiche l'email du Capitaine, les IP et les clés.

### 4. Écrire le storyboard JSON

Exemples complets dans `IA/generators/storyboards/`. Squelette :

```json
{
  "ratio": "16:9", "megapixels": 0.3, "steps": 10, "ref_steps": 20,
  "style": "clean", "height": 720, "seed": 5005,
  "cast": {
    "lea": {"image": "/home/frd/.zen/workspace/scenes/cast/lea/portrait.png",
            "voice": "/home/frd/.zen/workspace/scenes/cast/lea/voice.wav"}
  },
  "shots": [
    {"cast": ["lea"], "duration": 7,
     "prompt": "Close-up of Lea at her kitchen table… she says in French: \"Et si Internet nous appartenait ?\" Quiet kitchen ambience."},
    {"screen": "http://127.0.0.1:54321/earth/g1.html", "presenter": "lea", "duration": 8,
     "prompt": "Lea says in French: \"Je choisis ma station, mon Home.\"", "title": "Choisir sa station"},
    {"card": {"title": "Créez votre MULTIPASS",
              "links": [{"label": "S'inscrire", "url": "https://u.copylaradio.com/g1"}]}, "duration": 8}
  ]
}
```

### 5. Lancer le rendu

```bash
cd ~/.zen/Astroport.ONE/IA/generators
./generate_scene.sh -w ~/.zen/workspace/scenes/episode06 storyboards/episode06.json
```

- La sortie standard contient l'URL IPFS de la vidéo finale.
- Le répertoire `-w` conserve acteurs, plans (`shot_NN.mp4`), incrustations
  (`talk_NN.mp4`) et captures. Relancer la même commande reprend là où le rendu
  s'est arrêté.
- **Ne jamais modifier `generate_scene.sh` pendant un rendu** : bash lit le script
  au fil de l'exécution et déraille à la fin de la boucle des plans.

### 6. Contrôler et corriger

Planche contact d'un épisode (une image toutes les 8 s) :

```bash
ffmpeg -i scene.mp4 -vf "fps=1/8,scale=320:-2,tile=6x2" -frames:v 1 planche.png
```

Pour refaire un plan, supprimer `shot_NN.mp4` (et `talk_NN.mp4` pour une
incrustation), changer éventuellement sa seed dans le storyboard (`"seed": 3777`),
puis relancer avec le même `-w`. Seul ce plan est recalculé ; la finition et
l'assemblage prennent quelques secondes.

Défauts rencontrés et remèdes :

| Symptôme | Cause | Remède |
|---|---|---|
| Plan en style dessin, dominante verte, rectangles de pseudo-texte | ref2va à 10 steps | `ref_steps` ≥ 20 (défaut) |
| Visage différent de l'acteur, fond de studio | deux acteurs dans le même plan | un acteur par plan |
| Visage étiré | image de départ d'un autre ratio (MiniMax l'étire) | recadrage automatique au ratio ; générer l'image au bon format (`IMAGE_SIZE`) |
| « Piercing » ou détails inventés après upscale | base trop basse (visage de ~60 px) + SeedVR2 | gros plans, 0,3-0,4 MP, pas de SeedVR2 |
| Mots mal prononcés (NOSTR → « nocester », uDRIVE, UMAP…) | sigles lus « à l'aveugle » | ajouter le mot à `lib/prononciation_fr.json` |
| Titre qui chevauche l'incrustation | — | automatique : titre en haut sur les plans `presenter` |

### 7. Publier

La vidéo finale est ajoutée à IPFS par le script (`ipfs add -wq`). Pour la
diffuser sur NostrTube, suivre [publish_nostrtube_video.md](publish_nostrtube_video.md).

## Résultat attendu

Une vidéo 1280×720 (ou 720×1280) en H.264 / AAC 48 kHz, 24 i/s, de 75 à 95 s pour
10 à 11 plans, produite en 45 à 80 minutes sur RTX 3090 sans intervention.

---

## Annexe — Référence

### Chaîne des scripts (`IA/generators/`)

```text
storyboard.json
   │
   ▼
generate_scene.sh ──► generate_image.sh ──► ComfyUI (Z-Image Turbo)          portraits, 1ʳᵉ images
   │              ──► generate_minimax.sh ─► ComfyUI (MiniMax H3 fl2va/ref2va) plans vidéo + voix
   │              ──► lib/capture_page.py ─► Playwright                         écrans, carton
   │              ──► lib/pronounce.py                                           répliques phonétiques
   │              ──► video_finish.sh                                            720p exact, style VHS
   ▼
ffmpeg concat ─► titres (drawtext) ─► ipfs add ─► URL
```

| Fichier | Rôle |
|---|---|
| `generate_scene.sh` | Storyboard → vidéo : acteurs, plans IA/écran/carton, finition par plan, assemblage, IPFS |
| `generate_minimax.sh` | Un plan MiniMax H3 : t2v, i2v (`-i`), références ref2va (`-R` image, `-A` audio), `-o` fichier, `-S` seed, `-u` SeedVR2, `DRY_RUN=1` |
| `generate_image.sh` | Image Z-Image Turbo int8 (repli Flux schnell si le modèle manque), taille via `IMAGE_SIZE=LxH` |
| `video_finish.sh` | `-s LxH` taille exacte, `-v` style VHS ; 24 i/s, AAC 48 kHz stéréo |
| `workflow/video_minimax_h3_t2v_api.json` | Template ComfyUI `video_minimax_h3_t2v` au format API (subgraph aplati) + `VRAM_Debug` |
| `workflow/ZImageTurbo.json` | Workflow Z-Image (mêmes IDs de nodes que `FluxImage.json`) |
| `lib/capture_page.py` | Capture Playwright (`--full`, `--wait`, `--js`) |
| `lib/git_timeline.py` | Frise HTML commits/mois + jalons |
| `lib/pronounce.py`, `lib/prononciation_fr.json` | Orthographe phonétique des répliques + consigne de diction |
| `lib/comfyui_recovery.sh` | Diagnostic OOM, retry après libération VRAM (local uniquement) |
| `storyboards/*.json` | Épisodes 1-5, spot Constellation |

Codes de sortie communs : `0` ok, `1` erreur, `2` storyboard invalide,
`3` ComfyUI non équipé (contrôle `/object_info` avant envoi), `4` timeout.
En mode relayé (ComfyUI d'une autre station via tunnel), le timeout de calcul ne
démarre qu'au passage du job en exécution ; l'attente en file est bornée à part
(`-Q`, 4 h par défaut). `/free` n'est appelé que sur un ComfyUI local.

### Champs du storyboard

| Champ global | Défaut | Effet |
|---|---|---|
| `ratio` | `16:9` | `9:16` pour smartphone ; aussi `4:3`, `1:1`… |
| `megapixels` | `0.4` | 0,25 ≈ 360p, 0,3 ≈ 736×416 ; calcul puis agrandissement en `height` |
| `steps` / `ref_steps` | `10` / `20` | plans sans / avec acteur |
| `height` | `720` | petit côté de la vidéo finale |
| `style` | `clean` | `vhs` : look cassette (plans IA seulement) |
| `upscale` | `1` | facteur SeedVR2 (OOM au-delà de ~3 s à 0,4 MP) |
| `seed` | aléatoire | plan *i* = `seed + i` : épisode reproductible |
| `voice` | `amelie` | voix Orpheus des `voiceover` (`amelie`, `pierre`) |
| `cast` | — | `{nom: {image\|image_prompt, voice\|voice_line}}` |

| Type de plan | Champs |
|---|---|
| Acteur (ref2va) | `cast: [nom]`, `prompt` (avec la réplique entre guillemets) |
| Image générée puis animée | `image_prompt`, `prompt` |
| Suite du plan précédent | `continue: true`, `prompt` (repart de sa dernière image) |
| Image fournie / text-to-video | `image` / rien, `prompt` |
| Écran | `screen` (URL ou PNG), `motion` (`scroll`/`zoom`), `screen_js`, `presenter`, `prompt` |
| Carton | `card: {title, subtitle, links: [{label, url}]}` |
| Communs | `duration` (5-10 s), `seed`, `title`, `voiceover` (TTS mixé, MiniMax reçoit « no speech ») |

### Prompts ajoutés par les scripts

Préambule de chaque plan avec acteur (`generate_scene.sh`, `cast_refs`) :

```text
Photorealistic live-action video footage with natural colors and lighting, not an
illustration, not a cartoon, not a poster. Use <Picture 1> as the reference for
Lea's face, hair and clothing, and <Audio 1> as the reference for Lea's voice.
```

Incrustation du présentateur (plan `screen` + `presenter`, rendu en 1:1 à 0,2 MP) :

```text
Close-up head-and-shoulders shot of Lea facing the camera against a plain softly
lit neutral studio background, talking naturally with small gestures. <prompt du plan>
```

Consigne de diction ajoutée dès qu'un prompt contient une réplique (`lib/pronounce.py`) :

```text
The dialogue is spoken slowly and clearly, in natural French with a native French
accent, articulating every word, with short pauses between sentences.
```

Plan en voix-off : `Audio: ambient sound effects and soft background music only,
no speech, no voices, no singing.`

### Temps mesurés (RTX 3090)

| Opération | Durée |
|---|---|
| Image Z-Image Turbo (1344×768) | ~12 s |
| Plan 5 s, 0,4 MP, 10 steps (sans acteur) | ~4 min 30 |
| Plan 8 s, 0,25 MP (360p), 10 steps | ~3 min 40 |
| Plan acteur 9 s, 0,3 MP, ref2va 20 steps | ~9-10 min |
| Incrustation présentateur 8 s (1:1, 0,2 MP, 20 steps) | ~4-5 min |
| Écran, carton, finition, assemblage | quelques secondes |
| Épisode de 10-11 plans | 45 à 80 min |

### Pistes écartées

- **LoRA turbo 8 steps** : crash CUDA (`cudaErrorInvalidValue` dans
  `dequantize_int8`) avec le dynamic VRAM, OOM sans lui, sur 24 Go.
- **Chargeurs DisTorch2 (MultiGPU)** : le rendu passe, mais le décharger fait
  planter ComfyUI au workflow suivant.
- **Orpheus TTS pour les dialogues** : deux voix seulement, débit rapide, le
  paramètre `speed` est ignoré ; les voix natives MiniMax (avec lipsync) sont
  préférées, Orpheus reste disponible pour `voiceover`.
- **Contrôle automatique par transcription Whisper** : Whisper se trompe aussi
  (nombres, noms propres) ; la vérification reste humaine, à l'écoute.

### Stockage

Ne rien laisser dans `~/.zen/tmp` : le nettoyage d'Astroport le vide (acteurs et
dossiers de travail des épisodes 1 à 4 y ont été perdus). Utiliser
`~/.zen/workspace/scenes/` (défaut de `-w`). ComfyUI garde de son côté une copie
de chaque image et vidéo générée dans `ComfyUI/output/`, ce qui a permis de
restaurer les acteurs.
