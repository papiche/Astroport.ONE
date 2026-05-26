#!/bin/bash
########################################################################
# Version: 1.0
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
# PAD COCODING : https://pad.p2p.legal/s/G1PalPay
# This script monitors G1 Blockchain
########################################################################
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

. "${MY_PATH}/../tools/my.sh"

CESIUM=${myCESIUM}
GCHANGE=${myGCHANGE}

echo "$ME RUNNING (•‿‿•)"
CURRENT=$(readlink ~/.zen/game/players/.current | rev | cut -d '/' -f 1 | rev)
########################################################################
# PALPAY SERVICE : MONITOR INCOMING TX & NEW TIDDLERS
########################################################################
########################################################################
INDEX="$1"  ## TW file
[[ ! ${INDEX} ]] && INDEX="$HOME/.zen/game/players/.current/ipfs/moa/index.html"
[[ ! -s ${INDEX} ]] && echo "ERROR - Please provide path to source TW index.html" && exit 1
[[ ! -s ${INDEX} ]] && echo "ERROR - Fichier TW absent. ${INDEX}" && exit 1

PLAYER="$2" ## PLAYER
[[ ! ${PLAYER} ]] && PLAYER="$(cat ~/.zen/game/players/.current/.player 2>/dev/null)"
[[ ! ${PLAYER} ]] && echo "ERROR - Please provide PLAYER" && exit 1

ASTRONAUTENS=$(ipfs key list -l | grep -w ${PLAYER} | head -n1 | cut -d ' ' -f1) ## TW /ipns/
[[ ! ${ASTRONAUTENS} ]] && echo "ERROR - Clef IPNS ${PLAYER} introuvable!"  && exit 1

G1PUB=$(cat ~/.zen/game/players/${PLAYER}/.g1pub) ## PLAYER WALLET
[[ ! $G1PUB ]] && echo "ERROR - G1PUB ${PLAYER} VIDE"  && exit 1

# Extract tag=tube from TW
MOATS="$3"
[[ ! ${MOATS} ]] && MOATS=$(date -u +"%Y%m%d%H%M%S%4N")

###################################################################
## CREATE APP NODE PLAYER PUBLICATION DIRECTORY
###################################################################
mkdir -p $HOME/.zen/game/players/${PLAYER}/G1PalPay/
mkdir -p $HOME/.zen/tmp/${MOATS}
echo "=====(•‿‿•)====== ( ◕‿◕) (◕‿◕ ) =======(•‿‿•)======= ${PLAYER}
${INDEX}"
echo "(✜‿‿✜) G1PalPay : CHECK LAST 30 TX comment"

# CHECK LAST 30 TRANSACTIONS (via GraphQL squid)
${MY_PATH}/../tools/G1history.sh ${G1PUB} 30 \
    > $HOME/.zen/game/players/${PLAYER}/G1PalPay/${PLAYER}.duniter.history.json

[[ ! -s $HOME/.zen/game/players/${PLAYER}/G1PalPay/${PLAYER}.duniter.history.json ]] \
&& echo "NO PAYMENT HISTORY.........................."
########################################################
## CONVERT TO INLINE JSON | jq -rc '.history[] // empty'
## G1history.sh retourne {"history":[{Date, Amounts Ğ1, Issuers/Recipients, Reference, ...}]}
cat $HOME/.zen/game/players/${PLAYER}/G1PalPay/${PLAYER}.duniter.history.json | jq -rc '.history[] // empty' \
    > $HOME/.zen/game/players/${PLAYER}/G1PalPay/${PLAYER}.history.json

########################################################################################
echo "## CONTROL WALLET PRIMAL RX"
########################################################################################
echo "CONTROL UPLANET ZEN - ZenCard primal control"

# For ZenCard wallets, use UPLANETNAME_G1 as unique primal source (unified architecture)
${MY_PATH}/../tools/primal_wallet_control.sh \
    "${HOME}/.zen/game/players/${PLAYER}/secret.dunikey" \
    "${G1PUB}" \
    "${UPLANETNAME_G1}" \
    "${PLAYER}"

##########################################################
echo "############# CHECK FOR N1COMMANDs IN PAYMENT COMMENT"
#################################################################
# LOG / cat $HOME/.zen/game/players/${PLAYER}/G1PalPay/${PLAYER}.duniter.history.json  | jq -rc .[]
## TREAT ANY COMMENT STARTING WITH N1: exemple : N1Kodi.sh
## EXTRACT /ASTROBOT/N1ProgramNames
ls ${MY_PATH}/../ASTROBOT/ | grep "N1" | cut -d "." -f 1 > ~/.zen/tmp/${MOATS}/N1PROG
while read prog; do
    echo "# SCAN FOR N1 COMMAND : $prog"
    cat $HOME/.zen/game/players/${PLAYER}/G1PalPay/${PLAYER}.duniter.history.json | jq -rc '.history[] // empty' | grep "$prog" >> ~/.zen/tmp/${MOATS}/myN1.json
done < ~/.zen/tmp/${MOATS}/N1PROG

# got N1 incoming TX
while read NLINE; do
    ## COMMENT FORMAT = N1$CMD:$TH:$TRAIL
    ## Champs G1history.sh : Date, "Amounts Ğ1", "Issuers/Recipients", Reference, blockNumber, direction
    TXIDATE=$(echo ${NLINE} | jq -r '.Date // .date // ""')
    TXIPUBKEY=$(echo ${NLINE} | jq -r '."Issuers/Recipients" // .pubkey // ""')
    TXIAMOUNT=$(echo $NLINE | jq -r '."Amounts Ğ1" // .amount // "0"')
    COMMENT=$(echo ${NLINE} | jq -r '.Reference // .comment // ""')
    CMD=$(echo ${COMMENT} | cut -d ':' -f 1 | cut -c -12 ) # Maximum 12 characters CMD

    # Verify last recorded acting date (avoid running twice)
    [[ $(cat ~/.zen/game/players/${PLAYER}/.ndate) -ge $TXIDATE ]]  \
        && echo "$CMD $TXIDATE from ${TXIPUBKEY} ALREADY TREATED - continue" \
        && continue

    TH=$(echo ${COMMENT} | cut -d ':' -f 2)
    TRAIL=$(echo ${COMMENT} | cut -d ':' -f 3-)

    if [[ -s ${MY_PATH}/../ASTROBOT/${CMD}.sh ]]; then

        echo "RECEIVED CMD=${CMD} from ${TXIPUBKEY}"
        ${MY_PATH}/../ASTROBOT/${CMD}.sh ${INDEX} ${PLAYER} ${MOATS} ${TXIPUBKEY} ${TH} ${TRAIL} ${TXIAMOUNT}
        ## WELL DONE .
        [[ $? == 0 ]] \
            && echo "${CMD} DONE" \
            && echo "$TXIDATE" > ~/.zen/game/players/${PLAYER}/.ndate ## MEMORIZE LAST TXIDATE

    else

        echo "NOT A N1 COMMAND ${COMMENT}"

    fi

done < ~/.zen/tmp/${MOATS}/myN1.json

########################################################################################
echo "# CHECK FOR EMAILs IN PAYMENT COMMENT"
## DEBUG ## cat $HOME/.zen/game/players/${PLAYER}/G1PalPay/${PLAYER}.duniter.history.json | jq -r
#################################################################
cat $HOME/.zen/game/players/${PLAYER}/G1PalPay/${PLAYER}.duniter.history.json | jq -rc '.history[] // empty' | grep '@' \
    > ~/.zen/tmp/${MOATS}/myPalPay.json

# IF COMMENT CONTAINS EMAIL ADDRESSES
# SPREAD & TRANSFER AMOUNT TO NEXT (REMOVING IT FROM LIST)...
## Other G1PalPay will continue the transmission...
########################################################################
## GET @ in JSON INLINE
while read LINE; do

    JSON=${LINE}
    ## Champs G1history.sh : Date, "Amounts Ğ1", "Issuers/Recipients", Reference, blockNumber, direction
    TXIDATE=$(echo $JSON | jq -r '.Date // .date // ""')
    TXIPUBKEY=$(echo $JSON | jq -r '."Issuers/Recipients" // .pubkey // ""')
    TXIAMOUNT=$(echo $JSON | jq -r '."Amounts Ğ1" // .amount // "0"')
    TXIAMOUNTUD=$(echo $JSON | jq -r '."Amounts Ğ1" // .amountUD // "0"')
    COMMENT=$(echo $JSON | jq -r '.Reference // .comment // ""')

    lastTXdate=$(cat ~/.zen/game/players/${PLAYER}/.atdate 2>/dev/null)
    [[ -z "$lastTXdate" ]] && lastTXdate=0 && echo "0" > ~/.zen/game/players/${PLAYER}/.atdate
    [[ $(cat ~/.zen/game/players/${PLAYER}/.atdate) -ge $TXIDATE ]]  \
        && echo "PalPay $TXIDATE from ${TXIPUBKEY} ALREADY TREATED - continue" \
        && continue

    ## GET EMAILS FROM COMMENT
    TXIMAILS=($(echo "$COMMENT" | grep -E -o "\b[a-zA-Z0-9.%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,6}\b"))

    [[ $(echo "$TXIAMOUNT < 0" | bc) -eq 1 ]] \
        && echo "TX-OUT :: ${LINE}" \
        && echo "$TXIDATE" > ~/.zen/game/players/${PLAYER}/.atdate \
        && continue

    ### MATCHING NEW RX-IN
    echo "${LINE}"
    ## DIVIDE INCOMING AMOUNT TO SHARE
    echo "N=${#TXIMAILS[@]}"
    N=${#TXIMAILS[@]}

    SHAREE=$(echo "scale=2; $TXIAMOUNT / $N" | bc)
    SHARE=$(makecoord ${SHAREE})
    ## SHARE is received AMOUT divided by numbers of EMAILS in comment
    echo "% ${#TXIMAILS[@]} % $SHARE % $TXIDATE ${TXIPUBKEY} $TXIAMOUNT [$TXIAMOUNTUD] $TXIMAILS"

    # let's loop over TXIMAILS
    for EMAIL in "${TXIMAILS[@]}"; do

        [[ ${EMAIL} == $PLAYER ]] \
            && echo "ME MYSELF" \
            && echo "$TXIDATE" > ~/.zen/game/players/${PLAYER}/.atdate \
            && continue

        echo "EMAIL : ${EMAIL}"

        ASTROTW="" STAMP="" ASTROG1="" ASTROIPFS="" ASTROFEED="" # RESET VAR
        $($MY_PATH/../tools/search_for_this_email_in_players.sh ${EMAIL} | tail -n 1) ## export ASTROTW and more
        [[ ${ASTROTW} == "" ]] && ASTROTW=${ASTRONAUTENS}
        echo "export ASTROPORT=${ASTROPORT} ASTROTW=${ASTROTW} ASTROG1=${ASTROG1} ASTROMAIL=${EMAIL} ASTROFEED=${FEEDNS}"

        if [[ ! ${ASTROTW} ]]; then

            echo "# PLAYER ${EMAIL} INCONNU $(date)"
            continue

        fi

        if [[ ! ${ASTROG1} ]]; then
            cat > ~/.zen/tmp/palpay.bro <<'PALHTML'
<!DOCTYPE html><html lang="fr"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<style>body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;margin:0;padding:0;background:#e8f5e9}
.c{max-width:600px;margin:0 auto;background:#fff}
.h{background:linear-gradient(135deg,#1b5e20,#43a047);color:#fff;padding:1.5rem;text-align:center}
.lbl{font-size:.75rem;opacity:.85;letter-spacing:2px;text-transform:uppercase;margin-bottom:.3rem}
h1{margin:0;font-size:1.3rem}
.b{padding:1.5rem}.box{background:#e8f5e9;border-left:4px solid #43a047;padding:1rem;border-radius:6px;margin:.75rem 0}
p{line-height:1.6;margin:.4rem 0;font-size:.92rem}
.btn{display:inline-block;background:#2e7d32;color:#fff;padding:12px 24px;border-radius:6px;text-decoration:none;font-weight:700;margin:.5rem 0}
small{color:#666;font-size:.8rem}</style></head><body><div class="c">
<div class="h"><div class="lbl">(♥‿‿♥) Invitation PalPay</div>
<h1>BRO — _PLAYER_ vous envoie _SHARE_ Ğ1</h1></div>
<div class="b"><div class="box">
<p><strong>_PLAYER_</strong> souhaite vous envoyer <strong>_SHARE_ Ğ1</strong> via UPlanet.</p>
<p>Pour recevoir ce paiement, créez votre MULTIPASS UPlanet avec <strong>exactement cet email</strong>.</p>
</div>
<p style="text-align:center;margin-top:1rem"><a href="https://qo-op.com" class="btn" target="_blank">Rejoindre UPlanet →</a></p>
<p style="text-align:center;margin-top:1.5rem"><small>UPlanet / G1FabLab — support@qo-op.com</small></p>
</div></div></body></html>
PALHTML
            sed -i "s~_PLAYER_~${PLAYER}~g; s~_SHARE_~${SHARE}~g" ~/.zen/tmp/palpay.bro
            ${MY_PATH}/../tools/mailjet.sh --template "$0" --expire 48h "${EMAIL}" ~/.zen/tmp/palpay.bro "BRO. ${PLAYER} vous invite sur UPlanet"
            continue
        fi

        sleep 3

        ## SEND G1
        echo "PalPay_____ SENDING ${SHARE} G1 to $ASTROMAIL
        TW : $ASTROTW
        G1 : ${ASTROG1}"

        echo PAYforSURE.sh "${HOME}/.zen/game/players/${PLAYER}/secret.dunikey" "${SHARE}" "${ASTROG1}" "UPLANET:${UPLANETG1PUB:0:8}:PALPAY:${PLAYER}"
        ${MY_PATH}/../tools/PAYforSURE.sh "${HOME}/.zen/game/players/${PLAYER}/secret.dunikey" "${SHARE}" "${ASTROG1}" "UPLANET:${UPLANETG1PUB:0:8}:PALPAY:${PLAYER}" 2>/dev/null
        STAMP=$?
        ## DONE STAMP IT
        [[ $STAMP == 0 ]] \
        && echo "REDISTRIBUTION DONE" \
        && echo "$TXIDATE" > ~/.zen/game/players/${PLAYER}/.atdate

    done


done < ~/.zen/tmp/${MOATS}/myPalPay.json

echo "====(•‿‿•)======= %%%%% (°▃▃°) %%%%%%% ======(•‿‿•)========"

########################################################################################
## SEARCH FOR TODAY MODIFIED TIDDLERS WITH MULTIPLE EMAILS IN TAG
#  This can could happen in case Tiddler is copied OR PLAYER manualy adds an email tag to Tiddler to share with someone...
#################################################################
echo "# EXTRACT [days[-1]] DAYS TIDDLERS"
tiddlywiki --load ${INDEX} \
     --output ~/.zen/tmp/${MOATS} \
     --render '.' "today.${PLAYER}.tiddlers.json" 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[days[-1]]'

# cat ~/.zen/tmp/${MOATS}/today.${PLAYER}.tiddlers.json | jq -rc  # LOG

## FILTER MY OWN EMAIL
cat ~/.zen/tmp/${MOATS}/today.${PLAYER}.tiddlers.json \
        | sed "s~${PLAYER}~ ~g" | jq -rc '.[] | select(.tags | contains("@"))' \
         > ~/.zen/tmp/${MOATS}/@tags.json 2>/dev/null ## Get tiddlers with not my email in it

[[ ! -s ~/.zen/tmp/${MOATS}/@tags.json ]] \
    && echo "NO EXTRA @tags.json TIDDLERS TODAY"

# LOG
cat ~/.zen/tmp/${MOATS}/@tags.json
echo "******************TIDDLERS with new EMAIL in TAGS treatment"

################################
## detect NOT MY EMAIL in TODAY TIDDLERS
################################
while read LINE; do

    echo "---------------------------------- Sava PalPé mec"
    echo "${LINE}"
    echo "---------------------------------- PalPAY for Tiddler"
    TCREATED=$(echo ${LINE} | jq -r .created)
    TTITLE=$(echo ${LINE} | jq -r .title)
    TTAGS=$(echo ${LINE} | jq -r .tags)

    ## Extract "/ipfs/CID" from Tiddler - to pin TOPIN -
    TOPIN=$(echo ${LINE} | jq -r .ipfs) ## Tiddler produced by "Astroport Desktop"
    [[ ! $(echo ${TOPIN} | grep '/ipfs') ]] && TOPIN=$(echo ${LINE} | jq -r ._canonical_uri) ## Tiddler is exported to IPFS
    [[ ! $(echo ${TOPIN} | grep '/ipfs') ]] && TOPIN=$(echo ${LINE} | jq -r '.text | match("/ipfs/[^\"\\s]+") | .string | first') ## Ket first /ipfs/ link from text field
    [[ ! $(echo ${TOPIN} | grep '/ipfs') ]] && echo "NOT COMPATIBLE ${TOPIN}" && TOPIN=""

    echo "$TTITLE"

    ## Count extra emails found
    emails=($(echo "$TTAGS" | sed "s~${PLAYER}~ ~g" | grep -E -o "\b[a-zA-Z0-9.%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,6}\b"))
    nb=${#emails[@]}
    #~ zen=$(echo "scale=2; $nb / 10" | bc) ## / divide by 10 = 1 ZEN each

    ## Get first zmail
    ZMAIL="${emails[0]}"

    MSG=">>> $nb G1 to ${emails[@]} <<<"
    echo $MSG

    ASTROTW="" STAMP="" ASTROG1="" ASTROIPFS="" ASTROFEED=""
    #### SEARCH FOR PALPAY ACOUNTS : USING PALPAY RELAY - COULD BE DONE BY A LOOP ?? §§§
    $($MY_PATH/../tools/search_for_this_email_in_players.sh ${ZMAIL} | tail -n 1) ## export ASTROTW and more
    echo "export ASTROPORT=${ASTROPORT} ASTROTW=${ASTROTW} ASTROG1=${ASTROG1} ASTROMAIL=${EMAIL} ASTROFEED=${FEEDNS}"
    [[ ${ASTROTW} == "" ]] && ASTROTW="/ipns/${ASTRONAUTENS}"

    echo "TOPIN=${TOPIN}"
    if [[ ${TOPIN} && ${ASTROG1} && ${ASTROG1} != ${G1PUB} ]]; then

        ##############################
        ### GET PAID & GET PINNED !!
        ##############################
        ZZMAIL=$(echo "${emails[@]}" | sed "s~${ZMAIL}~~g") # remove ZMAIL from ${emails[@]} list
        ${MY_PATH}/../tools/PAYforSURE.sh "${HOME}/.zen/game/players/${PLAYER}/secret.dunikey" "${nb}" "${ASTROG1}" "UPLANET:${UPLANETG1PUB:0:8}:PIN:${TOPIN}:${PLAYER}" 2>/dev/null

        ## PINNING IPFS MEDIA - PROOF OF COPY SYSTEM -
        [[ ! -z $TOPIN ]] && ipfs pin add $TOPIN
        cat > ~/.zen/tmp/${MOATS}/g1message <<PINHTML
<!DOCTYPE html><html lang="fr"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<style>body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;margin:0;padding:0;background:#e3f2fd}
.c{max-width:600px;margin:0 auto;background:#fff}
.h{background:linear-gradient(135deg,#0d47a1,#1565c0);color:#fff;padding:1.5rem;text-align:center}
.lbl{font-size:.75rem;opacity:.85;letter-spacing:2px;text-transform:uppercase;margin-bottom:.3rem}
h1{margin:0;font-size:1.3rem}h2{font-size:1rem;margin:.75rem 0 .3rem}
.b{padding:1.5rem}.box{padding:1rem;border-radius:6px;margin:.75rem 0}
.blue{background:#e3f2fd;border-left:4px solid #1565c0}.green{background:#e8f5e9;border-left:4px solid #43a047}
p{line-height:1.6;margin:.4rem 0;font-size:.92rem}a{color:#1565c0}
.btn{display:inline-block;background:#1565c0;color:#fff;padding:12px 24px;border-radius:6px;text-decoration:none;font-weight:700;margin:.5rem 0}
small{color:#666;font-size:.8rem}</style></head><body><div class="c">
<div class="h"><div class="lbl">(☼‿‿☼) PIN confirmé</div>
<h1>BRO — ${PLAYER} : $MSG</h1></div>
<div class="b">
<div class="box blue">
<h2>Tiddler partagé</h2>
<p><a href="${myIPFSGW}${ASTROTW}#${TTITLE}">${TTITLE}</a></p>
<p>Destinataires : ${emails[@]}</p>
</div>
$([ ! -z "$TOPIN" ] && echo '<div class="box green"><h2>IPFS PIN</h2><p><a href="'"${myIPFSGW}${TOPIN}"'">'"$TOPIN"'</a></p></div>')
<p style="text-align:center;margin-top:1.5rem"><small>UPlanet / G1FabLab — support@qo-op.com</small></p>
</div></div></body></html>
PINHTML

        ${MY_PATH}/../tools/mailjet.sh --template "$0" --expire 48h "${PLAYER}" ~/.zen/tmp/${MOATS}/g1message "BRO. ${ZMAIL} — PIN TW5 confirmé"

    else
        ## ${ZMAIL} NOT A PLAYER YET
        ## SEND MESSAGE TO INFORM ${ZMAIL} OF THIS EXISTING TIDDLER
        cat > ~/.zen/tmp/palpay.bro <<INVHTML
<!DOCTYPE html><html lang="fr"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<style>body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;margin:0;padding:0;background:#f3e5f5}
.c{max-width:600px;margin:0 auto;background:#fff}
.h{background:linear-gradient(135deg,#4a148c,#7b1fa2);color:#fff;padding:1.5rem;text-align:center}
.lbl{font-size:.75rem;opacity:.85;letter-spacing:2px;text-transform:uppercase;margin-bottom:.3rem}
h1{margin:0;font-size:1.3rem}
.b{padding:1.5rem}.box{background:#f3e5f5;border-left:4px solid #7b1fa2;padding:1rem;border-radius:6px;margin:.75rem 0}
p{line-height:1.6;margin:.4rem 0;font-size:.92rem}a{color:#4a148c}
.btn{display:inline-block;background:#6a1b9a;color:#fff;padding:12px 24px;border-radius:6px;text-decoration:none;font-weight:700;margin:.5rem 0}
small{color:#666;font-size:.8rem}</style></head><body><div class="c">
<div class="h"><div class="lbl">(✜‿‿✜) Tiddler partagé</div>
<h1>BRO — ${PLAYER} partage avec vous</h1></div>
<div class="b"><div class="box">
<p><strong>${TTITLE}</strong></p>
<p><a href="${myIPFSGW}${ASTROTW}#${TTITLE}">Voir le tiddler →</a></p>
<p>Destinataires : ${emails[@]}</p>
</div>
<p>${PLAYER} partage ce contenu via UPlanet. Rejoignez la constellation pour participer pleinement.</p>
<p style="text-align:center;margin-top:1rem"><a href="https://qo-op.com" class="btn" target="_blank">Rejoindre UPlanet →</a></p>
<p style="text-align:center;margin-top:1.5rem"><small>UPlanet / G1FabLab — support@qo-op.com</small></p>
</div></div></body></html>
INVHTML

        ${MY_PATH}/../tools/mailjet.sh --template "$0" --expire 48h "${ZMAIL}" ~/.zen/tmp/palpay.bro "BRO. ${PLAYER} partage un tiddler avec vous"

    fi


done < ~/.zen/tmp/${MOATS}/@tags.json

echo "=====(•‿‿•)====== ( ◕‿◕)  (◕‿◕ ) =======(•‿‿•)======="

# rm -Rf $HOME/.zen/tmp/${MOATS}
ls $HOME/.zen/tmp/${MOATS}

exit 0
