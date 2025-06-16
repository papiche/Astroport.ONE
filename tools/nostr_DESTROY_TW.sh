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
## Extract email from s parameter
# DEBUG: s before removal (quoted): '/?youyou@yopmail.com'
email=${s:2}  # Remove the first two characters (/, ?)
echo "$email"
youser=$($MY_PATH/../tools/clyuseryomail.sh "${email}")
secnostr=$(${MY_PATH}/../tools/keygen -t nostr "${salt}" "${pepper}" -s)
pubnostr=$(${MY_PATH}/../tools/keygen -t nostr "${salt}" "${pepper}")

OUTPUT_DIR="$HOME/.zen/game/nostr/${email}"

echo ./strfry scan '{"authors": ["'$hex'"]}'
cd ~/.zen/strfry
./strfry scan '{"authors": ["'$hex'"]}' 2> /dev/null > "${OUTPUT_DIR}/nostr_export.json"
cd - > /dev/null 2>&1

COUNT=$(wc -l < "${OUTPUT_DIR}/nostr_export.json")
echo "Exported ${COUNT} events to ${OUTPUT_DIR}/nostr_export.json"
NOSTRIFS=$(ipfs add -rwq "${OUTPUT_DIR}"/* | tail -n 1) ## ADD ALL FILES IN OUTPUT_DIR
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
    ${MY_PATH}/../tools/PAY4SURE.sh "${HOME}/.zen/tmp/nostr.dunikey" "$AMOUNT" "$prime" "MULTIPASS:$youser:PRIMAL:CASH BACK" 2>/dev/null
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
            <title>MULTIPASS/uDRIVE Card Deactivated | Carte MULTIPASS/uDRIVE Désactivée</title>
            <meta charset='UTF-8'>
            <meta name='viewport' content='width=device-width, initial-scale=1.0'>
            <style>
                body { 
                    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                    max-width: 800px;
                    margin: 2em auto;
                    line-height: 1.6;
                    color: #333;
                    padding: 0 1em;
                }
                .section {
                    margin: 2em 0;
                    padding: 1.5em;
                    border-radius: 8px;
                    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
                }
                .alert {
                    background: #fff3cd;
                    border-left: 4px solid #ffc107;
                }
                .backup {
                    background: #d4edda;
                    border-left: 4px solid #28a745;
                }
                .ai-status {
                    background: #e2e3e5;
                    border-left: 4px solid #6c757d;
                }
                .keys {
                    background: #cce5ff;
                    border-left: 4px solid #0d6efd;
                }
                .lang-section {
                    padding: 1em 0;
                    border-bottom: 1px solid #eee;
                }
                h2, h3, h4 {
                    color: #2c3e50;
                    margin-top: 0;
                }
                a {
                    color: #0d6efd;
                    text-decoration: none;
                }
                a:hover {
                    text-decoration: underline;
                }
            </style>
        </head>
        <body>
            <div class='section alert'>
                <div class='lang-section'>
                    <h2>⚠️ MULTIPASS/uDRIVE Card Deactivated</h2>
                    <p>Your MULTIPASS/uDRIVE card has been deactivated due to missing Ẑen balance. Don't worry - all your data is safe!</p>
                </div>
                <div class='lang-section'>
                    <h2>⚠️ Carte MULTIPASS/uDRIVE Désactivée</h2>
                    <p>Votre carte MULTIPASS/uDRIVE a été désactivée en raison d'un solde Ẑen insuffisant. Ne vous inquiétez pas - toutes vos données sont en sécurité !</p>
                </div>
            </div>

            <div class='section backup'>
                <div class='lang-section'>
                    <h3>📦 Your Data Backup</h3>
                    <p>We've archived all your MULTIPASS data on IPFS: <a target='_blank' href='${myIPFS}/ipfs/${NOSTRIFS}'>Download Backup</a></p>
                </div>
                <div class='lang-section'>
                    <h3>📦 Sauvegarde de vos Données</h3>
                    <p>Nous avons archivé les données de votre MULTIPASS sur IPFS : <a target='_blank' href='${myIPFS}/ipfs/${NOSTRIFS}'>Télécharger la Sauvegarde</a></p>
                </div>
            </div>

            <div class='section ai-status'>
                <div class='lang-section'>
                    <h3>🤖 #BRO AI Status</h3>
                    <p>While #BRO AI access is currently disabled, you can still connect with friends present on our relay!</p>
                </div>
                <div class='lang-section'>
                    <h3>🤖 Statut de l'IA #BRO</h3>
                    <p>Bien que votre accès à l'IA #BRO soit actuellement désactivé, vous pouvez toujours vous connecter avec vos amis présents sur notre relais !</p>
                </div>
            </div>

            <div class='section keys'>
                <div class='lang-section'>
                    <h4>🔑 Your Keys (Keep these safe!)</h4>
                    <p>Salt: ${salt}</p>
                    <p>Pepper: ${pepper}</p>
                </div>
                <div class='lang-section'>
                    <h4>🔑 Vos Clés (Gardez-les en sécurité !)</h4>
                    <p>Sel : ${salt}</p>
                    <p>Poivre : ${pepper}</p>
                </div>
            </div>

            <div class='section'>
                <div class='lang-section'>
                    <p>Ready to rejoin? <a target='_blank' href='${uSPOT}/g1'>Respawn your MULTIPASS</a></p>
                </div>
                <div class='lang-section'>
                    <p>Revenez quand vous aurez des Ẑen ! <a target='_blank' href='${uSPOT}/g1'>Réactivez votre MULTIPASS</a></p>
                </div>
            </div>
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
