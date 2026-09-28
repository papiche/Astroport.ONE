#!/bin/bash
# Dependencies : ffmpeg
#### video_finish.sh : mise à l'échelle 720p (ou autre) + style VHS optionnel
#
# Usage: video_finish.sh [-v] [-H hauteur] <entrée.mp4> <sortie.mp4>
#   -v  style lecteur VHS : bavure et décalage chroma, flou horizontal, grain,
#       lignes de balayage, vignettage, couleurs délavées, son filtré.
#       Masque bien les défauts d'une vidéo calculée en basse résolution.
#   -H  petit côté de la sortie en pixels (défaut 720 : 1280x720 ou 720x1280)

VHS=0
SHORT_SIDE=720
while getopts "vH:h" opt; do
  case $opt in
    v) VHS=1 ;;
    H) SHORT_SIDE="$OPTARG" ;;
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

ffmpeg -v error -y -i "$IN" -vf "$vf" -af "$af" \
       -c:v libx264 -preset fast -crf 20 -pix_fmt yuv420p -c:a aac -b:a 160k \
       -movflags +faststart "$OUT" || exit 1
echo "$OUT"
