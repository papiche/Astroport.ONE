#!/bin/bash
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "$MY_PATH/my.sh"

#Set Path to Images
img_dir="$1"

if [[ ! -d $img_dir ]]; then
    PLAYERONE=($(ls -t ~/.zen/game/players/  | grep "@" 2>/dev/null))
        [[ ! $PLAYERONE ]] && echo "NO PLAYER IN THE GAME HERE" && exit 1

        echo "ASTROPORT STATION CAROUSEL MODE"
        rm -Rf ~/.zen/tmp/carousel 2>/dev/null
        mkdir -p ~/.zen/tmp/carousel
        # Make it with latest PLAYERS WALLETS
        ## RUNING FOR ALL LOCAL PLAYERS
        for PLAYER in ${PLAYERONE[@]}; do

                pub=$(cat ~/.zen/game/players/$PLAYER/.g1pub)

                # Get PLAYER wallet amount :: ~/.zen/game/players/${PLAYER}/ipfs/G1SSB/COINS
                echo $MY_PATH/jaklis/jaklis.py -k ~/.zen/game/players/${PLAYER}/secret.dunikey balance
                COINS=$(${MY_PATH}/timeout.sh -t 3 $MY_PATH/jaklis/jaklis.py -k ~/.zen/game/players/${PLAYER}/secret.dunikey balance | cut -d '.' -f 1)
                echo "+++ ${PLAYER} have $COINS Ğ1 Coins +++"

                ## USE G1BARRE SERVICE AS 1ST IMAGE
                curl -so ~/.zen/tmp/carousel/${pub}.one.png \
                "https://g1sms.fr/g1barre/image.php?pubkey=${pub}&target=20000&title=${PLAYER}&node=g1.asycn.io&start_date=2020-01-01&display_pubkey=true&display_qrcode=true"
                echo "GOT ~/.zen/tmp/carousel/${pub}.png"

                ## WRITE ON IT : ASK FOR REFILL
                convert -font 'Liberation-Sans' \
                -pointsize 80 -fill black -draw 'text 150,150 "'"$COINS"'"' \
                "${HOME}/.zen/tmp/carousel/${pub}.one.png" "${HOME}/.zen/tmp/carousel/${pub}.png"

                ## PREPARE LOOP LINK LINE
                ASTRONAUTENS=$(cat ~/.zen/game/players/${PLAYER}/.playerns)
                [[ $COINS -gt 0 ]] \
                && echo "<a href=\"javascript:homeAstroportStation($myASTROPORT/?qrcode=$ASTRONAUTENS)\" title=\"$PLAYER ($COINS G1)\">_REPLACE_</a>" > ~/.zen/tmp/carousel/${pub}.insert \
                || echo "_REPLACE_" > ~/.zen/tmp/carousel/${pub}.insert

                ## DEBUG PATCH
                echo "<a href=\"javascript:homeAstroportStation('"$myASTROPORT"/?qrcode="$ASTRONAUTENS"', 'tab', '2500')\" title=\"$PLAYER ($COINS G1)\">_REPLACE_</a>" > ~/.zen/tmp/carousel/${pub}.insert

        done
        img_dir="$HOME/.zen/tmp/carousel"
fi

#Set Path to HTML page
html_file="/tmp/index.html"
core_file="/tmp/core.html"

#Create HTML page
echo "<!DOCTYPE html>
<html>
<head>
<title>Astroport ZEN Gallery : $myIP</title>
<meta charset=\"UTF-8\">
</head>
<body>" > $html_file

echo "<link rel=\"stylesheet\" href=\"/ipfs/QmX9QyopkTw9TdeC6yZpFzutfjNFWP36nzfPQTULc4cYVJ/bootstrap.min.css\">
    <script src=\"/ipfs/QmPas4hhJypYaYD5wCe6Ltz7QhnJeYd8G2erseHADNVcH1/astro.js\"></script>

<style>
.carousel-item {
    background-color: #0B0C10;
}
.carousel-indicators li {
    background-color: #0B0C10;
}
.carousel-indicators .active {
    background-color: #FFFFFF;
}
</style>

  <h2> $myHOST : $(date) </h2>

<div class=\"container\">

  <div id=\"myCarousel\" class=\"carousel slide\" data-ride=\"carousel\">
    <!-- Indicators -->
    <ul class=\"carousel-indicators\">
      <li data-target=\"#myCarousel\" data-slide-to=\"0\" class=\"active\"></li>" > $core_file

#Loop over images
num=1
for i in "$img_dir"/*; do
if [[ $i =~ \.(JPG|jpg|PNG|png|JPEG|jpeg|GIF|gif)$ ]]; then
  if [ $num -ne 1 ]; then
    echo "      <li data-target=\"#myCarousel\" data-slide-to=\"$num\"></li>" >> $core_file
  fi
  num=$((num+1))
fi
done

echo "    </ul>

    <!-- The slideshow -->
    <div class=\"carousel-inner\">" >> $core_file

#Loop over images
num=1
for i in "$img_dir"/*; do
if [[ $i =~ \.(JPG|jpg|PNG|png|JPEG|jpeg|GIF|gif)$ ]]; then


  ilink=$(ipfs add -q "$i")
  img_info=$(identify -format '%w %h %[EXIF:*]' "$i")
  img_width=$(echo $img_info | cut -d ' ' -f1)
  img_height=$(echo $img_info | cut -d ' ' -f2)
  img_alt=$(echo $img_info | cut -d ' ' -f3)

  MORE="${i%.png}.insert"
  echo "$MORE"
  LINK="<img src=\"/ipfs/$ilink\" alt=\"$img_alt\" width=\"$img_width\" height=\"$img_height\">"
  [[ -s $MORE ]] && ZLINK=$(cat $MORE | sed "s~_REPLACE_~$LINK~g") || ZLINK="$LINK"

  echo $ZLINK

  if [ $num -eq 1 ]; then
    echo "      <div class=\"carousel-item active\">
        $ZLINK
      </div>" >> $core_file
  else
    echo "      <div class=\"carousel-item\">
        $ZLINK
      </div>" >> $core_file
  fi
  num=$((num+1))
fi
done

echo "    </div>

    <!-- Left and right controls -->
    <a class=\"carousel-control-prev\" href=\"#myCarousel\" data-slide=\"prev\">
      <span class=\"carousel-control-prev-icon\"></span>
    </a>
    <a class=\"carousel-control-next\" href=\"#myCarousel\" data-slide=\"next\">
      <span class=\"carousel-control-next-icon\"></span>
    </a>
  </div>
</div>

<script src=\"/ipfs/QmX9QyopkTw9TdeC6yZpFzutfjNFWP36nzfPQTULc4cYVJ/jquery-3.2.1.slim.min.js\"></script>
<script src=\"/ipfs/QmX9QyopkTw9TdeC6yZpFzutfjNFWP36nzfPQTULc4cYVJ/popper.min.js\"></script>
<script src=\"/ipfs/QmX9QyopkTw9TdeC6yZpFzutfjNFWP36nzfPQTULc4cYVJ/bootstrap.min.js\"></script>" >> $core_file

cat $core_file >> $html_file
echo "</body></html>" >> $html_file

htmlipfs=$(ipfs add -q $html_file)
[[ $XDG_SESSION_TYPE == 'x11' ]] && xdg-open http://ipfs.localhost:8080/ipfs/$htmlipfs
echo /ipfs/$htmlipfs

exit 0
