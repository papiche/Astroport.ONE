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

### Installation automatique

`install.sh` (INSTALL_COMFYUI=yes) appelle `install/install_comfyui_video.sh`, relançable seul :
paquets (ffmpeg, jq, qrencode), Playwright, trimesh, pack KJNodes, MultiGPU désactivé,
`--highvram` retiré du service, puis modèles avec `COMFYUI_VIDEO_MODELS=yes` (~60 Go).
Chemins surchargeables : `COMFY_PY`, `ASTRO_PY`, `COMFYUI_DIR`, `SCENES_DIR`, `FFMPEG`
(voir `IA/generators/lib/env.sh`). Dans un storyboard, écrire `$SCENES_DIR/...` ou `$HOME/...`.

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

- `ffmpeg` du système (`/usr/bin/ffmpeg`, 6.1) : les scripts l'utilisent pour tout,
  car il a tous les filtres nécessaires, `drawtext` compris (le build de
  `/usr/local/bin` n'a pas `drawtext`) ; repli sur le `ffmpeg` du PATH.
- `qrencode`, `jq`, `ipfs`.
- Playwright + Chromium dans `~/.astro` (captures d'écran).
- Facultatif : PowerJoular en service 24/7 (`powerjoular.service`, voir
  [POWER_MONITORING.md](POWER_MONITORING.md)) : l'énergie de chaque rendu est alors
  affichée à la fin et écrite dans `<workdir>/energy.json`.
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

**Voix distinctes.** Sans précision, la voix de référence venait de MiniMax avec la même
graine pour tous : les acteurs finissaient avec des voix voisines. Ajouter `voice_design`
(description du timbre, de l'âge, du ton, en anglais) pour que Qwen3-TTS VoiceDesign invente
la voix ; elle dit `voice_line` en français et sert de `<Audio k>` à ref2va. Mesuré :
« young woman, bright » ≈ 296 Hz, « deep man in his 50s » ≈ 102 Hz. Installation :
`install/install_qwen3_tts.sh` (venv `~/qwen3tts_env`, séparé car `qwen-tts` impose
`transformers==4.57.3`). Sans ce venv, repli sur MiniMax, avec une graine propre à chaque
acteur. Une `voice.wav` déjà présente dans `cast/<nom>/` n'est pas régénérée : la supprimer.

```json
"cast": {"ana": {"image_prompt": "woman in her 50s, grey hair…",
                 "voice_design": "Warm low-pitched woman in her 50s, slow and calm",
                 "voice_line": "Bonjour, je m'appelle Ana et je vous présente la station."}}
```

**Banque de personnages.** Un acteur généré une fois est automatiquement enregistré dans
`$CAST_BANK` (défaut `~/.zen/workspace/characters/<nom>/`, hors `~/.zen/tmp` : jamais
purgée) et repris tel quel par tout storyboard suivant qui déclare le même nom — un simple
`"nom": {}` suffit alors, pas besoin de redonner `image_prompt`/`voice_line`. `"refresh":
true` dans l'entrée `.cast` force une régénération et remplace la banque. Un acteur
modifié depuis le dernier rendu (signature de son entrée JSON) est automatiquement
détecté et refait, sans y toucher à la main.

Cette banque est **indépendante** des paquets chiffrés du Studio web (§6 bis) : un
personnage créé en CLI n'y est pas visible, et réciproquement. Pour le pont entre les
deux, voir « Uniformiser CLI et Web » au §6 bis — en pratique, si un acteur déclaré
`"nom": {}` est absent de `$CAST_BANK`, `generate_scene.sh` cherche automatiquement un
personnage de ce nom dans la bibliothèque du Studio (NOSTR/IPFS) avant d'abandonner.

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

**Avec l'aide d'une IA.** `generate_storyboard.sh` pose une série de questions (sujet, nombre
de plans, format, style, personnages à réutiliser ou à créer, voix-off, carton final) et
rédige le storyboard via Ollama — local ou essaim, moteur choisi interactivement parmi les
modèles installés (`question.py`, même moteur que BRO ; compte utilisé pour la trace
`~/.zen/tmp/IA.log` : le Capitaine de la station). Jusqu'à 3 tentatives si le JSON renvoyé
ne respecte pas le schéma (mêmes règles que la validation de `generate_scene.sh`). Les
personnages déjà connus (banque CLI ou bibliothèque du Studio web, via la même résolution
qu'au §6 bis) sont décrits à l'IA pour qu'elle les réutilise sans en réinventer l'apparence.

```bash
cd ~/.zen/Astroport.ONE/IA/generators
./generate_storyboard.sh                      # choix du moteur interactif
./generate_storyboard.sh -m gemma3:latest -o storyboards/essai.json
```

Propose ensuite de lancer `generate_scene.sh` directement. Le JSON produit reste un point de
départ : le relire et le corriger à la main avant un rendu long reste plus sûr qu'une confiance
aveugle dans la sortie du modèle (un modèle peut par exemple ajouter un carton ou un lien non
demandé — demandez-lui explicitement de ne pas le faire si vous ne voulez aucun carton).

**À la main.** Exemples complets dans `IA/generators/storyboards/`. Squelette (`lea` déjà dans
`$CAST_BANK` — un rendu précédent, ou la bibliothèque du Studio web — sinon
`{"image_prompt": "…", "voice_design": "…", "voice_line": "…"}` ou
`{"image": "/chemin.png", "voice": "/chemin.wav"}`) :

```json
{
  "ratio": "16:9", "megapixels": 0.3, "steps": 10, "ref_steps": 20,
  "style": "clean", "height": 720, "seed": 5005,
  "cast": {
    "lea": {}
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

Plus rapide pour itérer sur un seul plan : `-i INDEX` (0-based) calcule ce plan et
s'arrête — pas de finition ni d'assemblage de toute la scène :

```bash
./generate_scene.sh -w ~/.zen/workspace/scenes/episode06 -i 2 storyboards/episode06.json
```

La prise précédente de ce plan n'est pas perdue si un autre mécanisme l'archive avant
de la remplacer (c'est ce que fait l'interface Studio web, §6 bis — « Générer ce
plan ») ; en CLI pur, `shot_NN.mp4` est simplement écrasé.

Défauts rencontrés et remèdes :

| Symptôme | Cause | Remède |
|---|---|---|
| Plan en style dessin, dominante verte, rectangles de pseudo-texte | ref2va à 10 steps | `ref_steps` ≥ 20 (défaut) |
| Visage différent de l'acteur, fond de studio | deux acteurs dans le même plan | un acteur par plan |
| Visage étiré | image de départ d'un autre ratio (MiniMax l'étire) | recadrage automatique au ratio ; générer l'image au bon format (`IMAGE_SIZE`) |
| « Piercing » ou détails inventés après upscale | base trop basse (visage de ~60 px) + SeedVR2 | gros plans, 0,3-0,4 MP, pas de SeedVR2 |
| Mots mal prononcés (NOSTR → « nocester », uDRIVE, UMAP…) | sigles lus « à l'aveugle » | ajouter le mot à `lib/prononciation_fr.json` |
| Titre qui chevauche l'incrustation | — | automatique : titre en haut sur les plans `presenter` |

### 6 bis. Studio vidéo IA : partager, modifier, générer, supprimer, récupérer (Kind 30510)

Page `UPlanet/earth/story.html` (menu « Studio vidéo IA ») ou, en ligne de commande, `tools/story_asset.py` —
**même moteur `generate_scene.sh`/`generate_character.sh` des deux côtés** : un storyboard ou un personnage
fonctionne à l'identique en CLI pur ou lancé depuis la page web, et les deux usages se complètent (voir
« Uniformiser CLI et Web » plus bas).

**Paquets.** Un personnage (`cast/<nom>/` : portrait, voix, fiche `character.json`) ou une scène (`storyboard.json`
+ images + casting, éventuellement `scene.mp4`) est un tar.gz chiffré en AES-256-GCM (méthode uCloud), ajouté à
IPFS, annoncé par un événement public **Kind 30510** (titre, type, CID, hash, historique, rendus). Jamais de clé
dans l'événement. Signature : MULTIPASS du Capitaine.

| Portée | Clé | Qui lit | Comment |
|---|---|---|---|
| `private` | aléatoire par version, keyring local 0600 | vos amis | clé envoyée par message fichier NIP-17 (`--share`) ; **sauvegardée en plus par DM NOSTR à soi-même** (voir « Récupérer après suppression ») |
| `coop` | `sha256("uplanet-story-assets:v1:" + $UPLANETNAME)`, comme `cooperative_config.sh` | **tous les Capitaines** de la coopérative | rien à échanger ; propagé par la synchro constellation (kind 30510 dans `backfill_constellation.sh`) |

Chaque Capitaine modifie ses propres paquets ; pour changer celui d'un autre : **copier** (`fork`) dans sa bibliothèque.
Les stations qui consultent un paquet coopératif l'épinglent : la coopérative le conserve.

**Versions.** Chaque enregistrement crée un nouveau paquet (nouveau CID) sous le même d-tag : l'événement garde la
liste `history` et les anciens CID restent épinglés. On peut rouvrir n'importe quelle version, voir ses rendus, ou la
**restaurer** (nouvelle version identique ; l'historique n'est jamais réécrit).

**Générer.** Bouton « Générer » : un job détaché lance `generate_scene.sh` (scène) ou `generate_character.sh`
(portrait Z-Image + voix Qwen3-TTS). Un seul job à la fois (une carte graphique), les autres attendent. Le suivi
vient de `progress.json` (étapes, plan en cours, plans terminés) : chaque plan terminé se regarde et s'écoute dans sa
vignette avant la fin. Le répertoire de travail sert de cache entre versions : un plan ou un acteur inchangé n'est pas
recalculé (signature de leur contenu). Les rendus sont archivés par version ; pour une scène coopérative, la vidéo est
ajoutée à IPFS et annoncée dans `renders` (les autres Capitaines la voient et l'entendent) ; un rendu privé ne quitte
pas la station (`STORY_NO_IPFS`).

Enregistrer et générer sont deux actions **séparées** : « Générer » reste désactivé tant qu'il y a des modifications
non enregistrées (pas d'enregistrement silencieux d'une nouvelle version juste pour prévisualiser un rendu).

**Générer un seul plan.** Bouton « 🎬 Générer ce plan » sur chaque vignette (ou `-i INDEX` en CLI, §6) : relance
juste ce plan dans le même répertoire de travail que la scène (acteurs et autres plans déjà calculés ne sont pas
retouchés), sans finition ni assemblage — pour itérer vite sur un plan qui ne convient pas. La prise précédente de
ce plan n'est jamais perdue : archivée côté serveur avant d'être remplacée, rejouable depuis « Prises précédentes »
(repliable, sous la vignette).

**Supprimer.** Bouton « Supprimer » (ou `tools/story_asset.py delete <cid>`) : retire toute la lignée de versions de
*votre* bibliothèque et publie une demande de suppression NIP-09 (kind 5) pour l'événement courant — honorée au
mieux par les relais, jamais garantie (NOSTR n'efface rien de force). Les blobs restent épinglés sur IPFS, comme
pour toute ancienne version ; un paquet coopératif peut rester visible chez d'autres Capitaines tant qu'ils n'ont
pas fait de même.

**Exporter / importer.** Bouton « Exporter » télécharge le paquet **en clair** (tar.gz, hors chiffrement/IPFS/NOSTR
de cette station) — sauvegarde locale, ou transfert manuel vers une autre station. « Importer un paquet… » dans la
bibliothèque l'installe comme nouvel asset (nouvelle clé, nouveau CID, nouvelle lignée — comme un `fork` mais
depuis un fichier local). Équivalent CLI :

```bash
tools/story_asset.py export <cid> -o perso.tar.gz
tools/story_asset.py importpkg perso.tar.gz --scope private --name "Ma copie"
```

```bash
tools/story_asset.py create scene "Visite du village" --scope coop
tools/story_asset.py update <cid> --set storyboard.json=sb.json --description "plan 2 réécrit"
tools/story_asset.py versions <cid> ; tools/story_asset.py restore <ancien_cid>
tools/story_asset.py fork <cid_d_un_autre_capitaine> --name "Ma version"
tools/story_asset.py publish scene "Épisode 6" storyboard.json --video scene.mp4 --share <hex_ami>   # privé
tools/story_asset.py import <cid> --key <hex> --sha256 <hex>      # côté ami, valeurs du DM
tools/story_asset.py delete <cid>                                 # retire + demande de suppression NIP-09
```

API (UPassport, NIP-98, Capitaine) : `/api/story/*`, voir `UPassport/CLAUDE.md`. Le visage et la voix d'une personne
réelle ne se partagent qu'avec son consentement. Les rendus d'une scène coopérative sont publics (IPFS).

#### Stockage : disque, NOSTR, IPFS

| Où | Quoi |
|---|---|
| `$SCENES_DIR/library/keyring.json` | Mes paquets : CID → `{scope, clé AES (si private), hash, event_id, version, lignée…}`, 0600. La clé `coop` n'y est **jamais** stockée (recalculée à la volée depuis `$UPLANETNAME`). |
| `$SCENES_DIR/library/renders.json`, `library/jobs/*.json` | Index des rendus scène entière ; état des jobs (survit à un redémarrage d'UPassport). |
| `$SCENES_DIR/renders/<auteur8>-<d>/src/` | Paquet **déchiffré** de la version en cours de rendu. |
| `$SCENES_DIR/renders/<auteur8>-<d>/work/` | Cache incrémental (`shot_NN.mp4`, portraits/voix, fichiers `.sig`) : un plan ou un acteur inchangé n'est jamais recalculé. |
| `$SCENES_DIR/renders/<auteur8>-<d>/v/<cid>/<job>/` | Rendus archivés (scène entière), en liens physiques pour ne pas dupliquer les plans réutilisés. |
| `$SCENES_DIR/renders/<auteur8>-<d>/v/<cid>/shots/<NN>/` | Prises archivées d'un plan généré isolément. |
| `$CAST_BANK` (CLI : `~/.zen/workspace/characters/`, Web : une banque par rendu) | Portraits/voix en clair, pour `generate_scene.sh`/`generate_character.sh` — voir « Uniformiser CLI et Web ». |
| **IPFS** | Chaque version est un tar.gz **chiffré** AES-256-GCM, ajouté via `ipfs add`. Les anciens CID restent épinglés pour toujours (historique/restauration). Pour un rendu `coop`, la vidéo finale en clair est *en plus* ajoutée séparément, pour que les autres Capitaines la regardent sans déchiffrer le paquet. |
| **NOSTR** | Un événement **Kind 30510** (remplaçable, NIP-33) par lignée de paquet, republié à chaque version. Contenu toujours public (titre, type, CID, hash, historique, rendus) — **jamais la clé**. Relais local (strfry, 7777), propagé à la constellation. La suppression publie un **Kind 5** (NIP-09, best-effort). |

#### Uniformiser CLI et Web

Les deux usages partagent le **même format de storyboard** et le **même moteur** (`generate_scene.sh` /
`generate_character.sh`) — aucune divergence de ce côté. Ce qui diffère, c'est l'endroit où vivent les
*personnages* : la banque CLI (`$CAST_BANK`, en clair sur disque) et la bibliothèque Studio web (paquets chiffrés
IPFS/NOSTR) sont deux magasins distincts, pour ne jamais faire écraser vos personnages par un paquet partagé du
même nom pendant un rendu web.

Le pont entre les deux est une **résolution automatique en lecture** : si un acteur est déclaré `"nom": {}` dans un
storyboard lancé en CLI et qu'il est absent de `$CAST_BANK`, `generate_scene.sh` cherche un personnage de ce nom
dans la bibliothèque du Studio (le vôtre, sinon celui d'un Capitaine coopératif) et l'installe automatiquement
avant de continuer :

```text
Acteur lea : recherche dans la bibliothèque du Studio (NOSTR/IPFS)…
Acteur lea : trouvé dans la bibliothèque, installé dans la banque
```

Dans l'autre sens (rendre utilisable en CLI un personnage créé côté web), ou pour l'installer ailleurs qu'un
rendu de scène :

```bash
tools/story_asset.py resolve-character lea --dest ~/.zen/workspace/characters/lea
```

⚠️ **`library/` (le trousseau) est indépendant de `$SCENES_DIR`.** Un rendu du Studio web isole chaque paquet dans
son propre bac à sable (`SCENES_DIR` surchargé vers `renders/<auteur>-<d>/src/`, pour que les chemins
`$SCENES_DIR/...` écrits dans un storyboard pointent dedans). Mais le trousseau — quels paquets sont « à moi », avec
quelle clé — est une ressource globale de la station, jamais propre à un rendu : `story_asset.py` résout toujours
`library/` depuis `$STORY_LIBRARY_DIR` (par défaut `~/.zen/workspace/scenes/library`), **pas** depuis `$SCENES_DIR`.
Sans ce découplage, `resolve-character` appelé en sous-processus d'un rendu web verrait une bibliothèque vide.

#### Récupérer après suppression de `$SCENES_DIR`

Si `~/.zen/workspace/scenes/` (donc `library/keyring.json`, source de vérité locale) est supprimé :

- Les paquets **`coop`** sont **toujours** entièrement récupérables : leur clé se recalcule depuis `$UPLANETNAME`
  (jamais stockée nulle part), et leurs métadonnées (titre, historique) viennent du relais NOSTR.
- Les paquets **`private`** ne le sont que si leur clé a été sauvegardée : à chaque version, `seal()` envoie
  automatiquement un **DM NOSTR chiffré à soi-même** (kind 4, même mécanisme que BRO) contenant CID + clé — un
  paquet dont la clé n'a jamais été sauvegardée ainsi (créé avant l'ajout de cette fonction, ou sur une station
  sans relais joignable au moment de la publication) reste listé après reconstruction mais **non déchiffrable**.

```bash
tools/story_asset.py rebuild              # refuse si library/keyring.json existe déjà et n'est pas vide
tools/story_asset.py rebuild --force      # reconstruit quand même (écrase l'existant)
```

Rebalaie le relais pour vos propres Kind 30510 (titre, type, CID, historique par lignée), déchiffre les
sauvegardes de clé self-DM pour les paquets `private`, dérive la clé coopérative pour les paquets `coop`, et
réécrit `library/keyring.json`. Rapporte `{lineages, versions, recovered, unrecoverable}` — `unrecoverable` compte
les versions `private` sans sauvegarde de clé retrouvée. Un paquet reconstruit ouvre et déchiffre normalement
(`tools/story_asset.py get <cid>`) dès que sa clé a été récupérée.

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
| `generate_storyboard.sh` | Assistant interactif (questions + Ollama via `../question.py`) → `storyboard.json`, avec validation/retry |
| `generate_minimax.sh` | Un plan MiniMax H3 : t2v, i2v (`-i`), références ref2va (`-R` image, `-A` audio), `-o` fichier, `-S` seed, `-u` SeedVR2, `DRY_RUN=1` |
| `generate_image.sh` | Image Z-Image Turbo int8 (repli Flux schnell si le modèle manque), taille via `IMAGE_SIZE=LxH` |
| `video_finish.sh` | `-s LxH` taille exacte, `-v` style VHS ; 24 i/s, AAC 48 kHz stéréo |
| `workflow/video_minimax_h3_t2v_api.json` | Template ComfyUI `video_minimax_h3_t2v` au format API (subgraph aplati) + `VRAM_Debug` |
| `workflow/ZImageTurbo.json` | Workflow Z-Image (mêmes IDs de nodes que `FluxImage.json`) |
| `lib/env.sh` | Chemins des outils (ffmpeg, pythons, ComfyUI, scènes), surchargeables |
| `lib/capture_page.py` | Capture Playwright (`--full`, `--wait`, `--js`) |
| `lib/git_timeline.py` | Frise HTML commits/mois + jalons |
| `lib/pronounce.py`, `lib/prononciation_fr.json` | Orthographe phonétique des répliques + consigne de diction |
| `lib/energy_window.py` | Énergie CPU + GPU entre deux instants, d'après le CSV 24/7 de PowerJoular |
| `lib/comfyui_recovery.sh` | Diagnostic OOM, retry après libération VRAM (local uniquement) |
| `storyboards/*.json` | Épisodes 1-6 |

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
| `voice` | `amelie` | voix Orpheus de secours des `voiceover` (`amelie`, `pierre`), utilisée si `narrator` absent ou Qwen3-TTS non installé |
| `narrator.voice_design` | — | voix-off constante (Qwen3-TTS, prononciation du lexique) : une seule synthèse, clonée pour chaque plan. Nécessite `install/install_qwen3_tts.sh` |
| `narrator.ref` | — | fichier audio de référence pour cloner la voix du narrateur (sinon générée depuis `voice_design` puis réutilisée) |
| `cast` | — | `{nom: {image\|image_prompt, voice\|voice_line, voice_design?, refresh?}}` — voir §2 et §6 bis (banque de personnages) |

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

Énergie mesurée (PowerJoular, CPU + GPU, sans RAM, disques ni alimentation) :
épisode 5 (11 plans, 94 s) = **513 Wh en 78 min** (GPU 413 Wh, CPU 100 Wh, moyenne
402 W, pic 447 W). La station consomme ~70-125 W au repos.

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

Pour tout personnage ou scène passé par le Studio web ne serait-ce qu'une fois (publié,
même en `private`), `~/.zen/workspace/scenes/` lui-même devient récupérable depuis
NOSTR/IPFS si on le supprime — voir « Récupérer après suppression de `$SCENES_DIR` » au
§6 bis (`tools/story_asset.py rebuild`). Pour un usage CLI pur jamais publié comme
paquet, cette section reste la seule protection : rien d'autre que ce répertoire ne
garde le portrait, la voix ou le montage.
