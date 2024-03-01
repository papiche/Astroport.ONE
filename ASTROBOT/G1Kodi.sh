#!/bin/bash
########################################################################
# Version: 0.5
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
# PAD COCODING : https://pad.p2p.legal/s/G1Kodi
# KODI SERVICE : Publish and Merge Friends Kodi Movies into RSS Stream
########################################################################
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

. "${MY_PATH}/../tools/my.sh"

echo "(✜‿‿✜) G1Kodi
Insert G1Kodi Tiddlers from Kodi database from ~/.kodi/userdata/Database/MyVideos116.db
should export movie to RSS (ex : http://ipfs.localhost:8080/ipfs/QmSJYf4uTj3NmqovSFZpBZuUhSS8j9FXKKnAjUMuVE896k)"
echo "$ME RUNNING"

## EXTRACT MOVIES FROM KODI
[[ ! -s ~/.kodi/userdata/Database/MyVideos116.db ]] && echo "KODI MOVIE SQLITE DB MISSING - EXIT -" && exit 1
## CREATE 1ST ONLY TIDDLER INTO TW

########################################################################
########################################################################
INDEX="$1"
[[ ! ${INDEX} ]] && INDEX="$HOME/.zen/game/players/.current/ipfs/moa/index.html"
[[ ! -s ${INDEX} ]] && echo "ERROR - Please provide path to source TW index.html" && exit 1
[[ ! -s ${INDEX} ]] && echo "ERROR - Fichier TW absent. ${INDEX}" && exit 1
ORIGININDEX=${INDEX}

PLAYER="$2"
[[ ! ${PLAYER} ]] && PLAYER="$(cat ~/.zen/game/players/.current/.player 2>/dev/null)"
[[ ! ${PLAYER} ]] && echo "ERROR - Please provide PLAYER" && exit 1

ASTRONAUTENS=$(ipfs key list -l | grep -w ${PLAYER} | cut -d ' ' -f1)
[[ ! ${ASTRONAUTENS} ]] && echo "ERROR - Clef IPNS ${PLAYER} introuvable!"  && exit 1

G1PUB=$(cat ~/.zen/game/players/${PLAYER}/.g1pub)
[[ ! $G1PUB ]] && echo "ERROR - G1PUB ${PLAYER} VIDE"  && exit 1

# Extract tag=tube from TW
MOATS="$3"
[[ ! ${MOATS} ]] && MOATS=$(date -u +"%Y%m%d%H%M%S%4N")

echo "${PLAYER} ${INDEX} ${ASTRONAUTENS} ${G1PUB} "
#~ ###################################################################
#~ ## CREATE APP NODE PLAYER PUBLICATION DIRECTORY
#~ ###################################################################
mkdir -p $HOME/.zen/tmp/${MOATS} && echo $HOME/.zen/tmp/${MOATS}
mkdir -p $HOME/.zen/game/players/${PLAYER}/G1Kodi/

echo "EXPORT Kodi Wish for ${PLAYER}"
rm -f ~/.zen/game/players/${PLAYER}/G1Kodi/Kodi.json
tiddlywiki  --load ${INDEX} \
                    --output ~/.zen/game/players/${PLAYER}/G1Kodi \
                    --render '.' 'Kodi.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[tag[G1Voeu]tag[G1Kodi]]'

[[ $(cat ~/.zen/game/players/${PLAYER}/G1Kodi/Kodi.json ) == "[]" ]] \
    && echo "AUCUN VOEU G1KODI - EXIT -" \
    && rm -Rf $HOME/.zen/game/players/${PLAYER}/G1Kodi \
    && exit 0

WISH=$(cat ~/.zen/game/players/${PLAYER}/G1Kodi/Kodi.json | jq -r '.[].wish')
WISHNS=$(cat ~/.zen/game/players/${PLAYER}/G1Kodi/Kodi.json | jq -r '.[].wishns')
echo "G1KODI: $WISH ${myIPFS}$WISHNS"

## Export already in TW movies
rm -f ~/.zen/game/players/${PLAYER}/G1Kodi/TWmovies.json

tiddlywiki  --load ${INDEX} \
                --output ~/.zen/game/players/${PLAYER}/G1Kodi \
                --render '.' 'TWmovies.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[tag[G1Kodi]!tag[G1Voeu]]'

[[ $(cat ~/.zen/game/players/${PLAYER}/G1Kodi/TWmovies.json) == "[]" ]] && echo "AUCUN FILM G1KODI"

#~ ## TW G1Kodi deletetiddlers CODE
#~ tiddlywiki  --load ${INDEX} \
                    #~ --deletetiddlers '[tag[G1Kodi]!Kodi]' \
                    #~ --output ~/.zen/tmp/${MOATS} --render "$:/core/save/all" "cleanindex.html" "text/plain"
#~ [[ -s ~/.zen/tmp/${MOATS}/cleanindex.html ]] && cp -f ~/.zen/tmp/${MOATS}/cleanindex.html ~/.zen/tmp/${MOATS}/index.html


echo "=========== ( ◕‿◕) EXTRACT KODI MyVideos DB (◕‿◕ ) =============="

## EXTRACT MOVIE FILES LIST TO CSV
echo "\"titre\",\"desc\",\"sub\",\"source\",\"cat\",\"extrait\",\"prem\"" > ~/.zen/tmp/${MOATS}/${PLAYER}.movie.csv
sqlite3 -csv ~/.kodi/userdata/Database/MyVideos116.db 'select c00, c01, c03, c22, c14, c19, premiered from movie' >> ~/.zen/tmp/${MOATS}/${PLAYER}.movie.csv
[[ ! -s ~/.zen/tmp/${MOATS}/${PLAYER}.movie.csv ]] && echo "EMPTY KODI MOVIE DATABASE - EXIT -" && exit 0
#################################

### CONVERT TO JSON
## Use "miller" to convert csv into json
mlr --c2j --jlistwrap cat ~/.zen/tmp/${MOATS}/${PLAYER}.movie.csv > ~/.zen/tmp/${MOATS}/${PLAYER}.movie.json

## SHUFFLE TITRE LIST
cat ~/.zen/tmp/${MOATS}/${PLAYER}.movie.json | jq -r .[].titre | shuf > ~/.zen/tmp/${MOATS}/${PLAYER}.movie.id

boucle=0

while read TITRE; do

    DESC=$(cat ~/.zen/tmp/${MOATS}/${PLAYER}.movie.json  | jq --arg v "${TITRE}" -r '.[] | select(.titre==$v) | .desc')
    SUB=$(cat ~/.zen/tmp/${MOATS}/${PLAYER}.movie.json  | jq --arg v "${TITRE}" -r '.[] | select(.titre==$v) | .sub')
    SOURCE=$(cat ~/.zen/tmp/${MOATS}/${PLAYER}.movie.json  | jq --arg v "${TITRE}" -r '.[] | select(.titre==$v) |  .source')
    IPFSONE=$(cat ~/.zen/tmp/${MOATS}/${PLAYER}.movie.json  | jq --arg v "${TITRE}" -r '.[] | select(.titre==$v) |  .ipfs_one')
    CAT=$(cat ~/.zen/tmp/${MOATS}/${PLAYER}.movie.json  | jq --arg v "${TITRE}" -r '.[] | select(.titre==$v) |  .cat' | tail -n 1)
    YID=$(cat ~/.zen/tmp/${MOATS}/${PLAYER}.movie.json  | jq --arg v "${TITRE}" -r '.[] | select(.titre==$v) |  .extrait' | rev | cut -d '=' -f 1 | rev)

    PREM=$(cat ~/.zen/tmp/${MOATS}/${PLAYER}.movie.json  | jq --arg v "${TITRE}" -r '.[] | select(.titre==$v) |  .prem')
    MIME=$(file --mime-type -b "$SOURCE" )

    YEAR=$(echo "${PREM}" | cut -f1 -d '-' )
    TITLE=$(echo "${TITRE}" | detox --inline ) ## TITLE SANITY
    TAGS="${YEAR} G1Kodi ${TITLE} ${PLAYER} $(echo "${CAT}" | detox --inline | sed 's~_~\ ~g')"

    echo "${boucle} > ${TITLE}"
    echo "($MIME)" "$SOURCE"

    ## ADD MOVIE TO IPFS
    #~ <item>
    #~ <title>Delicatessen</title>
    #~ <description>La vie des étranges habitants d'un immeuble de banlieue qui se dresse dans un immense terrain vague et qui tous vont se fournir chez le boucher-charcutier, à l'enseigne « Delicatessen ».</description>
    #~ <link>http://ipfs.localhost:8080/ipfs/QmfVuhDo4kEk5eh5EULfZGxiWqrrCcHBehojgPF6kiq8r3/Delicatessen.mp4</link>
    #~ <pubDate>Sun, 6 Sep 2022 16:20:00 +0000</pubDate>
    #~ </item>

    if [[ ! -s ~/.zen/game/players/${PLAYER}/G1Kodi/${TITLE}.dragdrop.json ]]; then
    echo "CHECKING Kodi_${TITLE} IN TW"
    tiddlywiki  --load ${ORIGININDEX} \
                --output ~/.zen/game/players/${PLAYER}/G1Kodi \
                --render '.' "${TITLE}.dragdrop.json" 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' "'"Kodi_${TITLE}"'"
    fi ## CHECK PLAYER G1KODI CACHE. QUICKER.

    if [[ $(cat ~/.zen/game/players/${PLAYER}/G1Kodi/${TITLE}.dragdrop.json) == "[]" ]]; then

         if [[ $MIME == "video/mp4"  ]]; then
            echo "$MIME. GOOD. RECORDING TO TW"

            # MAKE PAYMENT QRCODE
            # sha256 Kodi_TITLE + G1PUB encrypt = comment
            THASH=$(echo "Kodi_${TITLE}" | sha256sum | cut -d ' ' -f 1) # && echo ${THASH} > ~/.zen/tmp/${MOATS}/thash
            # WANA DO MORE SECURE ?
            ## ENCRYPT THASH with G1PUB (so you are sure it is a link from your TW).
            #~ ~/.zen/Astroport.ONE/tools/natools.py encrypt -p ${G1PUB} -i ~/.zen/tmp/${MOATS}/thash -o ~/.zen/tmp/${MOATS}/thash.enc
            #~ THASHSEC=$(cat ~/.zen/tmp/${MOATS}/thash.enc | base16)
            #~ Then update THASH with THASHSEC next
            ## CREATE june:// QRCODE put it in IPFS
            PAYCOM="june://${G1PUB}?comment=N1Kodi:${THASH}&" ## comment=N1Kodi:TiddlerTiltleHash
            echo "${PAYCOM}"
            amzqr "${PAYCOM}" -l H -c -p ${MY_PATH}/../images/TV.png -n VOD_${TITLE}.png -d ~/.zen/tmp/${MOATS}/
            convert -gravity northwest -pointsize 20 -fill black -draw "text 30,3 \"${TITRE} (${YEAR})\"" ~/.zen/tmp/${MOATS}/VOD_${TITLE}.png ~/.zen/tmp/${MOATS}/VOD.png

            PV=$(ipfs add -q ~/.zen/tmp/${MOATS}/VOD.png)
            echo "VOD QR = ${myIPFS}/ipfs/${PV}"
            ## ADD TO IPFS
            echo "ADD ${SOURCE} TO IPFS"

            IPFSMOVIE=$(ipfs add -q "$SOURCE")
            echo "/ipfs/${IPFSMOVIE}" > ~/.zen/tmp/${MOATS}/source

            ~/.zen/Astroport.ONE/tools/natools.py encrypt -p ${G1PUB} -i ~/.zen/tmp/${MOATS}/source -o ~/.zen/tmp/${MOATS}/source.enc
            ENCODING=$(cat ~/.zen/tmp/${MOATS}/source.enc | base16)
            echo "MOVIE ADDED /ipfs/${IPFSMOVIE} :NATOOLS16: ${ENCODING}"

            # CREATE TEXT AREA
            TEXT="<h1>{{!!titre}} ({{!!year}})</h1><h2>{{!!sub}}</h2>
            {{!!desc}}<br>
            <a target='youtube' href='https://youtu.be/"${YID}"'>Bande Annonce</a>
            <br>
            <h3>Voir ce Film:</h3>
            <h4>Installez Cesium+</h4>
            <table><tr>
            <td>
            <img width='240' src='/ipfs/QmXExw6Sh4o4rSjBQjU9PGU7BCGwb1jybrKEeaZGUNRCRE'>
            </td><td>
            <img width='240' src='/ipfs/QmP3qwEnVX9zSsyKAwuH6nhDPfrRoMbAfszrtdkLGgo7LQ'>
            </td>
            </tr>
            <tr>
            <td>
            <h4>Flashez, envoyez un don...</h4>
            <br>ce soir,<br>recevez le lien dans votre messagerie.
            </td><td>
            <img width='300' src='/ipfs/"${PV}"'>
            </td>
            </tr>
            </table>
            "

            ## MAKING TIDDLER
              echo "## Creation json tiddler ~/.zen/game/players/${PLAYER}/G1Kodi/${TITLE}.dragdrop.json"
              echo '[
              {
                "created": "'${MOATS}'",
                "title": "'Kodi_${TITLE}'",
                "text": "'${TEXT}'",
                "thash": "'${THASH}'",
                "year": "'${YEAR}'",
                "mime": "'${MIME}'",
                "prem": "'${PREM}'",
                "sub": "'${SUB}'",
                "desc": "'${DESC}'",
                "yid": "'${YID}'",
                "cat": "'${CAT}'",
                "g1pub": "'${G1PUB}'",
                "source": "'${SOURCE}'",
                "ipfs_one": "''",
                "titre": "'${TITRE}'",
                "modified": "'${MOATS}'",
                "issuer": "'${PLAYER}'",
                "tags": "'${TAGS}'"
               }
            ]
            ' > ~/.zen/game/players/${PLAYER}/G1Kodi/${TITLE}.dragdrop.json

            ##  ADD ipfs_one to JSON file (Just to show jq in action)
            cat ~/.zen/game/players/${PLAYER}/G1Kodi/${TITLE}.dragdrop.json | jq --arg v "${ENCODING}" '.[].ipfs_one = $v' \
                    > ~/.zen/game/players/${PLAYER}/G1Kodi/ipfs_one.json

            [[ -s ~/.zen/game/players/${PLAYER}/G1Kodi/ipfs_one.json ]] \
                && cp -f ~/.zen/game/players/${PLAYER}/G1Kodi/ipfs_one.json ~/.zen/game/players/${PLAYER}/G1Kodi/${TITLE}.dragdrop.json \
                && rm ~/.zen/game/players/${PLAYER}/G1Kodi/ipfs_one.json

            ## TO ALLOW DECODING FOR MY FRIENDS
            ## jq FORMULA TO ADD ipfs_FG1PUB = ACODING
            #~ cat ~/.zen/tmp/${MOATS}/atiddler.json | jq '.[] |= .+ {"_IPUB_":"_ICOD_"}' \
                        #~ > ~/.zen/tmp/${MOATS}/atiddler.json.tmp \
                        #~ && sed -i "s~_IPUB_~ipfs_${AG1PUB}~g" ~/.zen/tmp/${MOATS}/atiddler.json.tmp \
                        #~ && sed -i "s~_ICOD_~${ACODING}~g" ~/.zen/tmp/${MOATS}/atiddler.json.tmp \
                        #~ && mv ~/.zen/tmp/${MOATS}/atiddler.json.tmp ~/.zen/tmp/${MOATS}/atiddler.json

            echo "ipfs_one : ${ENCODING}"

            ## ADD TO TW
            echo "ADD G1KODI IN TW ${PLAYER} : $myIPFS/ipns/$ASTRONAUTENS"
            rm -f ~/.zen/tmp/newindex.html
            tiddlywiki --load ${INDEX} \
                            --import ~/.zen/game/players/${PLAYER}/G1Kodi/${TITLE}.dragdrop.json "application/json" \
                            --output ~/.zen/tmp --render "$:/core/save/all" "newindex.html" "text/plain"

            ## UPDATE ${INDEX}
            if [[ -s ~/.zen/tmp/newindex.html ]]; then

                    cp -f ~/.zen/tmp/newindex.html ~/.zen/tmp/${MOATS}/index.html

                    INDEX="$HOME/.zen/tmp/${MOATS}/index.html"
                    echo "NEWINDEX : ${INDEX}"

                    boucle=$((boucle+1)) ## COUNT HOW MANY MOVIES GOING TO IPFS

            else

                    echo "CANNOT UPDATE TW - FATAL ERROR -"
                    exit 1

            fi

            echo "MOVIE IN TW ($YID)"
            echo "~~~~~~~~"

        else

            echo "${TITLE} MIME TYPE NOT COMPATIBLE.
            MUST BE CONVERTED TO MP4"

        fi

    else

        echo "ALREADY IN TW : Kodi_${TITLE}
        https://youtu.be/${YID}"

    fi

    ## BOUCLE BREAK - choose how many movies are added per day ? - G1STATION PARAM -
    [[ ${boucle} == 1 ]] && echo "IPFS ADD ${boucle} TODAY - BREAK -" && break

done < ~/.zen/tmp/${MOATS}/${PLAYER}.movie.id

## VERIFY, COULD BE DONE IN PLAYER REFRESH
if [[ $(diff ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html ${INDEX}) ]]; then

    cp ${INDEX} ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html
    echo "CHANGED TW"

fi

echo "=========== ( ◕‿◕)  (◕‿◕ ) =============="

#~ rm -Rf $HOME/.zen/tmp/${MOATS}

exit 0

## ./userdata/mediasources.xml
## ./userdata/sources.xml
