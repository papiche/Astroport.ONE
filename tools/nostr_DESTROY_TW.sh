#!/bin/bash
# Unplug NOSTR + PLAYER UPlanet Account

MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

. "${MY_PATH}/my.sh"

# Function to display usage information
usage() {
    echo "Usage: $ME [email]"
    echo "This script will prompt you to select a player email from the available options."
    exit 1
}

# Function to list available player emails and prompt user to select one
select_player_email() {
    echo "Available player emails:"
    player_emails=($(ls ~/.zen/game/nostr/*@*.*/HEX | rev | cut -d '/' -f 2 | rev))
    if [ ${#player_emails[@]} -eq 0 ]; then
        echo "No player emails found."
        exit 1
    fi

    for i in "${!player_emails[@]}"; do
        echo "$i) ${player_emails[$i]}"
    done

    read -p "Select the number corresponding to the player email: " selection
    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 0 ] || [ "$selection" -ge ${#player_emails[@]} ]; then
        echo "Invalid selection."
        exit 1
    fi

    player="${player_emails[$selection]}"
}

################### PLAYER G1 PUB ###########################
[[ -n "$1" ]] && player="$1"
[[ -z $player ]] && select_player_email
g1pubnostr=$(cat ~/.zen/game/nostr/${player}/G1PUBNOSTR)
[[ -z $g1pubnostr ]] && echo "BAD NOSTR MULTIPASS" && exit 1
hex=$(cat ~/.zen/game/nostr/${player}/HEX)

##################### DISCO DECODING ########################
tmp_mid=$(mktemp)
tmp_tail=$(mktemp)
# Decrypt the middle part using CAPTAIN key
${MY_PATH}/../tools/natools.py decrypt -f pubsec -i "$HOME/.zen/game/nostr/${player}/.ssss.mid.captain.enc" \
        -k ~/.zen/game/players/.current/secret.dunikey -o "$tmp_mid"

# Decrypt the tail part using UPLANET dunikey
if [[ ! -s ~/.zen/game/uplanet.dunikey ]]; then
    ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/game/uplanet.dunikey "${UPLANETNAME}" "${UPLANETNAME}"
    chmod 600 ~/.zen/game/uplanet.dunikey
fi
${MY_PATH}/../tools/natools.py decrypt -f pubsec -i "$HOME/.zen/game/nostr/${player}/ssss.tail.uplanet.enc" \
        -k ~/.zen/game/uplanet.dunikey -o "$tmp_tail"

# Combine decrypted shares
DISCO=$(cat "$tmp_mid" "$tmp_tail" | ssss-combine -t 2 -q 2>&1 | tail -n 1)
#~ echo "DISCO = $DISCO" ## DEBUG
IFS='=&' read -r s salt p pepper <<< "$DISCO"

if [[ -n $pepper ]]; then
    rm "$tmp_mid" "$tmp_tail"
else
    cat "$tmp_mid" "$tmp_tail"
    exit 1
fi
##################################################### DISCO DECODED
## s=/?email
echo $s
youser=$($MY_PATH/../tools/clyuseryomail.sh "${s}")
secnostr=$(${MY_PATH}/../tools/keygen -t nostr "${salt}" "${pepper}" -s)
pubnostr=$(${MY_PATH}/../tools/keygen -t nostr "${salt}" "${pepper}")

OUTPUT_DIR="$HOME/.zen/game/nostr/${s}"

echo ./strfry scan '{"authors": ["'$hex'"]}'
cd ~/.zen/strfry
./strfry scan '{"authors": ["'$hex'"]}' 2> /dev/null > "${OUTPUT_DIR}/nostr_export.json"
cd - > /dev/null 2>&1

COUNT=$(wc -l < "${OUTPUT_DIR}/nostr_export.json")
echo "Exported ${COUNT} events to ${OUTPUT_DIR}/nostr_export.json"
NOSTRIFS=$(ipfs add -rwq "${OUTPUT_DIR}/*" | tail -n 1) ## ADD ALL FILES IN OUTPUT_DIR
ipfs pin rm ${NOSTRIFS}

echo "DELETING ${player} NOSTRCARD : $pubnostr"
## 1. REMOVE NOSTR PROFILE
$MY_PATH/../tools/nostr_remove_profile.py "${secnostr}" "$myRELAY" "wss://relay.copylaradio.com"

## 2. CASH BACK
${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/tmp/nostr.dunikey "${salt}" "${pepper}"
AMOUNT=$(${MY_PATH}/../tools/COINScheck.sh ${g1pubnostr} | tail -n 1)
echo "______ AMOUNT = ${AMOUNT} G1"
## EMPTY AMOUNT G1 to PRIMAL
prime=$(cat ~/.zen/tmp/coucou/${g1pubnostr}.primal 2>/dev/null)
[[ -z $prime ]] && prime=${UPLANETG1PUB}
if [[ -n ${AMOUNT} && ${AMOUNT} != "null" ]]; then
    ${MY_PATH}/../tools/PAY4SURE.sh "${HOME}/.zen/tmp/nostr.dunikey" "$AMOUNT" "$prime" "MULTIPASS:$youser:PRIMAL:CASH BACK"
fi
rm ~/.zen/tmp/nostr.dunikey

## 2. REMOVE ZEN CARD
if [[ -s "${HOME}/.zen/game/players/${player}/ipfs/moa/index.html" ]]; then
    echo "/PLAYER.unplug : TW + ZEN CARD"
    ${MY_PATH}/../RUNTIME/PLAYER.unplug.sh "${HOME}/.zen/game/players/${player}/ipfs/moa/index.html" "${player}" "ALL"
fi

## SEND EMAIL with g1pubnostr.QR
${MY_PATH}/../tools/mailjet.sh \
    "${player}" \
    "<html>
        <head>
            <style>
                body { font-family: sans-serif; max-width: 800px; margin: 2em auto; line-height: 1.6; }
                .alert { background: #fff3cd; border: 1px solid #ffeeba; padding: 1em; border-radius: 4px; }
                .backup { background: #d4edda; border: 1px solid #c3e6cb; padding: 1em; border-radius: 4px; margin: 1em 0; }
                .keys { background: #e2e3e5; border: 1px solid #d6d8db; padding: 1em; border-radius: 4px; }
            </style>
        </head>
        <body>
            <div class='alert'>
                <h2>⚠️ MULTIPASS Card Deactivated</h2>
                <p>Your MULTIPASS card has been deactivated due to missing Ẑen balance. Don't worry - all your data is safe!</p>
            </div>

            <div class='backup'>
                <h3>📦 Your Data Backup</h3>
                <p>We've archived all your MULTIPASS data here: <a target='_blank' href='${myIPFS}/ipfs/${NOSTRIFS}'>Download Backup</a></p>
            </div>

            <div>
                <h3>🤖 #BRO AI Status</h3>
                <p>While #BRO AI access is currently disabled, you can still connect with friends on our relay!</p>
            </div>

            <div class='keys'>
                <h4>🔑 Your Keys (Keep these safe!)</h4>
                <p>Salt: ${salt}</p>
                <p>Pepper: ${pepper}</p>
            </div>

            <p>Ready to rejoin? <a target='_blank' href='${uSPOT}/g1'>Respawn your MULTIPASS</a></p>
        </body>
    </html>" \
    "${youser} : MULTIPASS #BRO access disabled."

## REMOVE NOSTR IPNS VAULT key
#~ ipfs name publish -k "${g1pubnostr}:NOSTR" $(cat "${HOME}/.zen/game/nostr/${player}/G1PUBNOSTR.QR.png.cid") ## "G1QR" CID
ipfs key rm "${g1pubnostr}:NOSTR" > /dev/null 2>&1

## Cleaning local cache
rm ~/.zen/tmp/coucou/${g1pubnostr-null}.*
rm -Rf ~/.zen/game/nostr/${player-null}
exit 0
