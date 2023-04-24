#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"${MY_PATH}\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/my.sh"

! ipfs swarm peers >/dev/null 2>&1 && echo "Lancez 'ipfs daemon' SVP" && exit 1
################################################################################
mkdir -p ~/.zen/tmp/${MOATS}

SALT="$1"
PEPPER="$2"
PLAYER="$3"
PSEUDO="$4"

## Fill UP TW with VIDEO URL
URL="$5"
################################################################################
YOU=$(myIpfsApi);
LIBRA=$(head -n 2 ${MY_PATH}/../A_boostrap_nodes.txt | tail -n 1 | cut -d ' ' -f 2)
################################################################################

################################################################################

## CHECK if PLAYER resolve any ASTRONAUTENS
#~ [[ ${PLAYER} ]] && ASTRONAUTENS=$(ipfs key list -l | grep -w "${PLAYER}" | cut -d ' ' -f 1)
#~ [[ ${ASTRONAUTENS} ]] && echo "WARNING IPNS ${PLAYER} EXISTANT ${myIPFS}/ipns/${ASTRONAUTENS} - EXIT -" && exit 0

mkdir -p ~/.zen/tmp/${MOATS}/TW

## Chargement TW !!!
if [[ $SALT != "" && PEPPER != "" ]]; then
    ASTRO=""

    ${MY_PATH}/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/player.key "$SALT" "$PEPPER" 2>/dev/null
    ASTRONAUTENS=$(ipfs key import ${MOATS} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/player.key 2>/dev/null)
    # echo "/ipns/${ASTRONAUTENS}"

    echo "SCANNING /ipns/${ASTRONAUTENS} for 180s"
    ## GETTING LAST TW via IPFS or HTTP GW
    [[ $YOU ]] \
    && ipfs --timeout 180s cat  /ipns/${ASTRONAUTENS} > ~/.zen/tmp/${MOATS}/TW/index.html

    [[ $XDG_SESSION_TYPE == 'x11' ]] \
    && [[ -s ~/.zen/tmp/${MOATS}/TW/index.html ]] \
    && echo "TYPE 'yes' TO RESET TW. HIT ENTER TO KEEP IT." \
    && read ENTER \
    && [[ $ENTER != "" ]] && rm ~/.zen/tmp/${MOATS}/TW/index.html

    #~ [[ ! -s ~/.zen/tmp/${MOATS}/TW/index.html ]] \
    #~ && echo "Trying curl on $LIBRA" \
    #~ && curl -m 30 -so ~/.zen/tmp/${MOATS}/TW/index.html "$LIBRA/ipns/${ASTRONAUTENS}"

    #############################################
    ## AUCUN RESULTAT
    if [ ! -s ~/.zen/tmp/${MOATS}/TW/index.html ]; then

        ipfs key rm ${MOATS} 2>/dev/null ## CLEANING
        echo "CREATION TW Astronaute" ## Nouveau Compte Astronaute
        echo
        echo "***** Activation du Canal TW Astronaute ${PLAYER} *****"
        cp ${MY_PATH}/../templates/twdefault.html ~/.zen/tmp/${MOATS}/TW/index.html

    else
    #############################################
    # EXISTING TW : DATA TESTING & CACHE
        rm -f ~/.zen/tmp/${MOATS}/Astroport.json
        tiddlywiki --load ~/.zen/tmp/${MOATS}/TW/index.html --output ~/.zen/tmp/${MOATS} --render '.' 'Astroport.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'Astroport'
        ASTROPORT=$(cat ~/.zen/tmp/${MOATS}/Astroport.json | jq -r .[].astroport)
        echo "ASTROPORT=$ASTROPORT"
        tiddlywiki --load ~/.zen/tmp/${MOATS}/TW/index.html --output ~/.zen/tmp/${MOATS} --render '.' 'AstroID.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'AstroID'
        AstroID=$(cat ~/.zen/tmp/${MOATS}/AstroID.json | jq -r .[]._canonical_uri)
        HPass=$(cat ~/.zen/tmp/${MOATS}/AstroID.json | jq -r .[].HPASS)
        echo "AstroID=$AstroID ($HPass)"
        tiddlywiki --load ~/.zen/tmp/${MOATS}/TW/index.html --output ~/.zen/tmp/${MOATS} --render '.' 'G1Visa.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'G1Visa'
        G1Visa=$(cat ~/.zen/tmp/${MOATS}/G1Visa.json | jq -r .[]._canonical_uri)
        echo "G1Visa=$G1Visa"

        if [[ $ASTROPORT != "" ]]; then

            IPNSTAIL=$(echo $ASTROPORT | rev | cut -f 1 -d '/' | rev) # Remove "/ipns/" part
            echo "TW ASTROPORT GATEWAY : ${ASTROPORT}"
            echo "---> CONNECTING PLAYER $(cat ~/.zen/tmp/${MOATS}/Astroport.json | jq -r .[].pseudo) TW NOW with $IPFSNODEID"

        else

            echo ">> NO ACTIVE TW - CREATING FRESH NEW ONE"
            cp ${MY_PATH}/../templates/twdefault.html ~/.zen/tmp/${MOATS}/TW/index.html

        fi

        ipfs key rm ${MOATS} 2>/dev/null ## CLEANING

    fi

fi


################################################################################
TWMODEL="/ipfs/bafybeibsy5fu4wrjr2gtjljvkuady3cydgrcbr5mdw2ogkrtm4eeo7xzue"
TWLINK="/ipfs/bafybeigyfttjvabeeoa4hbsvtegsqkw3riuquhbil55qhwe3s3q4tesyxi"
# ipfs cat $TWMODEL > templates/twdefault.html
##################################################### # NEW PLAYER ###############
################################################################################
echo "=============================================
ASTROPORT DIPLOMATIC PASSPORT - MadeInZion VISA -
=============================================
A Cryptographic Key to control your INTERNET
Adventure & Exploration P2P Terraforming Game.
=============================================
Bienvenue 'Astronaute'"; sleep 1

echo "Création de votre PLAYER, votre PSEUDO et PASS (6 chiffres)"

[[ $SALT == "" ]] && SALT=$(${MY_PATH}/diceware.sh 4 | xargs)
echo "-> SALT : $SALT"

[[ $PEPPER == "" ]] && PEPPER=$(${MY_PATH}/diceware.sh 2 | xargs)
echo "-> PEPPER : $PEPPER"

PSEUDO=${PLAYER%%[0-9]*}

[[ ! $PSEUDO ]] && echo "Choisissez un pseudo : " && read PSEUDO
PSEUDO=${PSEUDO,,}
# PSEUDO=${PSEUDO%%[0-9]*}

[[ $(ls ~/.zen/game/players/$PSEUDO 2>/dev/null) ]] && echo "$PSEUDO EST DEJA UN PLAYER. EXIT" && exit 1

# PSEUDO=${PSEUDO,,} #lowercase
[[ ! ${PLAYER} ]] && PLAYER=${PSEUDO}${RANDOM:0:3}@$(${MY_PATH}/diceware.sh 1 | xargs).${RANDOM:0:3} \
                            && echo "ADRESSE EMAIL ?" && read OPLAYER && [[ $OPLAYER ]] && PLAYER=$OPLAYER

PLAYER=${PLAYER,,}

[[ ! $PSEUDO ]] && PSEUDO="Anonymous"
echo; echo "Génération de votre crypto identité PLAYER :"; sleep 1; echo "${PLAYER}"; sleep 2

# 6 DIGIT PASS CODE TO PROTECT QRSEC
PASS=$(echo "${RANDOM}${RANDOM}${RANDOM}${RANDOM}" | tail -c-7)

############################################################
######### TODO Ajouter d'autres clefs IPNS, GPG ?
# MOANS=$(ipfs key gen moa_${PLAYER})
# MOAKEYFILE=$(${MY_PATH}/give_me_keystore_filename.py "moa_${PLAYER}")
# echo "Coffre personnel multimedia journalisé dans votre 'Astroport' (amis de niveau 3)"
# echo "Votre clef moa_${PLAYER} <=> $MOANS ($MOAKEYFILE)"; sleep 2
############################################################
echo
echo; echo "Création de votre clef multi-accès..."; sleep 2
echo;

${MY_PATH}/keygen -t duniter -o ~/.zen/tmp/${MOATS}/secret.dunikey "$SALT" "$PEPPER"

G1PUB=$(cat ~/.zen/tmp/${MOATS}/secret.dunikey | grep 'pub:' | cut -d ' ' -f 2)

[[ ! $G1PUB ]] && echo "Désolé. clef Cesium absente." && exit 1


    ## CREATE Player personnal files storage and IPFS publish directory
    mkdir -p ~/.zen/game/players/${PLAYER} # Prepare PLAYER datastructure

        # PLAYER=geg-la_debrouille@super.chez-moi.com
YUSER=$(echo ${PLAYER} | cut -d '@' -f1)    # YUSER=geg-la_debrouille
LYUSER=($(echo "$YUSER" | sed 's/[^a-zA-Z0-9]/\ /g')) # LYUSER=(geg la debrouille)
CLYUSER=$(printf '%s\n' "${LYUSER[@]}" | tac | tr '\n' '.' ) # CLYUSER=debrouille.la.geg.
YOMAIN=$(echo ${PLAYER} | cut -d '@' -f 2)    # YOMAIN=super.chez-moi.com
# echo "NEXT STYLE GW : https://ipfs.$CLYUSER$YOMAIN.$(myHostName)"
# echo "MY PLAYER API GW : $(myPlayerApiGw)"

NID="${myIPFS}"
WID="https://ipfs.$CLYUSER$YOMAIN.$(myHostName)/api" ## Next Generation API # TODO PLAYER IPFS Docker entrance
WID="https://ipfs.$(myHostName)/api"
# WID="http://ipfs.$(myHostName):5001"
USALT=$(echo "$SALT" | jq -Rr @uri)
UPEPPER=$(echo "$PEPPER" | jq -Rr @uri)
DISCO="/?salt=${USALT}&pepper=${UPEPPER}"

[[ $isLAN ]] && NID="http://ipfs.localhost:8080" \
                        && WID="http://ipfs.localhost:5001"

####

    mv ~/.zen/tmp/${MOATS}/secret.dunikey ~/.zen/game/players/${PLAYER}/

    # Create Player "IPNS Key" (key import)
    ${MY_PATH}/keygen -t ipfs -o ~/.zen/game/players/${PLAYER}/secret.player "$SALT" "$PEPPER"
    ipfs key import ${PLAYER} -f pem-pkcs8-cleartext ~/.zen/game/players/${PLAYER}/secret.player
    ASTRONAUTENS=$(ipfs key import $G1PUB -f pem-pkcs8-cleartext ~/.zen/game/players/${PLAYER}/secret.player)

    mkdir -p ~/.zen/game/players/${PLAYER}/ipfs/G1SSB # Prepare astrXbian sub-datastructure

    qrencode -s 12 -o ~/.zen/game/players/${PLAYER}/QR.png "$G1PUB"
    cp ~/.zen/game/players/${PLAYER}/QR.png ~/.zen/game/players/${PLAYER}/ipfs/QR.png
    echo "$G1PUB" > ~/.zen/game/players/${PLAYER}/ipfs/G1SSB/_g1.pubkey # G1SSB NOTATION (astrXbian compatible)

    qrencode -s 12 -o ~/.zen/game/players/${PLAYER}/QR.ASTRONAUTENS.png "$LIBRA/ipns/${ASTRONAUTENS}"

############################################################################
    ## SEC PASS PROTECTED QRCODE : base58 secret.june / openssl(pass)
    #~ secFromDunikey=$(cat ~/.zen/game/players/${PLAYER}/secret.dunikey | grep "sec" | cut -d ' ' -f2)
    #~ echo "$secFromDunikey" > ~/.zen/tmp/${MOATS}/${PSEUDO}.sec

    ## PGP ENCODING SALT/PEPPER API ACCESS
    echo "${DISCO}" > ~/.zen/tmp/topgp
    cat ~/.zen/tmp/topgp | gpg --symmetric --armor --batch --passphrase "$PASS" -o ~/.zen/tmp/${MOATS}/gpg.${PSEUDO}.asc
    rm ~/.zen/tmp/topgp
    #~ openssl enc -aes-256-cbc -md sha512 -pbkdf2 -iter 100000 -salt -in ~/.zen/game/players/${PLAYER}/secret.june -out "$HOME/.zen/tmp/${MOATS}/enc.${PSEUDO}.sec" -k "$PASS"
    #~ PASsec=$(cat ~/.zen/tmp/${MOATS}/enc.${PSEUDO}.sec  | base64 -w 0 | jq -sRr '@uri' )
    #~ HPass=$(echo "$PASS" | sha512sum | cut -d ' ' -f 1)
    #~ qrencode -s 12 -o $HOME/.zen/game/players/${PLAYER}/QRsec.png $PASsec

    ## Add logo to QRCode
    cp ${MY_PATH}/../images/astrologo_nb.png ~/.zen/tmp/${MOATS}/fond.png

    ## MAKE amzqr WITH astro:// ---- PGP LINK
    amzqr  "$(cat ~/.zen/tmp/${MOATS}/gpg.${PSEUDO}.asc  | tr '-' '~' | tr '\n' '-'  | tr '+' '_' | jq -Rr @uri )" \
                -d ~/.zen/tmp/${MOATS} \
                -l H \
                -p ~/.zen/tmp/${MOATS}/fond.png 1>/dev/null

    ## ADD PLAYER EMAIL
    convert -gravity northwest -pointsize 28 -fill black -draw "text 5,5 \"$PLAYER\"" ~/.zen/tmp/${MOATS}/fond_qrcode.png ~/.zen/game/players/${PLAYER}/result_qrcode.png
    convert ~/.zen/game/players/${PLAYER}/result_qrcode.png -resize 480 ~/.zen/game/players/${PLAYER}/AstroID.png

    ASTROQR="/ipfs/$(ipfs add -q $HOME/.zen/game/players/${PLAYER}/AstroID.png | tail -n 1)"

############################################################################ TW
    ### INITALISATION WIKI dans leurs répertoires de publication IPFS
    ############ TODO améliorer templates, sed, ajouter index.html, etc...
        mkdir -p ~/.zen/game/players/${PLAYER}/ipfs/moa/

        [[ ! -s ~/.zen/tmp/${MOATS}/TW/index.html ]] && cp ${MY_PATH}/../templates/twdefault.html ~/.zen/tmp/${MOATS}/TW/index.html
        sed "s~_BIRTHDATE_~${MOATS}~g" ~/.zen/tmp/${MOATS}/TW/index.html > ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html

        # INSERT ASTROPORT ADRESS
        tiddlywiki --load ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html --output ~/.zen/tmp/${MOATS} --render '.' 'Astroport.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'Astroport'
        ASTROPORT=$(cat ~/.zen/tmp/${MOATS}/Astroport.json | jq -r .[].astroport)
        sed -i "s~$ASTROPORT~/ipns/${IPFSNODEID}~g" ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html

         # TW CHAIN INIT WITH TWMODEL
         sed -i "s~_MOATS_~${MOATS}~g" ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html
         sed -i "s~_CHAIN_~${TWMODEL}~g" ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html

         ## TODO : FOR STRONGER SECURITY REMOVE THIS LINE
         sed -i "s~_PASS_~${PASS}~g" ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html

         ## AND HACK QRCODE.sh FOR _PGP KEY_ TO VERIFY LAST HASH OF PROVIDED PASS
         HPASS=$(echo $PASS | sha512sum | cut -d ' ' -f 1)
         [[ ${HPass} != "" ]] && SRCPASS=${HPass} || SRCPASS="_HPASS_"
         sed -i "s~${SRCPASS}~${HPASS}~g" ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html

        ## RESET WISHES TO DEPLOY DERIVATED KEYS ON HOST AGAIN ( DONE IN PLAYER_REFRESH )
        #~ sed -i "s~G1Voeu~voeu~g" ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html

        ## Fill ♥BOX
         sed -i "s~_URL_~${URL}~g" ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html

        # INSERT PLAYER DATA
        sed -i "s~_PLAYER_~${PLAYER}~g" ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html
        sed -i "s~_PSEUDO_~${PSEUDO}~g" ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html
        sed -i "s~_WISHKEY_~${G1PUB}~g" ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html

        sed -i "s~_G1PUB_~${G1PUB}~g" ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html
        #~ sed -i "s~_QRSEC_~${PASsec}~g" ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html

        ASTRONAUTENS=$(ipfs key list -l | grep -w "${PLAYER}" | cut -d ' ' -f 1)
        # La Clef IPNS porte comme nom G1PUB et ${PLAYER}
        sed -i "s~_MEDIAKEY_~${PLAYER}~g" ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html
        sed -i "s~k2k4r8kxfnknsdf7tpyc46ks2jb3s9uvd3lqtcv9xlq9rsoem7jajd75~${ASTRONAUTENS}~g" ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html

        ## AstroID G1PASS Update
        [[ ! $AstroID ]] && AstroID="/ipfs/bafybeifbebc3ewnzrzbm44arddedbralegnxklhua5d5ymzaqtf2kaub7i"
        sed -i "s~${AstroID}~${ASTROQR}~g" ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html

        sed -i "s~tube.copylaradio.com~$myTUBE~g" ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html
        sed -i "s~ipfs.copylaradio.com~$myTUBE~g" ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html

        ## Change myIP
        #~ sed -i "s~127.0.0.1~$myIP~g" ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html # 8080 & 5001 BEING THE RECORDING GATEWAY (WAN or ipfs.localhost)

###########
        ## GET OLD16
        tiddlywiki --load ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html --output ~/.zen/tmp/${MOATS} --render '.' 'MIZ.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'MadeInZion'
        OLD16=$(cat ~/.zen/tmp/${MOATS}/MIZ.json | jq -r ".[].secret")
        [[ ${OLD16} == "" || ${OLD16} == "null" ]] && OLD16="_SECRET_"

        ## USING  SWARMKEY (derivated from IPFSNODE "/proc/cpuinfo" key made by _12345.sh)  ## HARDWARE SPECIFIC KEY ##
        # TODO : NODE COULD FORGET PASS THEN DECODE  ${PLAYER}/secret.dunikey FROM TW # PROD #
        MACHINEPUB=$(cat $HOME/.zen/game/secret.dunikey | grep pub | cut -d ' ' -f 2)
        echo "# CRYPTO ENCODING  _SECRET_ "
        ${MY_PATH}/natools.py encrypt -p ${MACHINEPUB} -i $HOME/.zen/game/players/${PLAYER}/secret.dunikey -o $HOME/.zen/tmp/${MOATS}/secret.dunikey.$G1PUB.enc
        ENCODING=$(cat ~/.zen/tmp/${MOATS}/secret.dunikey.$G1PUB.enc | base16)
        sed -i "s~${OLD16}~${ENCODING}~g" ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html
        # echo "${ENCODING}"
###########
        echo "# CRYPTO DECODING TESTING..."
        tiddlywiki --load ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html --output ~/.zen/tmp/${MOATS} --render '.' 'MadeInZion.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'MadeInZion'
        cat ~/.zen/tmp/${MOATS}/MadeInZion.json | jq -r ".[].secret" | base16 -d > ~/.zen/tmp/${MOATS}/crypto.$G1PUB.enc.2
        ${MY_PATH}/natools.py decrypt -f pubsec -k $HOME/.zen/game/secret.dunikey -i $HOME/.zen/tmp/${MOATS}/crypto.$G1PUB.enc.2 -o $HOME/.zen/tmp/${MOATS}/crypto.2
        #~ echo "DEBUG : $(cat $HOME/.zen/tmp/${MOATS}/crypto.2)"
###########
        ## CRYPTO PROCESS VALIDATED
        [[ -s ~/.zen/tmp/${MOATS}/crypto.2 ]] && echo "NATOOLS LOADED" \
                                                        || echo "NATOOLS ERRORS - CHECK STATION" # MACHINEPUB CRYPTO ERROR

###########

    ### CREATE $NID ADDRESS FOR API & ROUND ROBIN FOR GW
    cat ${MY_PATH}/../templates/data/local.api.json | sed "s~_NID_~${WID}~g" > ~/.zen/tmp/${MOATS}/local.api.json
    cat ${MY_PATH}/../templates/data/local.gw.json | sed "s~_NID_~${NID}~g" > ~/.zen/tmp/${MOATS}/local.gw.json

    # Create"${PLAYER}_feed" Key ! DERIVATED !
    ${MY_PATH}/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/feed.ipfskey "$SALT" "$G1PUB"
    ipfs key import "${PLAYER}_feed" -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/feed.ipfskey
    FEEDNS=$(ipfs key list -l | grep -w "${PLAYER}_feed" | cut -d ' ' -f 1 )

    ## MAKE LightBeam Plugin Tiddler ${PLAYER}_feed
    # $:/plugins/astroport/lightbeams/saver/ipns/lightbeam-key
    echo '[{"title":"$:/plugins/astroport/lightbeams/saver/ipns/lightbeam-name","text":"'${PLAYER}_feed'","tags":""}]' > ~/.zen/tmp/${MOATS}/lightbeam-name.json
    echo '[{"title":"$:/plugins/astroport/lightbeams/saver/ipns/lightbeam-key","text":"'${FEEDNS}'","tags":""}]' > ~/.zen/tmp/${MOATS}/lightbeam-key.json

    ## NATOOLS ENCRYPT
    echo "# NATOOLS ENCODING  feed.ipfskey "
    ${MY_PATH}/../tools/natools.py encrypt -p $G1PUB -i $HOME/.zen/tmp/${MOATS}/feed.ipfskey -o $HOME/.zen/tmp/${MOATS}/feed.ipfskey.$G1PUB.enc
    ENCODING=$(cat $HOME/.zen/tmp/${MOATS}/feed.ipfskey.$G1PUB.enc | base16)
    echo ${ENCODING}
    echo '[{"title":"$:/plugins/astroport/lightbeams/saver/g1/lightbeam-natools-feed","text":"'${ENCODING}'","tags":""}]' > ~/.zen/tmp/${MOATS}/lightbeam-natools.json

    echo "TW IPFS GATEWAY : $NID"
    # cat ~/.zen/tmp/${MOATS}/local.gw.json | jq -r
    echo "TW IPFS API : $WID"
    # cat ~/.zen/tmp/${MOATS}/local.api.json | jq -r

    ## CHANGE SELECTED GW & API

        ## ADD SYSTEM TW
        tiddlywiki  --load ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html \
                            --import ~/.zen/tmp/${MOATS}/lightbeam-name.json "application/json" \
                            --import ~/.zen/tmp/${MOATS}/lightbeam-key.json "application/json" \
                            --import ~/.zen/tmp/${MOATS}/lightbeam-natools.json "application/json" \
                            --import ~/.zen/tmp/${MOATS}/local.api.json "application/json" \
                            --import ~/.zen/tmp/${MOATS}/local.gw.json "application/json" \
    --import "${MY_PATH}/../templates/tw/\$ _ipfs_saver_api.json" "application/json" \
    --import "${MY_PATH}/../templates/tw/\$ _ipfs_saver_gateway.json" "application/json" \
                            --output ~/.zen/tmp/${MOATS} --render "$:/core/save/all" "tw.html" "text/plain"

        [[ -s ~/.zen/tmp/${MOATS}/tw.html ]] \
        && cp -f ~/.zen/tmp/${MOATS}/tw.html ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html \
        && echo "TW INDEX OK" \
        || ( echo "Problem with TW - EXIT" && exit 1 )

############################################################################ TW

        ## MAKE IMAGE AVATAR WITH G1PUB QRCODE
        if [[ $(which amzqr) ]]; then

            GIMG="${MY_PATH}/../images/moa_net.png"
            CIMG="${MY_PATH}/../images/g1ticket.png"

            # QRG1avatar.png
            [[ ! -s ~/.zen/game/players/${PLAYER}/QRG1avatar.png ]] && amzqr ${G1PUB} -l H -p "$CIMG" -c -n QRG1avatar.png -d ~/.zen/game/players/${PLAYER}/ 1>/dev/null
            # QRTWavatar.png
            [[ ! -s ~/.zen/game/players/${PLAYER}/QRTWavatar.png ]] && amzqr ${myIPFSGW}/ipns/$ASTRONAUTENS -l H -p "$GIMG" -c -n QRTWavatar.png -d ~/.zen/game/players/${PLAYER}/ 1>/dev/null

        else

            [[ ! -s ~/.zen/game/players/${PLAYER}/QRG1avatar.png ]] \
            && cp ~/.zen/game/players/${PLAYER}/QR.png ~/.zen/game/players/${PLAYER}/QRG1avatar.png

            [[ ! -s ~/.zen/game/players/${PLAYER}/QRTWavatar.png ]] \
            && cp ~/.zen/game/players/${PLAYER}/QR.ASTRONAUTENS.png ~/.zen/game/players/${PLAYER}/QRTWavatar.png

        fi

        ## ID CARD & QRCODE
        convert ~/.zen/game/players/${PLAYER}/QRG1avatar.png -resize 300 ~/.zen/tmp/${MOATS}/QR.png
        convert ~/.zen/game/players/${PLAYER}/QRTWavatar.png -resize 240 ~/.zen/tmp/${MOATS}/TW.png
        convert ${MY_PATH}/../images/astroport.jpg  -resize 240 ~/.zen/tmp/${MOATS}/ASTROPORT.png


        composite -compose Over -gravity SouthEast -geometry +5+5 ~/.zen/tmp/${MOATS}/ASTROPORT.png ${MY_PATH}/../images/Brother_600x400.png ~/.zen/tmp/${MOATS}/astroport.png
        composite -compose Over -gravity NorthEast -geometry +10+55 ~/.zen/tmp/${MOATS}/TW.png ~/.zen/tmp/${MOATS}/astroport.png ~/.zen/tmp/${MOATS}/astroport2.png
        composite -compose Over -gravity NorthWest -geometry +0+0 ~/.zen/tmp/${MOATS}/QR.png ~/.zen/tmp/${MOATS}/astroport2.png ~/.zen/tmp/${MOATS}/one.png
        convert -gravity SouthWest -pointsize 12 -fill black -draw "text 5,3 \"$G1PUB\"" ~/.zen/tmp/${MOATS}/one.png ~/.zen/tmp/${MOATS}/txt.png

        # composite -compose Over -gravity NorthWest -geometry +280+280 ~/.zen/game/players/.current/QRsec.png ~/.zen/tmp/${MOATS}/one.png ~/.zen/tmp/${MOATS}/image.png

        convert -gravity northwest -pointsize 25 -fill black -draw "text 50,300 \"$PSEUDO\"" ~/.zen/tmp/${MOATS}/txt.png ~/.zen/tmp/${MOATS}/image.png
        convert -gravity northwest -pointsize 20 -fill black -draw "text 300,40 \"${PLAYER}\"" ~/.zen/tmp/${MOATS}/image.png ~/.zen/tmp/${MOATS}/pseudo.png


        ## WITH CONFIDENTIAL (LOCAL PRINT)
        convert -gravity northeast -pointsize 25 -fill black -draw "text 20,180 \"$PASS\"" ~/.zen/tmp/${MOATS}/pseudo.png ~/.zen/tmp/${MOATS}/pass.png
        convert -gravity northwest -pointsize 25 -fill black -draw "text 300,100 \"$SALT\"" ~/.zen/tmp/${MOATS}/pass.png ~/.zen/tmp/${MOATS}/salt.png
        convert -gravity northwest -pointsize 25 -fill black -draw "text 300,140 \"$PEPPER\"" ~/.zen/tmp/${MOATS}/salt.png ~/.zen/game/players/${PLAYER}/ID.png

        # INSERTED IMAGE IPFS
        # IASTRO=$(ipfs add -Hq ~/.zen/game/players/${PLAYER}/ID.png | tail -n 1) ## G1VISA PUBLIC / PRIVATE
        IASTRO="/ipfs/$(ipfs add -Hq ~/.zen/tmp/${MOATS}/pseudo.png | tail -n 1)" ## G1VISA PUBLIC ONLY

        ## Update G1Visa
        [[ ! $G1Visa ]] && G1Visa="/ipfs/bafybeidhghlcx3zdzdah2pzddhoicywmydintj4mosgtygr6f2dlfwmg7a"
        sed -i "s~${G1Visa}~${IASTRO}~g" ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html

    echo
    echo "♥ IPFS Ŋ1 DRIVE INIT ♥"
    echo "TW /ipns/${ASTRONAUTENS}/"
    IPUSH=$(ipfs add -Hq ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html | tail -n 1)
    echo $IPUSH > ~/.zen/game/players/${PLAYER}/ipfs/moa/.chain # Contains last IPFS backup PLAYER KEY
    echo $MOATS > ~/.zen/game/players/${PLAYER}/ipfs/moa/.moats

    (
        #~ echo "$MOATS :: /ipfs/$IPUSH"
        ipfs name publish --key=${PLAYER} /ipfs/$IPUSH
        #~ echo "TW PUBLISHING DONE"
    ) &

    ## MEMORISE PLAYER Ŋ1 ZONE
    echo "${PLAYER}" > ~/.zen/game/players/${PLAYER}/.player
    echo "$PSEUDO" > ~/.zen/game/players/${PLAYER}/.pseudo
    echo "$G1PUB" > ~/.zen/game/players/${PLAYER}/.g1pub

    echo "${ASTRONAUTENS}" > ~/.zen/game/players/${PLAYER}/.playerns

    echo "SALT=\"$SALT\"" > ~/.zen/game/players/${PLAYER}/secret.june
    echo "PEPPER=\"$PEPPER\"" >> ~/.zen/game/players/${PLAYER}/secret.june

echo; echo "Création Clefs et QR codes pour accès au niveau Astroport Ŋ1"; sleep 1

echo "--- PLAYER : ${PLAYER} - FILE SYSTEM LOADED";
# ls ~/.zen/game/players/${PLAYER}

[[ $XDG_SESSION_TYPE == 'x11' ]] && xdg-open "${myIPFS}/ipns/${ASTRONAUTENS}" && espeak "YOUR PASS IS $PASS"

################# PREPARE DOCKERIZATION
rm ~/.zen/game/players/.current
ln -s ~/.zen/game/players/${PLAYER} ~/.zen/game/players/.current
. "${MY_PATH}/my.sh"

#################################################################
#### make player ipfs docker ## TODO
# [[ $USER == 'zen' ]] && make player MAIL=$(myPlayer) USER_HOST=$(myPlayerHost) > /dev/null 2>&1
## 1ST RELEASE BASED ON DIRECT NODE IPFSNODEID KEY "ADD / DEL" API
#################################################################

#################################################
# !! TODO !! # DEMO MODE. REMOVE FOR PRODUCTION - RECALCULATE AND RENEW AFTER EACH NEW KEY DELEGATION
echo "$PASS" > ~/.zen/game/players/${PLAYER}/.pass
# ~/.zen/game/players/${PLAYER}/secret.june SECURITY TODO
# Astronaut QRCode + PASS = LOGIN (=> DECRYPTING CRYPTO IPFS INDEX)
# TODO : Allow Astronaut PASS change ;)
#####################################################

## DISCONNECT AND CONNECT CURRENT PLAYER
#~ rm -f ~/.zen/game/players/.current
#~ ln -s ~/.zen/game/players/${PLAYER} ~/.zen/game/players/.current

## MANAGE GCHANGE+ & Ŋ1 EXPLORATION
${MY_PATH}/Connect_PLAYER_To_Gchange.sh "${PLAYER}"

### IF PRINTER -> PRINT VISA
LP=$(ls /dev/usb/lp* 2>/dev/null)
[[ $LP ]] && ${MY_PATH}/VISA.print.sh "${PLAYER}" &

## INIT FRIENDSHIP CAPTAIN/ASTRONAUTS (LATER THROUGH GCHANGE)
## ${MY_PATH}/FRIENDS.init.sh
## NO. GCHANGE+ IS THE MAIN INTERFACE, astrXbian manage
echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
echo "$(${MY_PATH}/face.sh cool)"
echo " 'Astronaute'  $PSEUDO"
echo
echo "G1VISA : ${myIPFS}${IASTRO}"
echo "AstroID : ${myIPFS}${ASTROQR}  (${PASS})"
echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
echo "${PLAYER}"
echo "https://monnaie-libre.fr (ğ1) : $G1PUB"; sleep 1
echo "G1CopierYoutube : $URL"
echo "
Secret :
    $SALT
    $PEPPER

https://Cesium.app <wallet::market> https://GChange.fr
People ★ PKI ★ Ğ1/Ŋ1 ★ Nation ★ Libre"; sleep 1
echo
echo "Explorateur Web3. Batisseur de(s) Toile(s) de Confiance(s).
BIENVENUE
"
echo "G1FRAME : ${myIPFS}/ipns/${FEEDNS}"
echo "TW : ${myIPFS}/ipns/${ASTRONAUTENS}"
echo echo
echo "$(${MY_PATH}/face.sh friendly)
#~ DISCONNECT : $DISCO&logout=${PLAYER}
#~ CONNECT : $DISCO&login=${PLAYER}"

echo $PSEUDO > ~/.zen/tmp/PSEUDO ## Return data to start.sh
echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
echo "--- web3 PKI system ---"
echo "export ASTROTW=/ipns/$ASTRONAUTENS ASTROG1=$G1PUB ASTROMAIL=$PLAYER ASTROFEED=$FEEDNS"

## CLEANING CACHE
rm -Rf ~/.zen/tmp/${MOATS}

exit 0
