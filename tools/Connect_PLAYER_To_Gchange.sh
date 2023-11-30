#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# Takes care of analysing GChange+ Pod key and stars relations
################################################################################
# TODO: could make better ES stars requests
# https://forum.monnaie-libre.fr/t/proposition-damelioration-de-gchange/1940/49
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "$MY_PATH/my.sh"

export PLAYERFEEDS=""

######################################################################### CONNECT PLAYER WITH GCHANGE
# Check who is .current PLAYER
PLAYER="$1"

[[ ${PLAYER} == "" ]] && PLAYER=$(cat ~/.zen/game/players/.current/.player 2>/dev/null)
[[ ${PLAYER} == "" ]] && echo "ERROR PLAYER - EXIT" && exit 1
PSEUDO=$(cat ~/.zen/game/players/${PLAYER}/.pseudo 2>/dev/null)
[[ ${G1PUB} == "" ]] && G1PUB=$(cat ~/.zen/game/players/${PLAYER}/.g1pub 2>/dev/null)
[[ ${G1PUB} == "" ]] && echo "ERROR G1PUB - EXIT" && exit 1

    PSEUDO=$(cat ~/.zen/game/players/${PLAYER}/.pseudo 2>/dev/null)
    G1PUB=$(cat ~/.zen/game/players/${PLAYER}/.g1pub 2>/dev/null)
    ASTRONS=$(cat ~/.zen/game/players/${PLAYER}/.playerns 2>/dev/null)

    ## REFRESH ASTRONAUTE TW
    ASTRONAUTENS=$(ipfs key list -l | grep -w ${PLAYER} | cut -d ' ' -f1)
    [[ ! $ASTRONAUTENS ]] && echo "WARNING No ${PLAYER} in keystore -- EXIT" && exit 1
    [[ ! -f ~/.zen/game/players/${PLAYER}/QR.png ]] && echo "NOT MY ${PLAYER} -- EXIT" && exit 1

mkdir -p ~/.zen/tmp/${IPFSNODEID}/GCHANGE/${PLAYER}/

## VERIFY IT HAS ALREADY RUN

    ## GET GCHANGE PROFIL
    ${MY_PATH}/timeout.sh -t 20 \
    curl -s ${myDATA}/user/profile/${G1PUB} > ~/.zen/game/players/${PLAYER}/ipfs/gchange.json
    [[ ! $? == 0 ]] && echo "xxxxx ERROR PROBLEM WITH GCHANGE+ NODE ${myDATA} xxxxx" && exit 1
    [[ ! $(cat ~/.zen/game/players/${PLAYER}/ipfs/gchange.json | jq -r '.title' 2>/dev/null) ]] \
        && echo "xxxxx GCHANGE+ MISSING ACCOUNT ${myDATA} xxxxx" \
        && ${MY_PATH}/jaklis/jaklis.py -k ~/.zen/game/players/${PLAYER}/secret.dunikey set -n " " -v " " -a " " -d " " -pos 0.00 0.00 -s https://qo-op.com -A ${MY_PATH}/../images/plain.png \
        && exit 0

    # $MY_PATH/jaklis/jaklis.py -k ~/.zen/game/players/${PLAYER}/secret.dunikey get >  ~/.zen/game/players/${PLAYER}/ipfs/gchange.json
    ## GET AVATAR PICTURE
    cat ~/.zen/game/players/${PLAYER}/ipfs/gchange.json | jq -r '._source.avatar._content' | base64 -d > "$HOME/.zen/game/players/${PLAYER}/ipfs/G1SSB/_g1.gchange_avatar.png" 2>/dev/null
    # CLEANING BAD FILE TYPE
    [[ ! $(file -b "$HOME/.zen/game/players/${PLAYER}/ipfs/G1SSB/_g1.gchange_avatar.png" | grep PNG) ]] && rm "$HOME/.zen/game/players/${PLAYER}/ipfs/G1SSB/_g1.gchange_avatar.png"

    ## GET CESIUM PUBKEY & C+ PROFILE
    CPUB=$(cat ~/.zen/game/players/${PLAYER}/ipfs/gchange.json | jq -r '._source.pubkey' 2>/dev/null)
    if [[ $CPUB && $CPUB != 'null'  ]]; then

        echo "OHH ... GET CPUB+ PROFILE  .... $CPUB"

        ${MY_PATH}/timeout.sh -t 20 \
        curl -s ${myCESIUM}/user/profile/${CPUB} > ~/.zen/game/players/${PLAYER}/ipfs/cesium.json 2>/dev/null
        [[ ! $? == 0 ]] && echo "xxxxx ERROR PROBLEM WITH CESIUM+ NODE ${myCESIUM} xxxxx"

        cat ~/.zen/game/players/${PLAYER}/ipfs/cesium.json | jq -r '._source.avatar._content' | base64 -d > "$HOME/.zen/game/players/${PLAYER}/ipfs/G1SSB/_g1.cesium_avatar.png" 2>/dev/null
        # CLEANING NOT PNG FILE
        [[ ! $(file -b "$HOME/.zen/game/players/${PLAYER}/ipfs/G1SSB/_g1.cesium_avatar.png" | grep PNG) ]] && rm "$HOME/.zen/game/players/${PLAYER}/ipfs/G1SSB/_g1.cesium_avatar.png"


        CPSEUDO=$(cat ~/.zen/game/players/${PLAYER}/ipfs/cesium.json | jq -r '.title' 2>/dev/null)

        [[ ${CPSEUDO} ]] \
        && echo "♥PARTNER ${CPSEUDO}" \
        && echo "$CPUB" > ~/.zen/game/players/${PLAYER}/ipfs/G1SSB/G1CPUB \
        || echo "NO CPUB CESIUM PROFILE"

    else

        echo "NO CPUB CESIUM PROFILE"

    fi

        echo "... TRY TO GET CESIUM+ WALLET PROFILE .... "

        ${MY_PATH}/timeout.sh -t 20 \
        curl -s ${myCESIUM}/user/profile/${G1PUB} > ~/.zen/game/players/${PLAYER}/ipfs/cesium.json 2>/dev/null
        [[ ! $? == 0 ]] && echo "xxxxx ERROR PROBLEM WITH CESIUM+ NODE ${myCESIUM} xxxxx"

        cat ~/.zen/game/players/${PLAYER}/ipfs/cesium.json | jq -r '._source.avatar._content' | base64 -d > "$HOME/.zen/game/players/${PLAYER}/ipfs/G1SSB/_g1.cesium_avatar.png" 2>/dev/null
        [[ ! $(file -b "$HOME/.zen/game/players/${PLAYER}/ipfs/G1SSB/_g1.cesium_avatar.png" | grep PNG) ]] && rm "$HOME/.zen/game/players/${PLAYER}/ipfs/G1SSB/_g1.cesium_avatar.png"

        CPSEUDO=$(cat ~/.zen/game/players/${PLAYER}/ipfs/cesium.json | jq -r '.title' 2>/dev/null)

        [[ ${CPSEUDO} ]] \
        && echo "Ğ1 WALLET " \
        && echo "${G1PUB}" > ~/.zen/game/players/${PLAYER}/ipfs/G1SSB/G1WALLET \
        || echo "NO WALLET FOR THIS PLAYER"

    ## KEEPING ALREADY EXISTING PROFILE DATA
    GPSEUDO=$(cat ~/.zen/game/players/${PLAYER}/ipfs/gchange.json | jq -r '.title' 2>/dev/null)
    [[ ! ${GPSEUDO} || ${GPSEUDO} == "null" ]] &&  GPSEUDO="$PSEUDO"
    CPSEUDO=$(cat ~/.zen/game/players/${PLAYER}/ipfs/cesium.json | jq -r '.title' 2>/dev/null)
    [[ ! ${CPSEUDO} || ${CPSEUDO} == "null" ]] &&  CPSEUDO="${PLAYER}"

    GDESCR=$(cat ~/.zen/game/players/${PLAYER}/ipfs/gchange.json | jq -r '.description' 2>/dev/null)
    [[ ! ${GDESCR} || ${GDESCR} == "null" ]] &&  GDESCR="Astronaute GChange"
    CDESCR=$(cat ~/.zen/game/players/${PLAYER}/ipfs/cesium.json | jq -r '.description' 2>/dev/null)
    [[ ! ${CDESCR} || ${CDESCR} == "null" ]] &&  CDESCR="Portefeuille Astro"

    GVILLE=$(cat ~/.zen/game/players/${PLAYER}/ipfs/gchange.json | jq -r '.city' 2>/dev/null)
    [[ ! ${GVILLE} || ${GVILLE} == "null" ]] &&  GVILLE=""
    CVILLE=$(cat ~/.zen/game/players/${PLAYER}/ipfs/cesium.json | jq -r '.city' 2>/dev/null)
    [[ ! ${CVILLE} || ${CVILLE} == "null" ]] &&  CVILLE=""

    GADRESSE=$(cat ~/.zen/game/players/${PLAYER}/ipfs/gchange.json | jq -r '.address' 2>/dev/null)
    [[ ! ${GADRESSE} || ${GADRESSE} == "null" ]] &&  GADRESSE=""
    CADRESSE=$(cat ~/.zen/game/players/${PLAYER}/ipfs/cesium.json | jq -r '.address' 2>/dev/null)
    [[ ! ${CADRESSE} || ${CADRESSE} == "null" ]] &&  CADRESSE=""

    # POSITION=$(cat ~/.zen/game/players/${PLAYER}/ipfs/gchange.json | jq -r '.geoPoint')
    # SITE=$(cat ~/.zen/game/players/${PLAYER}/ipfs/gchange.json | jq -r '.socials' 2>/dev/null)
    echo ">> GCHANGE+ : ${GPSEUDO} - ${GDESCR} : ${G1PUB} ($CPUB) <<"
    echo ">> CESIUM+ : ${CPSEUDO} - ${CDESCR} : ${G1PUB} <<"


    ########################################################################
    # echo "set -n "${GPSEUDO}" -d "${GDESCR}" -v "${GVILLE}" -a "${GADRESSE}""
    ########################################################################
    #~ if [[ ! -s ~/.zen/game/players/${PLAYER}/ipfs/G1SSB/G1WALLET && -s ~/.zen/game/players/${PLAYER}/QRTWavatar.png ]]; then

        #~ echo "CREATING GCHANGE+ PROFILE https://www.gchange.fr/#/app/user?q=${G1PUB}"

        #~ ${MY_PATH}/timeout.sh -t 20 \
        #~ $MY_PATH/jaklis/jaklis.py -k ~/.zen/game/players/${PLAYER}/secret.dunikey set -n "${GPSEUDO}" -d "${GDESCR}" -v "${GVILLE}" -a "${GADRESSE}" -s "$LIBRA/ipns/$ASTRONAUTENS"  -A ~/.zen/game/players/${PLAYER}/QRG1avatar.png #GCHANGE+
        #~ [[ ! $? == 0 ]] && echo "GCHANGE PROFILE CREATION FAILED" \
        #~ || cat ~/.zen/game/players/${PLAYER}/ipfs/gchange.json > ~/.zen/game/players/${PLAYER}/ipfs/G1SSB/gchange.1st.json

        #~ echo " CREATING CESIUM+ https://demo.cesium.app/#/app/wot/lg?q=${G1PUB}"

        #~ ${MY_PATH}/timeout.sh -t 20 \
        #~ $MY_PATH/jaklis/jaklis.py -k ~/.zen/game/players/${PLAYER}/secret.dunikey -n ${myCESIUM} set -n "${CPSEUDO}" -d "${CDESCR}" -v "${CVILLE}" -a "${CADRESSE}" --s "http://ipfs.localhost:8080/ipns/$ASTRONAUTENS" -A ~/.zen/game/players/${PLAYER}/QRTWavatar.png #CESIUM+
        #~ [[ ! $? == 0 ]] && echo "CESIUM PROFILE CREATION FAILED" \
        #~ || cat ~/.zen/game/players/${PLAYER}/ipfs/cesium.json > ~/.zen/game/players/${PLAYER}/ipfs/G1SSB/cesium.1st.json

    #~ fi


## GET LAST ONLINE gchange & cesium PROFILE
${MY_PATH}/timeout.sh -t 20 \
$MY_PATH/jaklis/jaklis.py -k ~/.zen/game/players/${PLAYER}/secret.dunikey -n ${myDATA} get > ~/.zen/game/players/${PLAYER}/ipfs/gchange.json
${MY_PATH}/timeout.sh -t 20 \
$MY_PATH/jaklis/jaklis.py -k ~/.zen/game/players/${PLAYER}/secret.dunikey -n ${myCESIUM} get > ~/.zen/game/players/${PLAYER}/ipfs/cesium.json

########################################################################
        # Get PLAYER wallet amount :: ~/.zen/game/players/${PLAYER}/ipfs/G1SSB/COINS
        COINS=$($MY_PATH/COINScheck.sh ${G1PUB} | tail -n 1)
        echo "+++ YOU have ${COINS} Ğ1 Coins +++"
########################################################################

########################################################################
########################################################################
echo "### ${PLAYER}  #################"
echo "SCANNING - ${G1PUB} STAR FRIENDS"
echo "########################################################################"
################## CHECKING WHO GAVE ME STARS
################## SEND ipfstryme MESSAGES to FRIENDS
rm -f ~/.zen/tmp/${IPFSNODEID}/GCHANGE/${PLAYER}/my_star_level

## Getting Gchange  liking_me list
echo "Checking received stars ON $myDATA"
################################## JAKLIS PLAYER stars
${MY_PATH}/timeout.sh -t 30 \
${MY_PATH}/jaklis/jaklis.py -k ~/.zen/game/players/${PLAYER}/secret.dunikey -n "$myDATA" stars > ~/.zen/tmp/${IPFSNODEID}/GCHANGE/${PLAYER}/received_stars.json
[[ ! $? == 0 ]] && echo "> WARNING $myDATA UNREACHABLE"

[[ ! $(cat ~/.zen/tmp/${IPFSNODEID}/GCHANGE/${PLAYER}/received_stars.json | jq -r '.likes[].issuer') ]] && echo "Activez votre Toile de Confiance Ŋ1" && exit 0

## GETTING ALL INCOMING liking_me FRIENDS
cat ~/.zen/tmp/${IPFSNODEID}/GCHANGE/${PLAYER}/received_stars.json | jq -r '.likes[].issuer' | sort | uniq > ~/.zen/tmp/${IPFSNODEID}/GCHANGE/${PLAYER}/liking_me
# echo "cat ~/.zen/tmp/${IPFSNODEID}/GCHANGE/${PLAYER}/received_stars.json | jq -r" # DEBUG
## ADD ALREADY FRIENDS (in case Gchange+ timout)
find ~/.zen/game/players/${PLAYER}/FRIENDS/* -type d | rev | cut -d '/' -f 1 | rev >> ~/.zen/tmp/${IPFSNODEID}/GCHANGE/${PLAYER}/liking_me

for liking_me in $(cat ~/.zen/tmp/${IPFSNODEID}/GCHANGE/${PLAYER}/liking_me | sort | uniq);
do
    [[ "${liking_me}" == "" ]] && continue ## Protect from empty line !!
    echo "........................."
    FRIENDNS=$(${MY_PATH}/g1_to_ipfs.py ${liking_me})
    echo "==========================="
    echo "${liking_me} IS LIKING ME"
    echo "TW ? $LIBRA/ipns/${FRIENDNS} "

##### CHECKING IF WE LIKE EACH OTHER Ŋ1 LEVEL
    ################################## JAKLIS LIKING_ME stars
    ${MY_PATH}/timeout.sh -t 20 \
    ${MY_PATH}/jaklis/jaklis.py \
    -k ~/.zen/game/players/${PLAYER}/secret.dunikey \
    stars -p ${liking_me} > ~/.zen/tmp/${IPFSNODEID}/GCHANGE/${PLAYER}/${liking_me}.Gstars.json

    cat ~/.zen/tmp/${IPFSNODEID}/GCHANGE/${PLAYER}/${liking_me}.Gstars.json | jq -rc

    ## ZOMBIE PROTECTION - PURGE AFTER 365 DAYS
    find ~/.zen/game/players/${PLAYER}/FRIENDS/* -mtime +365 -type d -exec rm -Rf '{}' \; 2>/dev/null

    ## COUNT NUMBER OF STAR COLLECT TRIES
    try=$(cat ~/.zen/game/players/${PLAYER}/FRIENDS/${liking_me}.try 2>/dev/null) || try=0
    [[ $try > 2 && ( $try < 30 || $try > 31 ) ]] \
    && echo "${liking_me} TOO MANY TRY ( $try )" \
    && ((try++)) && echo $try > ~/.zen/game/players/${PLAYER}/FRIENDS/${liking_me}.try \
    && continue

#### TODO RECUP ANNONCES Gchange ADD TO TW
## https://www.gchange.fr/#/app/records/wallet?q=2geH4d2sndR47XWtfDWsfLLDVyNNnRsnUD3b1sk9zYc4&old
## https://www.gchange.fr/#/app/market/records/42LqLa7ARTZqUKGz2Msmk79gwsY8ZSoFyMyPyEnoaDXR

    ## DATA EXTRACTION FROM ~/.zen/tmp/${IPFSNODEID}/GCHANGE/${PLAYER}/${liking_me}.Gstars.json
    my_star_level=$(cat ~/.zen/tmp/${IPFSNODEID}/GCHANGE/${PLAYER}/${liking_me}.Gstars.json | jq -r '.yours.level') || my_star_level=1
    gscore=$(cat ~/.zen/tmp/${IPFSNODEID}/GCHANGE/${PLAYER}/${liking_me}.Gstars.json | jq -r '.score')
    myfriendship=$(cat ~/.zen/tmp/${IPFSNODEID}/GCHANGE/${PLAYER}/${liking_me}.Gstars.json | jq -r '.likes[] | select(.issuer | strings | test("'${G1PUB}'"))')

    ## OH MY FRIEND !
    if [[ "${my_star_level}" != "null" && "${liking_me}" != "${G1PUB}" ]]
    then
        # ADD ${liking_me} TO MY ipfs FRIENDS list
        echo "LIKING with ${my_star_level} stars : Friend Ŋ1 SCORE  $gscore "
        mkdir -p ~/.zen/game/players/${PLAYER}/FRIENDS/${liking_me}

        cp ~/.zen/tmp/${IPFSNODEID}/GCHANGE/${PLAYER}/${liking_me}.Gstars.json ~/.zen/game/players/${PLAYER}/FRIENDS/${liking_me}/
        echo "${my_star_level}" > ~/.zen/game/players/${PLAYER}/FRIENDS/${liking_me}/stars.level ## LOCAL
        echo "${my_star_level}" > ~/.zen/tmp/${IPFSNODEID}/GCHANGE/${PLAYER}/${liking_me}.stars.level ## SWARM
        echo "***** ${my_star_level} STARS *****"

        ## GET FRIEND GCHANGE PROFILE
        echo "GET FRIEND gchange.json"
        ${MY_PATH}/timeout.sh -t 20 \
        ${MY_PATH}/jaklis/jaklis.py get \
        -p ${liking_me} > ~/.zen/game/players/${PLAYER}/FRIENDS/${liking_me}/gchange.json

        cp ~/.zen/game/players/${PLAYER}/FRIENDS/${liking_me}/gchange.json \
                ~/.zen/tmp/${IPFSNODEID}/GCHANGE/${PLAYER}/${liking_me}.gchange.json

        FRIENDTITLE=$(cat ~/.zen/game/players/${PLAYER}/FRIENDS/${liking_me}/gchange.json | jq -r '.title')

        ## GET FRIEND TW !!
        echo "SEARCHING $FRIENDTITLE - ONLINE TW -"
        YOU=$(ipfs swarm peers >/dev/null 2>&1 && echo "$USER" || ps auxf --sort=+utime | grep -w ipfs | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1);
        LIBRA=$(head -n 2 ~/.zen/Astroport.ONE/A_boostrap_nodes.txt | tail -n 1 | cut -d ' ' -f 2)

        # DISPLAY TIMER
        # ${MY_PATH}/displaytimer.sh 60 &


        [[ $YOU ]] \
        && echo "ipfs --timeout 120s cat  /ipns/${FRIENDNS} > ~/.zen/game/players/${PLAYER}/FRIENDS/${liking_me}/index.html" \
        && ipfs --timeout 120s cat  /ipns/${FRIENDNS} > ~/.zen/game/players/${PLAYER}/FRIENDS/${liking_me}/index.html

        [[ ! -s ~/.zen/game/players/${PLAYER}/FRIENDS/${liking_me}/index.html ]] \
        && echo "curl -m 120 -so ~/.zen/game/players/${PLAYER}/FRIENDS/${liking_me}/index.html $LIBRA/ipns/${FRIENDNS}" \
        && curl -m 120 -so ~/.zen/game/players/${PLAYER}/FRIENDS/${liking_me}/index.html "$LIBRA/ipns/${FRIENDNS}"

        ## PLAYER TW EXISTING ?
        if [ ! -s ~/.zen/game/players/${PLAYER}/FRIENDS/${liking_me}/index.html ]; then

            ## AUCUN VISA ASTRONAUTE ENVOYER UN MESSAGE PAR GCHANGE
            echo "AUCUN TW ACTIF. PREVENONS LE"
            $MY_PATH/jaklis/jaklis.py -k ~/.zen/game/players/${PLAYER}/secret.dunikey send -d "${liking_me}" -t "HEY BRO !" -m "G1 ♥BOX : https://ipfs.copylaradio.com/ipns/$ASTRONAUTENS"

            ## +1 TRY
            try=$((try+1)) && echo $try > ~/.zen/game/players/${PLAYER}/FRIENDS/${liking_me}.try

        else

            FTW="$HOME/.zen/game/players/${PLAYER}/FRIENDS/${liking_me}/index.html"
            echo "COOL MON AMI PUBLIE SUR IPFS : $FTW"

            # LOG
            # echo tiddlywiki --load ${FTW} --output ~/.zen/tmp --render '.' "${liking_me}.MadeInZion.json" 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'MadeInZion'
            tiddlywiki --load ${FTW} --output ~/.zen/tmp --render '.' "${liking_me}.MadeInZion.json" 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'MadeInZion'
            [[ ! -s ~/.zen/tmp/${liking_me}.MadeInZion.json ]] && echo "~~~ BROKEN $FTW (☓‿‿☓) BAD ~/.zen/tmp/${liking_me}.MadeInZion.json ~~~" && continue
            FPLAYER=$(cat ~/.zen/tmp/${liking_me}.MadeInZion.json | jq -r .[].player)

            [[ ! $FPLAYER ]] \
                && echo "NO PLAYER = BAD MadeInZion Tiddler" \
                && rm -Rf ~/.zen/game/players/${PLAYER}/FRIENDS/${liking_me} \
                && continue

            tiddlywiki --load ${FTW} --output ~/.zen/tmp --render '.' "${liking_me}.Astroport.json" 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'Astroport'
            [[ ! -s ~/.zen/tmp/${liking_me}.Astroport.json ]] && echo "~~~ BROKEN $FTW (☓‿‿☓) BAD ~/.zen/tmp/${liking_me}.Astroport.json ~~~" && continue
            FASTRONAUTENS=$(cat ~/.zen/tmp/${liking_me}.Astroport.json | jq -r .[].astronautens)
            export ASTRONAUTS="$FASTRONAUTENS\n${ASTRONAUTS}"
            echo "${ASTRONAUTS}" > ~/.zen/tmp/${IPFSNODEID}/RSS/${PLAYER}/ASTRONAUTS

            ## CREATING 30 DAYS RSS STREAM
            tiddlywiki --load ${FTW} \
                                --output ~/.zen/game/players/${PLAYER}/ipfs --render '.' "${FPLAYER}.rss.json" 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[days:created[-30]]'
            [[ ! -s ~/.zen/game/players/${PLAYER}/ipfs/${FPLAYER}.rss.json ]] && echo "NO ${FPLAYER} RSS - BAD ~/.zen/game/players/${PLAYER}/ipfs/${FPLAYER}.rss.json -" && continue

            echo "> DEBUG RSS : cat ~/.zen/game/players/${PLAYER}/ipfs/${FPLAYER}.rss.json | jq -r"
            echo
            tiddlywiki --load ${FTW} \
                                --output ~/.zen/game/players/${PLAYER}/ipfs --render '.' "${FPLAYER}.lightbeam-key.json" 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '$:/plugins/astroport/lightbeams/saver/ipns/lightbeam-key'
            [[ ! -s ~/.zen/game/players/${PLAYER}/ipfs/${FPLAYER}.lightbeam-key.json ]] && echo "NO ${FPLAYER} lightbeam-key - CONTINUE -" && continue
            ASTRONAUTEFEED=$(cat ~/.zen/game/players/${PLAYER}/ipfs/${FPLAYER}.lightbeam-key.json | jq -r .[].text)

            echo "DEBUG LIGHTBEAM : cat ~/.zen/game/players/${PLAYER}/ipfs/${FPLAYER}.lightbeam-key.json | jq -r"
            echo
        ## RESET try
        echo 0 > ~/.zen/game/players/${PLAYER}/FRIENDS/${liking_me}.try
        ## ★★★★★ ############################################################################
            #~ ## liking_me IS A GOOD FRIEND. PLAYER Send ${my_star_level} COIN
            #~ $MY_PATH/jaklis/jaklis.py -k ~/.zen/game/players/${PLAYER}/secret.dunikey pay -a ${my_star_level} -p ${liking_me} -c "BRO:star:${my_star_level}" -m
            #~ [[ ! $? == 0 ]] \
            #~ && echo "PLAYER BROKE. G00D FRIEND. ${liking_me}" \
            #~ && $MY_PATH/jaklis/jaklis.py -k ~/.zen/game/players/${PLAYER}/secret.dunikey send -d "${G1PUB}" -t "BRO YOU BROKE" -m "PLEASE REFILL WALLET: ${G1PUB} ~:star:~ ${my_star_level} stars : Friend Ŋ1 SCORE  $gscore ${liking_me} "

        #~ ############################################################################### ★★★★★
            #~ ## DEFAULT SAME CONFIDENCE LEVEL
            #~ echo "★ SENDING ${my_star_level} STAR(s) ★"
            #~ $MY_PATH/jaklis/jaklis.py -k ~/.zen/game/players/${PLAYER}/secret.dunikey stars -p $liking_me -n ${my_star_level}

        ######################################
            ## ADD THIS FPLAYER RSS FEED INTO PLAYER TW
            ## PUSH DATA TO 12345 SWARM KEY
            mkdir -p ~/.zen/tmp/${IPFSNODEID}/RSS/${PLAYER}
            cp -f ~/.zen/game/players/${PLAYER}/ipfs/${FPLAYER}.rss.json ~/.zen/tmp/${IPFSNODEID}/RSS/${PLAYER}/${FPLAYER}.rss.json

                export FRIENDSFEEDS="$ASTRONAUTEFEED\n${FRIENDSFEEDS}"
                echo "${FRIENDSFEEDS}" > ~/.zen/tmp/${IPFSNODEID}/RSS/${PLAYER}/FRIENDSFEEDS

            echo "(☉_☉ ) (☉_☉ ) (☉_☉ ) : FRIENDSFEEDS=" ${FRIENDSFEEDS}

                export IFRIENDHEAD="<a target='you' href='/ipns/"${FRIENDNS}"'>$FRIENDTITLE</a> ${IFRIENDHEAD}"
                echo "${IFRIENDHEAD}" > ~/.zen/tmp/${IPFSNODEID}/RSS/${PLAYER}/IFRIENDHEAD

            echo "(☉_☉ ) (☉_☉ ) (☉_☉ ) : IFRIENDHEAD=" ${IFRIENDHEAD}


            echo "APP=RSS : PLAYER  $FPLAYER RSS PUBLICATION READY"
            echo "~/.zen/tmp/${IPFSNODEID}/RSS/${PLAYER}/${FPLAYER}.rss.json"

        fi

        ## Get Ŋ2 LEVEL
        echo "(°▃▃°) (°▃▃°) (°▃▃°) Ŋ2 scraping  ~/.zen/game/players/${PLAYER}/FRIENDS/${liking_me}/friend_of_friend.json"
        for nid in $(cat ~/.zen/game/players/${PLAYER}/FRIENDS/${liking_me}/${liking_me}.Gstars.json | jq -r '.likes[].issuer');
        do

            echo "Ami(s) de cet Ami $linking_me : $nid"
            friend_of_friend=$(cat ~/.zen/game/players/${PLAYER}/FRIENDS/${liking_me}/${liking_me}.Gstars.json | jq -r '.likes[] | select(.issuer | strings | test("'$nid'"))')
            echo "$friend_of_friend" | jq -r > ~/.zen/game/players/${PLAYER}/FRIENDS/${liking_me}/FoF_$nid.json

            cp ~/.zen/game/players/${PLAYER}/FRIENDS/${liking_me}/FoF_$nid.json \
                    ~/.zen/tmp/${IPFSNODEID}/GCHANGE/${PLAYER}/${liking_me}.FoF_$nid.json

        done

    else
        #########################################
        ## COOL FEATURE FOR GCHANGE ACCOUNT CONFIDENCE
        ## IS IT REALLY A FRIEND I LIKE ?
        echo "BRO?"
        $MY_PATH/jaklis/jaklis.py -k ~/.zen/game/players/${PLAYER}/secret.dunikey send -d "${G1PUB}" -t "Bro ?" -m "$myGCHANGE/#/app/user/${liking_me}/"
        $MY_PATH/jaklis/jaklis.py -k ~/.zen/game/players/${PLAYER}/secret.dunikey -n ${myCESIUM} send -d "${G1PUB}" -t "Bro ?" -m "$myGCHANGE/#/app/user/${liking_me}/"
        mkdir -p ~/.zen/game/players/${PLAYER}/FRIENDS/
        try=$((try+1)) && echo $try > ~/.zen/game/players/${PLAYER}/FRIENDS/${liking_me}.try

    fi

    sleep $((1 + RANDOM % 2)) # SLOW DOWN

done


exit 0
