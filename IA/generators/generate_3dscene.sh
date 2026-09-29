#!/bin/bash
# Dependencies : ComfyUI (SAM3, MoGe, Pixal3D), Ollama (modèle de vision), ipfs
#### generate_3dscene.sh : une photo → scène 3D GLB (objets séparés et nommés) pour Blender
#
# Usage: generate_3dscene.sh <image> [objets] [udrive_path]
#   objets : liste « fauteuil,lampe » en anglais (invites SAM3) ; vide = détection par
#            le modèle de vision local (Ollama, minicpm-v)
# Sortie stdout : URL IPFS du dossier (scene.glb, preview.png, manifest.json, un GLB par objet)
# Détail et limites : docs/how-to/IMAGE_TO_3D_SCENE.md

MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"${MY_PATH}\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

IMAGE="$1"
OBJECTS="$2"
UDRIVE_PATH="$3"
if [ ! -f "$IMAGE" ]; then
  echo "Usage: $ME <image> [objets] [udrive_path]" >&2
  exit 1
fi

. "${HOME}/.zen/Astroport.ONE/tools/my.sh"

WORK_DIR="$HOME/.zen/workspace/scenes3d/$(basename "${IMAGE%.*}")_$(date +%s)"
args=("$IMAGE" --workdir "$WORK_DIR")
[ -n "$OBJECTS" ] && args+=(--objects "$OBJECTS")

"$HOME/comfyui_env/bin/python" "$MY_PATH/image_to_3dscene.py" "${args[@]}" > /dev/null || exit 1

if [ -n "$UDRIVE_PATH" ] && [ -d "$UDRIVE_PATH" ]; then
  cp "$WORK_DIR/scene.glb" "$UDRIVE_PATH/$(basename "${IMAGE%.*}")_scene.glb"
fi

ipfs_hash=$(ipfs add -rwq "$WORK_DIR" 2>/dev/null | tail -n 1)
if [ -n "$ipfs_hash" ]; then
  echo "$myIPFS/ipfs/$ipfs_hash/$(basename "$WORK_DIR")/scene.glb"
else
  echo "$WORK_DIR/scene.glb"
fi
