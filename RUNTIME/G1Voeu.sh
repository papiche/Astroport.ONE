#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"${MY_PATH}\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/../tools/my.sh"
################################################################################
# Create G1VOEU TW for PLAYER
# Mon Titre => G1MonTitre
## PARAM : "TITRE DU VOEU" "PLAYER" "INDEX"
################################################################################
TITRE="$1"
PLAYER="$2"
INDEX="$3"

[[ ${PLAYER} == "" ]] && PLAYER=$(cat ~/.zen/game/players/.current/.player 2>/dev/null)
[[ ${PLAYER} == "" ]] && echo "Second paramètre PLAYER manquant" && exit 1
PSEUDO=$(cat ~/.zen/game/players/${PLAYER}/.pseudo 2>/dev/null)
[[ $G1PUB == "" ]] && G1PUB=$(cat ~/.zen/game/players/${PLAYER}/.g1pub 2>/dev/null)
[[ $G1PUB == "" ]] && echo "Troisième paramètre G1PUB manquant" && exit 1

[[ ! $INDEX ]] && INDEX="$HOME/.zen/game/players/${PLAYER}/ipfs/moa/index.html"
echo $INDEX
[[ ! -s $INDEX ]] && echo "TW ${PLAYER} manquant" && exit 1

echo "Working on $INDEX"

ASTRONAUTENS=$(ipfs key list -l | grep -w "${PLAYER}" | cut -d ' ' -f 1)
[[ $ASTRONAUTENS == "" ]] && echo "CLEF IPNS ASTRONAUTE MANQUANTE - EXIT -" && exit 1

echo "Bienvenue $PSEUDO (${PLAYER}) : $G1PUB"
echo

######################################################################
MOATS="$4"
[[ ! ${MOATS} ]] && MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
mkdir -p ~/.zen/tmp/${MOATS}

#####################################################
# CREATION DE LA CLEF DERIVEE "G1VOEU"
#####################################################
source ~/.zen/game/players/${PLAYER}/secret.june ## LE PEPPER DU PLAYER DEVIENT LE SALT DU G1VOEU
[[ ${PEPPER} ]] && echo "Using PLAYER PEPPER AS WISH SALT" && SECRET1=${PEPPER} ##
[[ ! ${SECRET1} ]] && SECRET1=$(${MY_PATH}/../tools/diceware.sh 3 | xargs)

#~ echo "${SECRET1}"

echo "## TITRE DU G1VOEU ? CapitalGluedWords please"
[[ ! ${TITRE} ]] && read TITRE
VoeuName=$(echo "${TITRE}" | sed -r 's/\<./\U&/g' | sed 's/ //g') # VoeuName EST LE TITRE DU VOEU : CapitalGluedWords + EMAIL

SECRET2="${VoeuName} ${PLAYER}" ## SECRET2 est "TitreDuVoeu PLAYER"

echo "${SECRET2}" && [[ ! ${SECRET2} ]] && echo "EMPTY SECRET2 - ERROR" && exit 1

echo "## keygen PLAYER DERIVATE WISH KEY"
${MY_PATH}/../tools/keygen  -t duniter -o ~/.zen/tmp/${MOATS}/wish.dunikey "${SECRET1}" "${SECRET2}"
WISHG1PUB=$(cat ~/.zen/tmp/${MOATS}/wish.dunikey | grep "pub:" | cut -d ' ' -f 2)
echo "WISHG1PUB (G1PUB) = ${WISHG1PUB}"
[[ ${WISHG1PUB} == "" ]] && echo "EMPTY WISHG1PUB G1PUB - ERROR" && exit 1
mkdir -p ~/.zen/game/players/${PLAYER}/voeux/${VoeuName}/${WISHG1PUB}/
mv ~/.zen/tmp/${MOATS}/wish.dunikey ~/.zen/game/players/${PLAYER}/voeux/${VoeuName}/${WISHG1PUB}/wish.dunikey

echo "# NOUVEAU VOEU"
mkdir -p ~/.zen/game/players/${PLAYER}/voeux/${VoeuName}/${WISHG1PUB}/
${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/game/players/${PLAYER}/voeux/${VoeuName}/${WISHG1PUB}/qrtw.ipfskey "${SECRET1}" "${SECRET2}"
ipfs key import ${WISHG1PUB} -f pem-pkcs8-cleartext ~/.zen/game/players/${PLAYER}/voeux/${VoeuName}/${WISHG1PUB}/qrtw.ipfskey
VOEUNS=$(ipfs key list -l | grep -w "${WISHG1PUB}" | cut -d ' ' -f 1 )
echo "/ipns/${VOEUNS}"

## NATOOLS ENCRYPT
echo "# NATOOLS ENCODING  qrtw.ipfskey "
${MY_PATH}/../tools/natools.py encrypt -p $G1PUB -i $HOME/.zen/game/players/${PLAYER}/voeux/${VoeuName}/${WISHG1PUB}/qrtw.ipfskey -o $HOME/.zen/tmp/${MOATS}/qrtw.ipfskey.$G1PUB.enc
ENCODING=$(cat $HOME/.zen/tmp/${MOATS}/qrtw.ipfskey.$G1PUB.enc | base16)
#~ echo $ENCODING

## TEST IPFS
#~ ipfs --timeout=30s cat --progress=false /ipns/${VOEUNS} > ~/.zen/tmp/${VOEUNS}.json
#~ [[ -s ~/.zen/tmp/${VOEUNS}.json ]] \
#~ && echo "HEY !!! UN CHANNEL EXISTE DEJA POUR CE VOEU !  ~/.zen/tmp/${VOEUNS}.json  - EXIT -" \
#~ && exit 1

echo "# UPGRADING WORLD WHISHKEY DATABASE"

mkdir -p ~/.zen/game/world/${VoeuName}/${WISHG1PUB}/
## A la fois Titre du tag et Pepper construction de clef
echo ${VoeuName} > ~/.zen/game/world/${VoeuName}/${WISHG1PUB}/.pepper
echo ${WISHG1PUB} > ~/.zen/game/world/${VoeuName}/${WISHG1PUB}/.wish

echo "# CREATION QR CODE"

LIBRA=$(head -n 2 ~/.zen/Astroport.ONE/A_boostrap_nodes.txt | tail -n 1 | cut -d ' ' -f 2)

qrencode -s 12 -o "$HOME/.zen/game/world/${VoeuName}/${WISHG1PUB}/QR.WISHLINK.png" "$LIBRA/ipns/${VOEUNS}"

#################################################################
## MAKING SPECIAL amrzqr => G1Milgram TICKET
## LE QRCODE CORRESPOND A LA CLEF DERIVE "${PLAYER} :: G1${VoeuName} ${PLAYERG1PUB}" avec PASS=YYYYMM
IMAGIC=$(${MY_PATH}/../tools/VOEUX.print.sh "${PLAYER}" "${VoeuName}" "${MOATS}" "${G1PUB}" | tail -n 1)
cp ~/.zen/tmp/${MOATS}/START.png ~/.zen/game/world/${VoeuName}/${WISHG1PUB}/

qrencode -s 12 -o "$HOME/.zen/game/world/${VoeuName}/${WISHG1PUB}/QR.ASTROLINK.png" "$LIBRA/ipns/$ASTRONAUTENS"
qrencode -s 12 -o "$HOME/.zen/game/world/${VoeuName}/${WISHG1PUB}/QR.G1ASTRO.png" "${G1PUB}"
qrencode -s 12 -o "$HOME/.zen/game/world/${VoeuName}/${WISHG1PUB}/QR.G1WISH.png" "${WISHG1PUB}:ZEN"
qrencode -s 12 -o "$HOME/.zen/game/world/${VoeuName}/${WISHG1PUB}/QR.IPNS.png" "/ipns/${VOEUNS}"

#################################
# PREMIER TYPE ~/.zen/tmp/player.png
convert $HOME/.zen/game/world/${VoeuName}/${WISHG1PUB}/QR.WISHLINK.png -resize 300 ~/.zen/tmp/QRWISHLINK.png
convert ${MY_PATH}/../images/logoastro.png  -resize 220 ~/.zen/tmp/ASTROLOGO.png

composite -compose Over -gravity NorthWest -geometry +350+10 ~/.zen/tmp/ASTROLOGO.png ${MY_PATH}/../images/Brother_600x400.png ~/.zen/tmp/astroport.png
composite -compose Over -gravity NorthWest -geometry +0+0 ~/.zen/tmp/QRWISHLINK.png ~/.zen/tmp/astroport.png ~/.zen/tmp/one.png
convert -gravity northwest -pointsize 20 -fill black -draw "text 320,250 \"${PLAYER}\"" ~/.zen/tmp/one.png ~/.zen/tmp/hop.png
convert -gravity northwest -pointsize 30 -fill black -draw "text 20,320 \"${VoeuName}\"" ~/.zen/tmp/hop.png ~/.zen/tmp/pseudo.png
convert -gravity northwest -pointsize 30 -fill black -draw "text 320,300 \"*****\"" ~/.zen/tmp/pseudo.png ~/.zen/tmp/salt.png
convert -gravity northwest -pointsize 33 -fill black -draw "text 320,350 \"${VoeuName}\"" ~/.zen/tmp/salt.png ~/.zen/tmp/player.png

#################################
# SECOND TYPE ~/.zen/tmp/voeu.png
convert $HOME/.zen/game/world/${VoeuName}/${WISHG1PUB}/QR.G1WISH.png -resize 300 ~/.zen/tmp/G1WISH.png
convert ${MY_PATH}/../images/logojeu.png  -resize 260 ~/.zen/tmp/MIZLOGO.png

composite -compose Over -gravity NorthWest -geometry +0+0 ~/.zen/tmp/G1WISH.png ${MY_PATH}/../images/Brother_600x400.png ~/.zen/tmp/astroport.png
composite -compose Over -gravity NorthWest -geometry +300+0 ~/.zen/tmp/QRWISHLINK.png ~/.zen/tmp/astroport.png ~/.zen/tmp/one.png
composite -compose Over -gravity NorthWest -geometry +320+280 ~/.zen/tmp/MIZLOGO.png ~/.zen/tmp/one.png ~/.zen/tmp/two.png

convert -gravity northwest -pointsize 28 -fill black -draw "text 32,350 \"Ğ1 VOEU\"" ~/.zen/tmp/two.png ~/.zen/tmp/pep.png
convert -gravity northwest -pointsize 50 -fill black -draw "text 30,300 \"${VoeuName}\"" ~/.zen/tmp/pep.png ~/.zen/tmp/voeu.png

# IMAGE DANS IPFS
IVOEUPLAY=$(ipfs add -Hq ~/.zen/tmp/player.png | tail -n 1)
IVOEU=$(ipfs add -Hq ~/.zen/tmp/voeu.png | tail -n 1)

### G1VOEU LIGHTBEAM :: ${PLAYER}_${VoeuName} :: /ipns/${VOEUNS}
echo '[{"title":"$:/plugins/astroport/lightbeams/saver/ipns/lightbeam-name","text":"'${PLAYER}_${VoeuName}'","tags":""}]' > ~/.zen/tmp/${MOATS}/lightbeam-name.json
echo '[{"title":"$:/plugins/astroport/lightbeams/saver/ipns/lightbeam-key-'${VoeuName}'","text":"'${VOEUNS}'","tags":""}]' > ~/.zen/tmp/${MOATS}/lightbeam-key.json
echo '[{"title":"$:/plugins/astroport/lightbeams/saver/g1/lightbeam-key-'${VoeuName}'","text":"'${WISHG1PUB}'","tags":""}]' > ~/.zen/tmp/${MOATS}/lightbeam-g1.json
echo '[{"title":"$:/plugins/astroport/lightbeams/saver/g1/lightbeam-natools-'${VoeuName}'","text":"'${ENCODING}'","tags":""}]' > ~/.zen/tmp/${MOATS}/lightbeam-natools.json

#    TEXT="<a target='_blank' href='"/ipns/${VOEUNS}"'><img src='"/ipfs/${IVOEUPLAY}"'></a><br><br><a target='_blank' href='"/ipns/${VOEUNS}"'>"${VoeuName}"</a>"
#:[tag[G1CopierYoutube]] [tag[pdf]]
# Contains QRCode linked to G1VoeuTW and BUTTON listing G1Voeux
# <img width='600' src='"/ipfs/${IMAGIC}"'><br>
TEXT="<a target='_blank' href='#:[tag[G1"${VoeuName}"]]' ><img src='"/ipfs/${IVOEUPLAY}"'></a><br>\n
<a target='_blank' href='"/ipns/${VOEUNS}"'>TW G1Voeu "${PLAYER}"</a><br><br>\n\n
<\$button class='tc-tiddlylink'>\n
<\$list filter='[tag[G1"${VoeuName}"]]'>\n
<\$action-navigate \$to=<<currentTiddler>> \$scroll=no/>\n
</\$list>\n
ALL G1"${VoeuName}"\n
</\$button>"

# NEW IVEU TIDDLER
echo "## Creation json tiddler : G1${VoeuName} /ipfs/${IVOEU}"
echo '[
{
"created": "'${MOATS}'",
"title": "'${VoeuName}'",
"type": "'text/vnd.tiddlywiki'",
"astronautens": "'/ipns/${ASTRONAUTENS}'",
"wishns": "'/ipns/${VOEUNS}'",
"qrcode": "'/ipfs/${IVOEUPLAY}'",
"decode": "'/ipfs/${IVOEU}'",
"wish": "'${WISHG1PUB}'",
"g1pub": "'${G1PUB}'",
"text": "'${TEXT}'",
"tags": "'G1Voeu G1${VoeuName} ${PLAYER}'",
"asksalt": "'${HPass}'",
"junesec" : "'${ENCODING}'"
}
]
' > ~/.zen/game/world/${VoeuName}/${WISHG1PUB}/${VoeuName}.voeu.json



rm -f ~/.zen/tmp/newindex.html

echo "Nouveau Voeu ${VoeuName} dans MOA $PSEUDO : http://127.0.0.1:8080/ipns/$ASTRONAUTENS"
tiddlywiki  --load $INDEX \
                    --deletetiddlers '[tag[voeu]]' \
                    --import ~/.zen/tmp/${MOATS}/lightbeam-name.json "application/json" \
                    --import ~/.zen/tmp/${MOATS}/lightbeam-key.json "application/json" \
                    --import ~/.zen/tmp/${MOATS}/lightbeam-g1.json "application/json" \
                    --import ~/.zen/tmp/${MOATS}/lightbeam-natools.json "application/json" \
                    --import ~/.zen/game/world/${VoeuName}/${WISHG1PUB}/${VoeuName}.voeu.json "application/json" \
                    --output ~/.zen/tmp --render "$:/core/save/all" "newindex.html" "text/plain"

echo "PLAYER TW Update..."
if [[ -s ~/.zen/tmp/newindex.html ]]; then
    echo "___ Mise à jour $INDEX"
    cp -f ~/.zen/tmp/newindex.html $INDEX
else
    echo "ERROR INTO ~/.zen/game/world/${VoeuName}/${WISHG1PUB}/${VoeuName}.voeu.json"
fi

# PRINTING
LP=$(ls /dev/usb/lp* | head -n1)
if [[ ! $LP ]]; then
    echo "NO PRINTER FOUND - Plug a Brother QL700 or Add your printer"
else
    echo "IMPRESSION VOEU"
    brother_ql_create --model QL-700 --label-size 62 ~/.zen/game/world/${VoeuName}/${WISHG1PUB}/result.png > ~/.zen/tmp/toprint.bin 2>/dev/null
    sudo brother_ql_print ~/.zen/tmp/toprint.bin $LP
    brother_ql_create --model QL-700 --label-size 62 ~/.zen/tmp/player.png > ~/.zen/tmp/toprint.bin 2>/dev/null
    sudo brother_ql_print ~/.zen/tmp/toprint.bin $LP
    brother_ql_create --model QL-700 --label-size 62 ~/.zen/tmp/voeu.png > ~/.zen/tmp/toprint.bin 2>/dev/null
    sudo brother_ql_print ~/.zen/tmp/toprint.bin $LP
fi

# COPY QR CODE TO PLAYER ZONE
cp ~/.zen/tmp/player.png ~/.zen/tmp/voeu.png ~/.zen/game/players/${PLAYER}/voeux/${VoeuName}/${WISHG1PUB}/
echo "${SECRET1}" > ~/.zen/game/players/${PLAYER}/voeux/${VoeuName}/${WISHG1PUB}/.salt
echo "${VoeuName}" > ~/.zen/game/players/${PLAYER}/voeux/${VoeuName}/${WISHG1PUB}/.title

echo "$LIBRA/ipns/${VOEUNS}" > ~/.zen/game/players/${PLAYER}/voeux/${VoeuName}/${WISHG1PUB}/.link
cp ~/.zen/game/players/${PLAYER}/voeux/${VoeuName}/${WISHG1PUB}/.link ~/.zen/game/world/${VoeuName}/${WISHG1PUB}/
cp ~/.zen/game/world/${VoeuName}/${WISHG1PUB}/*.png ~/.zen/game/players/${PLAYER}/voeux/${VoeuName}/${WISHG1PUB}/

# PUBLISHING
echo "ipfs name publish --key=${WISHG1PUB}"
banner="## ${PLAYER} G1WISH READY :: G1${VoeuName}
<img src=/ipfs/$IMAGIC>
G1Voeu Astronaute (TW) : $LIBRA/ipns/$ASTRONAUTENS
${VoeuName} FLUX Ŋ1
G1${VoeuName} : $LIBRA/ipns/${VOEUNS}
WISH G1PUB : ${WISHG1PUB}"

IPUSH=$(echo "$banner" | ipfs add -q | tail -n 1)
ipfs name publish --key=${WISHG1PUB} /ipfs/$IPUSH 2>/dev/null

echo $IPUSH > ~/.zen/game/players/${PLAYER}/voeux/${VoeuName}/${WISHG1PUB}/.chain.${MOATS}

echo $banner > ~/.zen/game/players/${PLAYER}/voeux/${VoeuName}/${WISHG1PUB}/banner
cat ~/.zen/game/players/${PLAYER}/voeux/${VoeuName}/${WISHG1PUB}/banner

#~ echo "## TO RECEIVE G1RONDS Creating Cesium+ Profil #### timeout long ... patience ...."
#~ ${MY_PATH}/../tools/jaklis/jaklis.py -k ~/.zen/game/players/${PLAYER}/voeux/${VoeuName}/${WISHG1PUB}/wish.dunikey set --name "G1Voeu ${VoeuName}" --avatar "$HOME/.zen/game/world/${VoeuName}/${WISHG1PUB}/result_qrcode.png" --site "$LIBRA/ipns/${VOEUNS}" #CESIUM+
#~ [[ ! $? == 0 ]] && echo "G1VOEU CESIUM WALLET PROFILE CREATION FAILED !!!!"

echo "************************************************************"
#~ echo "COULD LIMIT ON JUNE pour le Voeu ${VoeuName}"
#~ echo ${MY_PATH}/../tools/jaklis/jaklis.py -k ~/.zen/game/players/${PLAYER}/secret.dunikey pay -a 1 -p ${WISHG1PUB} -c \'"${VOEUNS} G1Voeu ${VoeuName}"\' -m
#~ echo "************************************************************"
#~ echo "************************************************************"

#~ ${MY_PATH}/../tools/jaklis/jaklis.py -k ~/.zen/game/players/${PLAYER}/secret.dunikey pay -a 1 -p ${WISHG1PUB} -c "$VOEUXNS G1Voeu ${VoeuName}" -m
#~ [[ ! $? == 0 ]] \
#~ && echo "SOOOOOOOOOOOORRRRRRRY GUY. YOU CANNOT PAY A G1 A NEW WISH - THIS IS FREE TO CHANGE -"
#~ && rm -Rf ~/.zen/game/players/${PLAYER}/voeux/${VoeuName}/${WISHG1PUB} \
#~ && rm -Rf ~/.zen/game/world/${VoeuName}/${WISHG1PUB}/ \
#~ && ipfs key rm ${WISHG1PUB} \
#~ && tiddlywiki  --load ${INDEX} \
                          #~ --deletetiddlers '${VoeuName}' \
                          #~ --output ~/.zen/tmp --render "$:/core/save/all" "newindex.html" "text/plain" \
#~ && cp -f ~/.zen/tmp/newindex.html $INDEX \
#~ && echo "G1${VoeuName} FLUX REMOVED"

echo "************************************************************"

exit 0
