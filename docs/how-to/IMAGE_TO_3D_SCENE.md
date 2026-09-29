# Transformer une photo en scène 3D pour Blender

## Problème

À partir d'une seule photo (une pièce, un décor), obtenir une scène 3D **dont chaque
objet est séparé, nommé et texturé**, placée comme sur la photo et importable
directement dans Blender (`Fichier → Importer → glTF 2.0`).

C'est l'idée de [Mira-Scene](https://github.com/VAST-AI-Research/Mira-Scene)
(VAST-AI-Research, MIT), refaite avec les nodes natifs de ComfyUI et un modèle de
vision local : pas de service externe (Mira-Scene appelle l'API Tripo/Gemini pour la
segmentation), pas de nouvel environnement Python.

## Prérequis

- ComfyUI ≥ 0.36 sur la station, avec les modèles :

| Rôle | Fichier (`ComfyUI/models/`) | Source |
|---|---|---|
| Segmentation | `checkpoints/sam3.1_multiplex_fp16.safetensors` (1,75 Go) | [Comfy-Org/sam3.1](https://huggingface.co/Comfy-Org/sam3.1) |
| Géométrie de la scène | `geometry_estimation/moge_2_vitl_normal_fp16.safetensors` (0,66 Go) | [Comfy-Org/MoGe](https://huggingface.co/Comfy-Org/MoGe) |
| Objet 3D | `diffusion_models/pixal3d_bf16.safetensors`, `clip_vision/dino_v3_L_naf_fp32.safetensors`, `vae/trellis_2_shape_vae_bf16.safetensors`, `vae/trellis_2_texture_vae_bf16.safetensors` | [Comfy-Org/Pixal3D](https://huggingface.co/Comfy-Org/Pixal3D) |
| Détourage | `background_removal/birefnet.safetensors` (0,44 Go) | [Comfy-Org/BiRefNet](https://huggingface.co/Comfy-Org/BiRefNet) |

- Ollama avec un modèle de vision (`minicpm-v`) pour lister les objets
  automatiquement — ou donner la liste soi-même. (`llama3.2-vision` ne se charge
  plus avec les versions récentes d'Ollama.)
- `~/comfyui_env` (trimesh, numpy, PIL).

## Étapes

```bash
cd ~/.zen/Astroport.ONE/IA/generators
./generate_3dscene.sh photo.jpg                                   # objets détectés par minicpm-v
./generate_3dscene.sh photo.jpg "armchair,side table,lamp,plant"  # objets imposés (anglais)
```

La commande affiche l'URL IPFS du dossier de résultat. Pour garder la main sur les
options, appeler directement le script Python :

```bash
~/comfyui_env/bin/python image_to_3dscene.py photo.jpg \
  --objects "armchair,lamp" --faces 150000 --workdir ~/.zen/workspace/scenes3d/salon
```

Relancer avec le même `--workdir` réutilise les objets déjà modélisés : seuls la
segmentation, le placement et l'assemblage sont refaits (~30 s).

Ce que fait la chaîne :

1. **Objets** : liste donnée, ou demandée à `minicpm-v` (Ollama libère sa VRAM juste
   après, `keep_alive: 0`) ; les éléments du décor (mur, sol…) sont écartés.
2. **SAM3** (`SAM3_Detect`) : un masque par instance de chaque objet. Un masque
   contenu à plus de 60 % dans un objet déjà placé est ignoré (« pot » dans « plante
   en pot »).
3. **MoGe** : nuage de points métrique de la photo, repère caméra (origine = caméra,
   regard vers −z, y vers le haut), et maillage du décor.
4. **Pixal3D** : un GLB texturé (PBR) par objet, à partir de sa découpe
   (workflow `workflow/pixal3d_image_to_model_api.json`, converti du template
   ComfyUI `3d_pixal3d_trellis2_image_to_model`).
5. **Placement** : face avant de l'objet sur les points visibles les plus proches,
   échelle et position ajustées pour que sa silhouette projetée recouvre le cadre du
   masque. Pas de rotation : Pixal3D rend l'objet dans l'orientation de la photo.
6. **Assemblage** : `scene.glb` = décor (sans la surface des objets, pour éviter les
   doublons) + un nœud par objet.

## Résultat attendu

Dans le dossier de travail (`~/.zen/workspace/scenes3d/<photo>_<date>/`) :

| Fichier | Contenu |
|---|---|
| `scene.glb` | scène complète : nœud `background` + un nœud nommé par objet (`green_velvet_chair_1`…) |
| `<objet>_N.glb` | chaque objet seul, centré |
| `preview.png` | rendu de contrôle vu depuis la caméra, à comparer avec la photo |
| `manifest.json` | FOV, pixels et dimensions (m) de chaque objet |

Test (salon, 4 objets) sur RTX 3090 : **21 min** (Pixal3D 90 à 230 s par objet,
SAM3 et MoGe 3 s chacun), scène de ~90 Mo, dimensions plausibles (fauteuil ~1 m,
ficus 1,6 m).

## Limites

- Les parties cachées des objets sont **inventées** par Pixal3D.
- Pas de rotation : un objet vu de biais garde l'orientation de sa découpe.
- Échelle métrique approximative (MoGe estime la profondeur à partir d'une seule
  image).
- Dans le décor, les zones masquées par les objets restent des trous.
