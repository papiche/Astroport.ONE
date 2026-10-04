#!/bin/bash
# Dependencies : ffmpeg
#### video_finish.sh : mise à l'échelle 720p (ou autre) + style VHS optionnel
#
# Usage: video_finish.sh [-v] [-H hauteur | -s LxH] <entrée.mp4> <sortie.mp4>
#   -v  style lecteur VHS : bavure et décalage chroma, flou horizontal, grain,
#       lignes de balayage, vignettage, couleurs délavées, son filtré.
#       Masque bien les défauts d'une vidéo calculée en basse résolution.
#   -H  petit côté de la sortie en pixels (défaut 720 : 1280x720 ou 720x1280)
#   -s  taille exacte (ex. 1280x720) : recadrage centré si le ratio diffère.
#       Sortie toujours en 24 i/s, AAC 48 kHz stéréo (plans concaténables).

VHS=0
SHORT_SIDE=720
SIZE=""
. "$(dirname "$(readlink -f "$0")")/lib/env.sh"   # FFMPEG / FFPROBE (avec drawtext)
while getopts "vH:s:h" opt; do
  case $opt in
    v) VHS=1 ;;
    H) SHORT_SIDE="$OPTARG" ;;
    s) SIZE="$OPTARG" ;;
    *) sed -n '5,9p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 1 ;;
  esac
done
shift $((OPTIND - 1))
IN="$1"
OUT="$2"
if [ ! -f "$IN" ] || [ -z "$OUT" ]; then
  sed -n '5,9p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 1
fi

# Petit côté à SHORT_SIDE, fonctionne en paysage comme en portrait (smartphone)
scale="scale='if(gt(iw,ih),-2,${SHORT_SIDE})':'if(gt(iw,ih),${SHORT_SIDE},-2)':flags=lanczos"
if [[ "$SIZE" =~ ^([0-9]+)x([0-9]+)$ ]]; then
  w=${BASH_REMATCH[1]} h=${BASH_REMATCH[2]}
  scale="scale=${w}:${h}:force_original_aspect_ratio=increase:flags=lanczos,crop=${w}:${h},setsar=1"
fi

if [ "$VHS" = 1 ]; then
  vf="${scale},format=yuv420p"
  vf+=",scale=iw/2:ih:flags=bilinear,scale=iw*2:ih:flags=bicubic"  # bande passante horizontale réduite
  vf+=",chromashift=cbh=3:crh=-3,rgbashift=rh=-2:bh=2"             # bavure et décalage des couleurs
  vf+=",eq=contrast=1.06:brightness=0.03:saturation=1.3:gamma=1.04"
  vf+=",colorbalance=rs=0.04:bs=-0.04:rh=0.03"                       # dominante chaude délavée
  vf+=",noise=alls=10:allf=t"                                        # grain animé
  vf+=",drawgrid=w=iw:h=3:t=1:c=black@0.18"                          # lignes de balayage
  vf+=",vignette=PI/5"
  af="highpass=f=80,lowpass=f=10000"
else
  vf="$scale"
  af="anull"
fi

# La piste audio doit couvrir TOUTE la durée de la vidéo : un plan dont l'audio s'arrête avant l'image
# (voix-off plus courte que le plan) laisse un trou que le muxer MP4 absorbe dans le dernier paquet
# audio ; à la lecture, le son des plans suivants arrive alors en avance (coupures, lipsync décalé).
# apad complète par du silence, -shortest s'arrête à la fin de l'image ; sans piste audio, silence.
if [ -n "$("$FFPROBE" -v error -select_streams a -show_entries stream=index -of csv=p=0 "$IN" | head -1)" ]; then
  src_audio=(-i "$IN"); amap=(-map 0:v -map 0:a)
else
  src_audio=(-i "$IN" -f lavfi -i anullsrc=r=48000:cl=stereo); amap=(-map 0:v -map 1:a)
fi
"$FFMPEG" -v error -y "${src_audio[@]}" -vf "${vf},fps=24" -af "${af},apad" "${amap[@]}" -shortest \
       -c:v libx264 -preset fast -crf 20 -pix_fmt yuv420p -c:a aac -b:a 160k -ar 48000 -ac 2 \
       -movflags +faststart "$OUT" || exit 1
echo "$OUT"
