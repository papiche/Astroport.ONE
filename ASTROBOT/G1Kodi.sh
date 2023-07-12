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

echo "(✜‿‿✜) G1Kodi : Get Kodi database from ~/.kodi/userdata/Database/MyVideos116.db
export movie to RSS (ex : http://ipfs.localhost:8080/ipfs/QmSJYf4uTj3NmqovSFZpBZuUhSS8j9FXKKnAjUMuVE896k)"
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
                    --render '.' 'Kodi.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'Kodi'

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

echo "=========== ( ◕‿◕) (◕‿◕ ) =============="

## EXTRACT MOVIE FILES LIST TO CSV
echo "\"titre\",\"desc\",\"sub\",\"source\",\"cat\",\"extrait\",\"prem\"" > ~/.zen/tmp/${MOATS}/${PLAYER}.movie.csv
sqlite3 -csv ~/.kodi/userdata/Database/MyVideos116.db 'select c00, c01, c03, c22, c14, c19, premiered from movie' >> ~/.zen/tmp/${MOATS}/${PLAYER}.movie.csv
[[ ! -s ~/.zen/tmp/${MOATS}/${PLAYER}.movie.csv ]] && echo "EMPTY KODI MOVIE DATABASE - EXIT -" && exit 0
#################################

### CONVERT TO JSON
## Use "miller" to convert csv into json
mlr --c2j --jlistwrap cat ~/.zen/tmp/${MOATS}/${PLAYER}.movie.csv > ~/.zen/tmp/${MOATS}/${PLAYER}.movie.json

## INDEX TITRE LIST
cat ~/.zen/tmp/${MOATS}/${PLAYER}.movie.json | jq -r .[].titre > ~/.zen/tmp/${MOATS}/${PLAYER}.movie.id

boucle=0

while read TITRE; do

    DESC=$(cat ~/.zen/tmp/${MOATS}/${PLAYER}.movie.json  | jq --arg v "${TITRE}" -r '.[] | select(.titre==$v) | .desc')
    SUB=$(cat ~/.zen/tmp/${MOATS}/${PLAYER}.movie.json  | jq --arg v "${TITRE}" -r '.[] | select(.titre==$v) | .sub')
    SOURCE=$(cat ~/.zen/tmp/${MOATS}/${PLAYER}.movie.json  | jq --arg v "${TITRE}" -r '.[] | select(.titre==$v) |  .source')
    CAT=$(cat ~/.zen/tmp/${MOATS}/${PLAYER}.movie.json  | jq --arg v "${TITRE}" -r '.[] | select(.titre==$v) |  .cat' | tail -n 1)
    YID=$(cat ~/.zen/tmp/${MOATS}/${PLAYER}.movie.json  | jq --arg v "${TITRE}" -r '.[] | select(.titre==$v) |  .extrait' | rev | cut -d '=' -f 1 | rev)

    PREM=$(cat ~/.zen/tmp/${MOATS}/${PLAYER}.movie.json  | jq --arg v "${TITRE}" -r '.[] | select(.titre==$v) |  .prem')
    MIME=$(file --mime-type -b "$SOURCE" )

    YEAR=$(echo "${PREM}" | cut -f1 -d '-' )
    TITLE=$(echo "${TITRE}" | detox --inline ) ## TITLE SANITY
    TAGS="${YEAR} G1Kodi ${TITLE} ${PLAYER} $(echo "${CAT}" | detox --inline | sed 's~_~\ ~g')"

    echo "${YID} > ${TITLE}"
    echo "($MIME)" "$SOURCE"

    ## ADD MOVIE TO IPFS
    #~ <item>
    #~ <title>Delicatessen</title>
    #~ <description>La vie des étranges habitants d'un immeuble de banlieue qui se dresse dans un immense terrain vague et qui tous vont se fournir chez le boucher-charcutier, à l'enseigne « Delicatessen ».</description>
    #~ <link>http://ipfs.localhost:8080/ipfs/QmfVuhDo4kEk5eh5EULfZGxiWqrrCcHBehojgPF6kiq8r3/Delicatessen.mp4</link>
    #~ <pubDate>Sun, 6 Sep 2022 16:20:00 +0000</pubDate>
    #~ </item>

        ## CHECK IN TW
        if [[ ! -s ~/.zen/game/players/${PLAYER}/G1Kodi/${TITLE}.dragdrop.json ]]; then
        tiddlywiki  --load ${ORIGININDEX} \
                    --output ~/.zen/game/players/${PLAYER}/G1Kodi \
                    --render '.' "${TITLE}.dragdrop.json" 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' "'"Kodi_${TITLE}"'"
        fi
        ## CHECK PLAYER G1KODI CACHE. QUICKER.

    if [[ $(cat ~/.zen/game/players/${PLAYER}/G1Kodi/${TITLE}.dragdrop.json) == "[]" ]]; then
        echo "NOT IN TW either IN CACHE"


         if [[ $MIME == "video/mp4"  ]]; then
            echo "$MIME. GOOD. RECORDING TO TW"


              echo "## Creation json tiddler"
              echo '[
              {
                "text": "'${DESC}'",
                "title": "'Kodi_${TITLE}'",
                "created": "'${MOATS}'",
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
                "tags": "'${TAGS}'"
               }
            ]
            ' > ~/.zen/game/players/${PLAYER}/G1Kodi/${TITLE}.dragdrop.json


            echo "ADD G1KODI IN TW ${PLAYER} : $myIPFS/ipns/$ASTRONAUTENS"
            rm -f ~/.zen/tmp/newindex.html
            tiddlywiki --load ${INDEX} \
                            --import ~/.zen/game/players/${PLAYER}/G1Kodi/${TITLE}.dragdrop.json "application/json" \
                            --output ~/.zen/tmp --render "$:/core/save/all" "newindex.html" "text/plain"

            if [[ -s ~/.zen/tmp/newindex.html ]]; then

                    cp -f ~/.zen/tmp/newindex.html ~/.zen/tmp/${MOATS}/index.html

                    INDEX="$HOME/.zen/tmp/${MOATS}/index.html"
                    echo "NEWINDEX : ${INDEX}"

            else

                    echo "CANNOT UPDATE TW - FATAL ERROR -"
                    exit 1

            fi

        else

            echo "MOVIE NO COMPATIBLE. PLEASE CONVERT TO MP4"

        fi

    else

            echo "## TIDDLER WITH OR WITHOUT ipfs_one"
            ## MANAGING TIDDLER UPDATE
            IPFSONE=$(cat ~/.zen/game/players/${PLAYER}/G1Kodi/${TITLE}.dragdrop.json | jq -r .[].ipfs_one)
            SOURCE=$(cat ~/.zen/game/players/${PLAYER}/G1Kodi/${TITLE}.dragdrop.json | jq -r .[].source)

            if [[ ${IPFSONE} == "" ]]; then

                ## RUN NO IPFS_ONE STEP
                echo "ADD ${SOURCE} TO IPFS"
                [[ ${boucle} == 1 ]] && echo "IPFS ADD DONE ONCE TODAY" && continue

                IPFSMOVIE=$(ipfs add -q "$SOURCE")
                echo "/ipfs/${IPFSMOVIE}" > ~/.zen/tmp/${MOATS}/source

                ~/.zen/Astroport.ONE/tools/natools.py encrypt -p ${G1PUB} -i ~/.zen/tmp/${MOATS}/source -o ~/.zen/tmp/${MOATS}/source.enc
                ENCODING=$(cat ~/.zen/tmp/${MOATS}/source.enc | base16)
                echo "MOVIE ADDED /ipfs/${IPFSMOVIE} :NATOOLS16: ${ENCODING}"

                ##  UPDATE ipfs_one in JSON
                cat ~/.zen/game/players/${PLAYER}/G1Kodi/${TITLE}.dragdrop.json | jq  --arg v "${ENCODING}" '.[].ipfs_one = $v' \
                        > ~/.zen/game/players/${PLAYER}/G1Kodi/ipfs_one.json

                ## INSERT NEW TIDDLER
                tiddlywiki --load ${INDEX} \
                            --import ~/.zen/game/players/${PLAYER}/G1Kodi/ipfs_one.json "application/json" \
                            --output ~/.zen/tmp --render "$:/core/save/all" "newindex.html" "text/plain"

                [[ -s ~/.zen/tmp/newindex.html ]] \
                    && cp -f ~/.zen/tmp/newindex.html ~/.zen/tmp/${MOATS}/index.html

                INDEX="$HOME/.zen/tmp/${MOATS}/index.html"
                boucle=$((boucle+1)) ## COUNT HOW MANY MOVIES GOING TO IPFS

            else

                ## ipfs_one STEP OK
                echo "ipfs_one NATOOLS DECRYPTING"
                echo "${IPFSONE}" | base16 -d > ~/.zen/tmp/${MOATS}/source.one.enc
                 ~/.zen/Astroport.ONE/tools/natools.py decrypt -f pubsec \
                        -k ~/.zen/game/players/${PLAYER}/secret.dunikey \
                        -i ~/.zen/tmp/${MOATS}/source.one.enc -o $HOME/.zen/tmp/${MOATS}/source.one

                echo "IPFS SOURCE $(cat $HOME/.zen/tmp/${MOATS}/source.one)"

                ## FIND FRIENDS and ADD FIELDS ipfs_AG1PUB
                find ~/.zen/game/players/${PLAYER}/FRIENDS -mindepth 1 -maxdepth 1 -type d | rev | cut -f 1 -d '/' | rev > ~/.zen/tmp/${MOATS}/twfriends
                cp -f ${HOME}/.zen/game/players/${PLAYER}/G1Kodi/${TITLE}.dragdrop.json ~/.zen/tmp/${MOATS}/atiddler.json

                while read AG1PUB; do

                    ## CREATE "ipfs_AG1PUB" : "ACODING"
                    rm -f ~/.zen/tmp/${MOATS}/source.aenc
                    ~/.zen/Astroport.ONE/tools/natools.py encrypt -p ${AG1PUB} -i ~/.zen/tmp/${MOATS}/source.one -o ~/.zen/tmp/${MOATS}/source.aenc
                    ACODING=$(cat ~/.zen/tmp/${MOATS}/source.aenc | base16)

                    cat ~/.zen/tmp/${MOATS}/atiddler.json | jq '.[] |= .+ {"_IPUB_":"_ICOD_"}' \
                        > ~/.zen/tmp/${MOATS}/atiddler.json.tmp \
                        && sed -i "s~_IPUB_~ipfs_${AG1PUB}~g" ~/.zen/tmp/${MOATS}/atiddler.json.tmp \
                        && sed -i "s~_ICOD_~${ACODING}~g" ~/.zen/tmp/${MOATS}/atiddler.json.tmp \
                        && mv ~/.zen/tmp/${MOATS}/atiddler.json.tmp ~/.zen/tmp/${MOATS}/atiddler.json

                done < ~/.zen/tmp/${MOATS}/twfriends

                ## INSERT NEW TIDDLER
                tiddlywiki --load ${INDEX} \
                            --import ~/.zen/tmp/${MOATS}/atiddler.json "application/json" \
                            --output ~/.zen/tmp --render "$:/core/save/all" "newindex.html" "text/plain"

                [[ -s ~/.zen/tmp/newindex.html ]] \
                            && cp -f ~/.zen/tmp/newindex.html ~/.zen/tmp/${MOATS}/index.html
                INDEX="$HOME/.zen/tmp/${MOATS}/index.html"

            fi

            YID=$(cat ~/.zen/tmp/${MOATS}/${PLAYER}.movie.json  | jq --arg v "${TITRE}" -r '.[] | select(.titre==$v) |  .extrait' | rev | cut -d '=' -f 1 | rev)

            echo "MOVIE IN TW ($YID)"

    fi

    echo "~~~~~~~~"

done < ~/.zen/tmp/${MOATS}/${PLAYER}.movie.id

if [[ $(diff ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html ${INDEX}) ]]; then

    ################################################
    ## UPDATE TW CHAIN WITH PREVIOUSLY RECORDED CHAIN
    tiddlywiki --load ${INDEX} \
        --output ~/.zen/tmp/${MOATS} \
        --render '.' 'Astroport.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'Astroport'
    ASTROPORT=$(cat ~/.zen/tmp/${MOATS}/Astroport.json | jq -r .[].astroport)
    [[ $ASTROPORT == "" ]] && echo "INCOMPATIBLE TW - ADD Astroport TIDDLER - CORRECTION NEEDED -" && exit 1

    CURCHAIN=$(cat ~/.zen/tmp/${MOATS}/Astroport.json | jq -r .[].chain | rev | cut -f 1 -d '/' | rev) # Remove "/ipfs/" part
    [[ $CURCHAIN == "" ||  $CURCHAIN == "null" ]] &&  CURCHAIN="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" # AVOID EMPTY
    echo "CURCHAIN=$CURCHAIN"
    [[ -s ~/.zen/game/players/$PLAYER/ipfs/moa/.chain ]] \
    && ZCHAIN=$(cat ~/.zen/game/players/$PLAYER/ipfs/moa/.chain) \
    && echo "# CHAIN : $CURCHAIN -> $ZCHAIN" \
    && sed -i "s~$CURCHAIN~$ZCHAIN~g" ${INDEX}
    ################################################

    espeak "I P N S Publishing. Please wait..."
    cp ${INDEX} ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html

    cp   ~/.zen/game/players/${PLAYER}/ipfs/moa/.chain \
                                ~/.zen/game/players/${PLAYER}/ipfs/moa/.chain.$(cat ~/.zen/game/players/${PLAYER}/ipfs/moa/.moats)

    TW=$(ipfs add -Hq ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html | tail -n 1)
    ipfs name publish --key=${PLAYER} /ipfs/$TW

    echo $TW > ~/.zen/game/players/${PLAYER}/ipfs/moa/.chain
    echo ${MOATS} > ~/.zen/game/players/${PLAYER}/ipfs/moa/.moats

    echo "================================================"
    echo "${PLAYER} : $myIPFS/ipns/$ASTRONAUTENS"
    echo "================================================"
    echo

    [[ $XDG_SESSION_TYPE == 'x11' ]] && xdg-open "http://ipfs.localhost:8080/ipns/$ASTRONAUTENS"

else

    echo "UNCHANGED TW"

fi

echo "=========== ( ◕‿◕)  (◕‿◕ ) =============="

rm -Rf $HOME/.zen/tmp/${MOATS}

exit 0

## ./userdata/mediasources.xml
## ./userdata/sources.xml
