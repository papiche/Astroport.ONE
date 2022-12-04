#!/bin/bash
# Run After PLAYER.entrance.sh
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
myIP=$(hostname -I | awk '{print $1}' | head -n 1)
isLAN=$(echo $myIP | grep -E "/(^127\.)|(^192\.168\.)|(^10\.)|(^172\.1[6-9]\.)|(^172\.2[0-9]\.)|(^172\.3[0-1]\.)|(^::1$)|(^[fF][cCdD])/")
[[ ! $myIP || $isLAN ]] && myIP="ipfs.localhost"

IPFSNODEID=$(ipfs id -f='<id>\n')

ME="${0##*/}"
######################################################################### CONNECT PLAYER WITH GCHANGE
# Check who is .current PLAYER
PLAYER="$1"

[[ ${PLAYER} == "" ]] && PLAYER=$(cat ~/.zen/game/players/.current/.player 2>/dev/null)
[[ ${PLAYER} == "" ]] && echo "ERROR PLAYER - EXIT" && exit 1
PSEUDO=$(cat ~/.zen/game/players/${PLAYER}/.pseudo 2>/dev/null)
[[ $G1PUB == "" ]] && G1PUB=$(cat ~/.zen/game/players/${PLAYER}/.g1pub 2>/dev/null)
[[ $G1PUB == "" ]] && echo "ERROR G1PUB - EXIT" && exit 1

    PSEUDO=$(cat ~/.zen/game/players/${PLAYER}/.pseudo 2>/dev/null)
    G1PUB=$(cat ~/.zen/game/players/${PLAYER}/.g1pub 2>/dev/null)
    ASTRONS=$(cat ~/.zen/game/players/${PLAYER}/.playerns 2>/dev/null)

    ## REFRESH ASTRONAUTE TW
    ASTRONAUTENS=$(ipfs key list -l | grep ${PLAYER} | cut -d ' ' -f1)
    [[ ! $ASTRONAUTENS ]] && echo "WARNING No ${PLAYER} in keystore -- EXIT" && exit 1
    [[ ! -f ~/.zen/game/players/${PLAYER}/QR.png ]] && echo "NOT MY ${PLAYER} -- EXIT" && exit 1

mkdir -p ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/

## VERIFY IT HAS ALREADY RUN
if [[ ! -s ~/.zen/game/players/${PLAYER}/ipfs/cesium.json ]]; then
    ## GET GCHANGE PROFIL
    $MY_PATH/jaklis/jaklis.py -k ~/.zen/game/players/${PLAYER}/secret.dunikey -n "https://data.gchange.fr" get >  ~/.zen/game/players/${PLAYER}/ipfs/gchange.json

    ## KEEPING ALREADY EXISTING PROFILE DATA
    NAME=$(cat ~/.zen/game/players/${PLAYER}/ipfs/gchange.json | jq -r '.title')
    [[ ! $NAME || $NAME == "null" ]] &&  NAME="Astronaute ${PSEUDO}"

    DESCR=$(cat ~/.zen/game/players/${PLAYER}/ipfs/gchange.json | jq -r '.description')
    [[ ! $DESCR || $DESCR == "null" ]] &&  DESCR="ASTROPORT Ŋ1 https://g1jeu.ml"

    VILLE=$(cat ~/.zen/game/players/${PLAYER}/ipfs/gchange.json | jq -r '.city')
    [[ ! $VILLE || $VILLE == "null" ]] &&  VILLE="Paris, 75012"

    ADRESSE=$(cat ~/.zen/game/players/${PLAYER}/ipfs/gchange.json | jq -r '.address')
    [[ ! $ADRESSE || $ADRESSE == "null" ]] &&  ADRESSE="Elysée"

    # POSITION=$(cat ~/.zen/game/players/${PLAYER}/ipfs/gchange.json | jq -r '.geoPoint')
    SITE=$(cat ~/.zen/game/players/${PLAYER}/ipfs/gchange.json | jq -r '.socials')

    ########################################################################
    echo "${PLAYER} GCHANGE+ PROFILE https://gchange.fr"
    echo "set -n "${NAME}" -d "${DESCR}" -v "${VILLE}" -a "${ADRESSE}""
    ########################################################################
    $MY_PATH/jaklis/jaklis.py -k ~/.zen/game/players/${PLAYER}/secret.dunikey -n "https://data.gchange.fr" set -n "${NAME}" -d "${DESCR}" -v "${VILLE}" -a "${ADRESSE}" -s "https://ipfs.copylaradio.com/ipns/$ASTRONAUTENS" #GCHANGE+
    [[ ! $? == 0 ]] && echo "GCHANGE PROFILE CREATION FAILED"

    ## SET CESIUM WALLET
    ########################################################################
    echo "${PLAYER} CESIUM+ PROFILE https://demo.cesium.app/#/app/wot/lg?q=$G1PUB"
    ########################################################################
    $MY_PATH/jaklis/jaklis.py -k ~/.zen/game/players/${PLAYER}/secret.dunikey -n "https://g1.data.presles.fr" set -n "${NAME}" -d "${DESCR}" -v "${VILLE}" -a "${ADRESSE}" --s "http://ipfs.localhost:8080/ipns/$ASTRONAUTENS" #CESIUM+
    [[ ! $? == 0 ]] && echo "CESIUM PROFILE CREATION FAILED"
    ## GET IT BACK
    $MY_PATH/jaklis/jaklis.py -k ~/.zen/game/players/${PLAYER}/secret.dunikey -n "https://g1.data.presles.fr" get >  ~/.zen/game/players/${PLAYER}/ipfs/cesium.json

fi

########################################################################

echo "########################################################################"
echo "SCANNING ${PLAYER} - $G1PUB - Gchange FRIENDS"
echo "########################################################################"
################## CHECKING WHO GAVE ME STARS
################## BOOTSTRAP LIKES THEM BACK
################## SEND ipfstryme MESSAGES to FRIENDS
rm -f ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/my_star_level
## Getting Gchange  liking_me list
echo "Getting received stars"
################################## JAKLIS PLAYER stars
~/.zen/Astroport.ONE/tools/timeout.sh -t 20 \
~/.zen/Astroport.ONE/tools/jaklis/jaklis.py \
-k ~/.zen/game/players/${PLAYER}/secret.dunikey \
-n "https://data.gchange.fr" stars > ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/received_stars.json

cat ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/received_stars.json | jq -r '.likes[].issuer' | sort | uniq > ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/liking_me
echo "cat ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/received_stars.json | jq -r"

for liking_me in $(cat ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/liking_me | sort | uniq);
do
    [[ "${liking_me}" == "" ]] && continue ## Protect from empty line !!
    echo "........................."
    ASTRONAUTENS=$(~/.zen/Astroport.ONE/tools/g1_to_ipfs.py ${liking_me})
    echo "==========================="
    echo "${liking_me} IS LIKING ME"
    echo "TW ? http://tube.copylaradio.com:8080/ipns/$ASTRONAUTENS "

##### CHECKING IF WE LIKE EACH OTHER Ŋ1 LEVEL
    echo "Receiving Stars : cat ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/${liking_me}.Gstars.json | jq -r"
    ################################## JAKLIS LIKING_ME stars
    ~/.zen/Astroport.ONE/tools/timeout.sh -t 20 \
    ~/.zen/Astroport.ONE/tools/jaklis/jaklis.py \
    -k ~/.zen/game/players/${PLAYER}/secret.dunikey \
    -n "https://data.gchange.fr" \
    stars -p ${liking_me} > ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/${liking_me}.Gstars.json
    ## ZOMBIE PROTECTION
    [[ "$?" == "0" && ! -s ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/${liking_me}.Gstars.json ]] && rm -Rf ~/.zen/game/players/${PLAYER}/FRIENDS/${liking_me} && echo "${liking_me} is a ZOMBIE..." && continue

#### RECUP ANNONCES Gchange
## https://www.gchange.fr/#/app/records/wallet?q=2geH4d2sndR47XWtfDWsfLLDVyNNnRsnUD3b1sk9zYc4&old
## https://www.gchange.fr/#/app/market/records/42LqLa7ARTZqUKGz2Msmk79gwsY8ZSoFyMyPyEnoaDXR

    ## DATA EXTRACTION FROM ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/${liking_me}.Gstars.json
    my_star_level=$(cat ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/${liking_me}.Gstars.json | jq -r '.yours.level');
    gscore=$(cat ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/${liking_me}.Gstars.json | jq -r '.score');
    myfriendship=$(cat ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/${liking_me}.Gstars.json | jq -r '.likes[] | select(.issuer | strings | test("'$G1PUB'"))')

    ## OH MY FRIEND !
    if [[ "$my_star_level" != "null" && "${liking_me}" != "$G1PUB" ]]
    then
        # ADD ${liking_me} TO MY ipfs FRIENDS list
        echo "LIKING with $my_star_level stars : Friend Ŋ1 SCORE  $gscore "
        mkdir -p ~/.zen/game/players/${PLAYER}/FRIENDS/${liking_me}

        cp ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/${liking_me}.Gstars.json ~/.zen/game/players/${PLAYER}/FRIENDS/${liking_me}/ && rm -f ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/${liking_me}.Gstars.json
        echo "$my_star_level" > ~/.zen/game/players/${PLAYER}/FRIENDS/${liking_me}/stars.level && echo "***** $my_star_level STARS *****"

        ## GET FRIEND GCHANGE PROFILE
        ${MY_PATH}/timeout.sh -t 20 \
        ${MY_PATH}/jaklis/jaklis.py get \
        -p ${liking_me} > ~/.zen/game/players/${PLAYER}/FRIENDS/${liking_me}/gchange.json

        FRIENDTITLE=$(cat ~/.zen/game/players/${PLAYER}/FRIENDS/${liking_me}/gchange.json | jq -r '.title')

        ## GET FRIEND TW !!
        echo "Getting $FRIENDTITLE latest online TW..."
        YOU=$(ipfs swarm peers >/dev/null 2>&1 && echo "$USER" || ps auxf --sort=+utime | grep -w ipfs | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1);
        LIBRA=$(head -n 2 ~/.zen/Astroport.ONE/A_boostrap_nodes.txt | tail -n 1 | cut -d ' ' -f 2)
        echo "$LIBRA/ipns/$ASTRONAUTENS"
        echo "http://$myIP:8080/ipns/$ASTRONAUTENS ($YOU)"
        [[ $YOU ]] && ipfs --timeout 12s cat  /ipns/$ASTRONAUTENS > ~/.zen/game/players/${PLAYER}/FRIENDS/${liking_me}/index.html
        [[ ! -s ~/.zen/game/players/${PLAYER}/FRIENDS/${liking_me}/index.html ]] && curl -m 12 -so ~/.zen/game/players/${PLAYER}/FRIENDS/${liking_me}/index.html "$LIBRA/ipns/$ASTRONAUTENS"

        ## PLAYER TW EXISTING ?
        if [ ! -s ~/.zen/game/players/${PLAYER}/FRIENDS/${liking_me}/index.html ]; then

            ## AUCUN VISA ASTRONAUTE ENVOYER UN MESSAGE PAR GCHANGE
            echo "AUCUN TW ACTIF. ENVOYONS LUI UN MESSAGE..."
            $MY_PATH/jaklis/jaklis.py -k ~/.zen/game/players/${PLAYER}/secret.dunikey -n "https://data.gchange.fr" send -d "${liking_me}" -t "BRO !" -m ">>> (◕‿‿◕) <<< https://astroport.copylaradio.com >>> (◕‿‿◕) <<<"

        else

            echo "COOL MON AMI EST SUR IPFS"
            FTW="~/.zen/game/players/${PLAYER}/FRIENDS/${liking_me}/index.html"

            tiddlywiki --load ${FTW}  --output ~/.zen/tmp --render '.' "${liking_me}.MadeInZion.json" 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'MadeInZion'
            [[ ! -s ~/.zen/tmp/${liking_me}.MadeInZion.json ]] && echo "~~~ BROKEN $FTW (☓‿‿☓) ~~~" && continue
            FPLAYER=$(cat ~/.zen/tmp/${liking_me}.MadeInZion.json | jq -r .[].player)
            [[ ! $FPLAYER ]] && echo "NO PLAYER = BAD MadeInZion Tiddler" && continue

            ## CREATING 30 DAYS RSS STREAM
            tiddlywiki --load ${FTW} \
                                --output ~/.zen/game/players/${PLAYER}/ipfs --render '.' "${FPLAYER}.rss.json" 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[days:created[-30]]'
            [[ ! -s ~/.zen/game/players/${PLAYER}/ipfs/${FPLAYER}.rss.json ]] && echo "NO ${FPLAYER} RSS - CONTINUE -" && continue

            ## ADD THIS FPLAYER RSS FEED INTO PLAYER TW
            ## TODO CREATE 20H12 TIDDLER TO ADD TO MY W

        fi

        ## ACTIVER RECUP ANNONCES...
# SCRAPING DONNE LE BON COIN
# https://www.leboncoin.fr/recherche?text=donne&locations=Toulouse__43.59743304757555_1.4471155185604894_10000_5000&owner_type=private&sort=time&donation=1

        ## Get Ŋ2 LEVEL
        echo "(°▃▃°) (°▃▃°) (°▃▃°) Ŋ2 scraping  ~/.zen/game/players/${PLAYER}/FRIENDS/${liking_me}/friend_of_friend.json"
        for nid in $(cat ~/.zen/game/players/${PLAYER}/FRIENDS/${liking_me}/${liking_me}.Gstars.json | jq -r '.likes[].issuer');
        do

            echo "Ami(s) de cet Ami $linking_me : $nid"
            friend_of_friend=$(cat ~/.zen/game/players/${PLAYER}/FRIENDS/${liking_me}/${liking_me}.Gstars.json | jq -r '.likes[] | select(.issuer | strings | test("'$nid'"))')
            echo "$friend_of_friend" | jq -r > ~/.zen/game/players/${PLAYER}/FRIENDS/${liking_me}/FoF_$nid.json

        done

        echo "***** Keep G1/IPNS conversion *****"
        echo ${G1PUB} > ~/.zen/game/players/${PLAYER}/FRIENDS/${liking_me}/${ASTRONAUTENS}

    else

        echo "$my_star_level ETOILES RECUES ($gscore). Etablir un lien retour."
        $MY_PATH/jaklis/jaklis.py -k ~/.zen/game/players/${PLAYER}/secret.dunikey -n "https://data.gchange.fr" send -d "${G1PUB}" -t "Bro ?" -m "https://www.gchange.fr/#/app/user/${liking_me}/"
        echo "LIKING LATER."

    fi

    sleep $((1 + RANDOM % 2)) # SLOW DOWN

done


exit 0
