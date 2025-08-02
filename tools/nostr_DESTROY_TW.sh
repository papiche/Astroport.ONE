#!/bin/bash
# -----------------------------------------------------------------------------
# nostr_DESTROY_TW.sh
#
# This script is used to deactivate ("unplug") a NOSTR + PLAYER UPlanet account.
# It allows the user to select a player email, exports and backs up all NOSTR data
# to IPFS, removes the NOSTR profile, transfers any remaining G1 balance to the
# primal account, removes the ZEN card, and sends a notification email to the user
# with recovery information and backup links. It also cleans up local cache and
# removes the NOSTR IPNS vault key.
#
# Usage: ./nostr_DESTROY_TW.sh [email]
# If no email is provided, the script will prompt the user to select one.
# -----------------------------------------------------------------------------
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
        g1pub=$(cat ~/.zen/game/nostr/${player_emails[$i]}/G1PUBNOSTR)
        pcoins=$(cat ~/.zen/tmp/coucou/${g1pub}.COINS)
        pprime=$(cat ~/.zen/tmp/coucou/${g1pub}.primal)
        echo "$i) ${player_emails[$i]} (${pcoins} Ğ1) ${g1pub} -> ${pprime}" 
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
if [[ -s ~/.zen/game/nostr/${player}/.secret.disco ]]; then
    DISCO=$(cat ~/.zen/game/nostr/${player}/.secret.disco)
    IFS='=&' read -r s salt p pepper <<< "$DISCO"
else
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
    IFS='=&' read -r s salt p pepper <<< "$DISCO"

    if [[ -n $pepper ]]; then
        rm "$tmp_mid" "$tmp_tail"
    else
        cat "$tmp_mid" "$tmp_tail"
        exit 1
    fi
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
    ${MY_PATH}/../tools/PAYforSURE.sh "${HOME}/.zen/tmp/nostr.dunikey" "$AMOUNT" "$prime" "MULTIPASS:$youser:PRIMAL:CASH BACK" 2>/dev/null
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
            <title>MULTIPASS/uDRIVE Desactivated | MULTIPASS/uDRIVE Désactivé</title>
            <meta charset='UTF-8'>
            <meta name='viewport' content='width=device-width, initial-scale=1.0'>
            <style>
                * {
                    box-sizing: border-box;
                }
                body { 
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
                    margin: 0;
                    padding: 0;
                    line-height: 1.5;
                    color: #2c3e50;
                    background: #f8f9fa;
                    font-size: 16px;
                }
                .email-container {
                    max-width: 600px;
                    margin: 0 auto;
                    background: white;
                    box-shadow: 0 2px 10px rgba(0,0,0,0.1);
                }
                .header {
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    color: white;
                    padding: 1.5rem;
                    text-align: center;
                    border-radius: 0;
                }
                .header h1 {
                    margin: 0;
                    font-size: 1.5rem;
                    font-weight: 600;
                    line-height: 1.3;
                }
                .content {
                    padding: 1.5rem;
                }
                .section {
                    margin: 1rem 0;
                    padding: 1rem;
                    border-radius: 8px;
                    border-left: 4px solid;
                    background: #fff;
                    box-shadow: 0 1px 3px rgba(0,0,0,0.1);
                }
                .status {
                    border-left-color: #e74c3c;
                    background: linear-gradient(135deg, #fff5f5 0%, #fed7d7 100%);
                }
                .backup {
                    border-left-color: #27ae60;
                    background: linear-gradient(135deg, #f0fff4 0%, #c6f6d5 100%);
                }
                .ai-status {
                    border-left-color: #8e44ad;
                    background: linear-gradient(135deg, #faf5ff 0%, #e9d8fd 100%);
                }
                .earn {
                    border-left-color: #3498db;
                    background: linear-gradient(135deg, #eff6ff 0%, #bfdbfe 100%);
                }
                .keys {
                    border-left-color: #e67e22;
                    background: linear-gradient(135deg, #fff7ed 0%, #fed7aa 100%);
                }
                .rejoin {
                    border-left-color: #2c3e50;
                    background: linear-gradient(135deg, #f7fafc 0%, #e2e8f0 100%);
                    text-align: center;
                }
                h2, h3, h4 {
                    margin: 0 0 0.5rem 0;
                    font-weight: 600;
                    line-height: 1.3;
                }
                h2 {
                    font-size: 1.25rem;
                    color: #1a202c;
                }
                h3 {
                    font-size: 1.1rem;
                    color: #2d3748;
                }
                h4 {
                    font-size: 1rem;
                    color: #4a5568;
                }
                p {
                    margin: 0 0 0.75rem 0;
                    font-size: 0.95rem;
                    line-height: 1.5;
                }
                p:last-child {
                    margin-bottom: 0;
                }
                a {
                    color: #3182ce;
                    text-decoration: none;
                    font-weight: 500;
                    transition: color 0.2s ease;
                }
                a:hover {
                    color: #2c5282;
                    text-decoration: underline;
                }
                .cta-button {
                    display: inline-block;
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    color: white;
                    padding: 0.75rem 1.5rem;
                    border-radius: 6px;
                    font-size: 0.9rem;
                    font-weight: 600;
                    text-decoration: none;
                    margin: 0.5rem 0.25rem;
                    box-shadow: 0 2px 4px rgba(102, 126, 234, 0.3);
                    transition: all 0.2s ease;
                }
                .cta-button:hover {
                    transform: translateY(-1px);
                    box-shadow: 0 4px 8px rgba(102, 126, 234, 0.4);
                    text-decoration: none;
                }
                .highlight {
                    background: rgba(102, 126, 234, 0.1);
                    padding: 0.2rem 0.4rem;
                    border-radius: 4px;
                    font-weight: 600;
                    color: #667eea;
                }
                code {
                    background: #f7fafc;
                    padding: 0.2rem 0.4rem;
                    border-radius: 4px;
                    font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace;
                    font-size: 0.85rem;
                    color: #2d3748;
                    border: 1px solid #e2e8f0;
                    word-break: break-all;
                }
                small {
                    font-size: 0.8rem;
                    color: #718096;
                    display: block;
                    margin-top: 0.5rem;
                }
                .emoji {
                    font-size: 1.2em;
                    margin-right: 0.3rem;
                }
                .button-group {
                    margin: 1rem 0;
                }
                .lang-selector {
                    text-align: center;
                    margin-bottom: 1rem;
                    padding: 0.5rem;
                    background: #f8f9fa;
                    border-radius: 6px;
                }
                .lang-btn {
                    display: inline-block;
                    padding: 0.5rem 1rem;
                    margin: 0 0.25rem;
                    background: white;
                    border: 2px solid #667eea;
                    border-radius: 6px;
                    color: #667eea;
                    text-decoration: none;
                    font-weight: 600;
                    font-size: 0.9rem;
                    transition: all 0.2s ease;
                }
                .lang-btn.active {
                    background: #667eea;
                    color: white;
                }
                .lang-btn:hover {
                    background: #667eea;
                    color: white;
                    text-decoration: none;
                }
                .lang-content {
                    display: none;
                }
                .lang-content.active {
                    display: block;
                }
                @media (max-width: 480px) {
                    body {
                        font-size: 14px;
                    }
                    .header {
                        padding: 1rem;
                    }
                    .header h1 {
                        font-size: 1.3rem;
                    }
                    .content {
                        padding: 1rem;
                    }
                    .section {
                        padding: 0.75rem;
                        margin: 0.75rem 0;
                    }
                    h2 {
                        font-size: 1.1rem;
                    }
                    h3 {
                        font-size: 1rem;
                    }
                    .cta-button {
                        display: block;
                        margin: 0.5rem 0;
                        text-align: center;
                    }
                    .button-group {
                        margin: 0.75rem 0;
                    }
                    .lang-btn {
                        display: block;
                        margin: 0.25rem 0;
                    }
                }
            </style>
            <script>
                function switchLanguage(lang) {
                    // Hide all language content
                    document.querySelectorAll('.lang-content').forEach(function(el) {
                        el.classList.remove('active');
                    });
                    
                    // Show selected language content
                    document.querySelectorAll('.lang-content[data-lang=\'' + lang + '\']').forEach(function(el) {
                        el.classList.add('active');
                    });
                    
                    // Update language buttons
                    document.querySelectorAll('.lang-btn').forEach(function(btn) {
                        btn.classList.remove('active');
                    });
                    document.querySelector('.lang-btn[data-lang=\'' + lang + '\']').classList.add('active');
                }
                
                // Set default language based on user preference or browser language
                window.onload = function() {
                    var browserLang = navigator.language || navigator.userLanguage;
                    var defaultLang = browserLang.startsWith('fr') ? 'fr' : 'en';
                    switchLanguage(defaultLang);
                    
                    // Add event listeners to language buttons
                    document.querySelectorAll('.lang-btn').forEach(function(btn) {
                        btn.addEventListener('click', function(e) {
                            e.preventDefault();
                            var lang = this.getAttribute('data-lang');
                            switchLanguage(lang);
                        });
                    });
                }
            </script>
        </head>
        <body>
            <div class='email-container'>
                <div class='header'>
                    <div class='lang-content' data-lang='en'>
                        <h1>⏸️ MULTIPASS/uDRIVE Paused</h1>
                    </div>
                    <div class='lang-content' data-lang='fr'>
                        <h1>⏸️ MULTIPASS/uDRIVE en Pause</h1>
                    </div>
                </div>
                
                <div class='content'>
                    <div class='lang-selector'>
                        <a href='#' class='lang-btn' data-lang='en'>🇺🇸 English</a>
                        <a href='#' class='lang-btn' data-lang='fr'>🇫🇷 Français</a>
                    </div>

                    <div class='section status'>
                        <div class='lang-content' data-lang='en'>
                            <h2>Account Status Update</h2>
                            <p>Your MULTIPASS/uDRIVE has been <span class='highlight'>temporarily paused</span> due to insufficient Ẑen balance. <strong>Your account is NOT deleted</strong> - all your data, connections, and settings are perfectly safe!</p>
                        </div>
                        <div class='lang-content' data-lang='fr'>
                            <h2>Mise à Jour du Statut du Compte</h2>
                            <p>Votre MULTIPASS/uDRIVE a été <span class='highlight'>temporairement en pause</span> en raison d'un solde Ẑen insuffisant. <strong>Votre compte N'EST PAS supprimé</strong> - toutes vos données, connexions et paramètres sont parfaitement en sécurité !</p>
                        </div>
                    </div>

                    <div class='section backup'>
                        <div class='lang-content' data-lang='en'>
                            <h3>📦 Complete Data Backup</h3>
                            <p>We've created a complete backup of all your MULTIPASS data on IPFS for your peace of mind:</p>
                            <a target='_blank' href='${myIPFS}/ipfs/${NOSTRIFS}/nostr_export.json' class='cta-button'>📥 Download Your Backup</a>
                        </div>
                        <div class='lang-content' data-lang='fr'>
                            <h3>📦 Sauvegarde Complète des Données</h3>
                            <p>Nous avons créé une sauvegarde complète de toutes vos données MULTIPASS sur IPFS pour votre tranquillité d'esprit :</p>
                            <a target='_blank' href='${myIPFS}/ipfs/${NOSTRIFS}/nostr_export.json' class='cta-button'>📥 Télécharger votre Sauvegarde</a>
                        </div>
                    </div>

                    <div class='section ai-status'>
                        <div class='lang-content' data-lang='en'>
                            <h3>🤖 #BRO AI Services</h3>
                            <p>Your #BRO AI assistant access is currently paused, but you can still connect with friends on our relay! Your social connections remain active.</p>
                        </div>
                        <div class='lang-content' data-lang='fr'>
                            <h3>🤖 Services IA #BRO</h3>
                            <p>Votre accès à l'assistant IA #BRO est actuellement en pause, mais vous pouvez toujours vous connecter avec vos amis sur notre relais ! Vos connexions sociales restent actives.</p>
                        </div>
                    </div>

                    <div class='section earn'>
                        <div class='lang-content' data-lang='en'>
                            <h3>💎 Earn Ẑen Easily!</h3>
                            <p>Need Ẑen? Join Coracle and earn <span class='highlight'>1 Ẑen per like</span> on your messages! Share your thoughts and get rewarded by the community.</p>
                            <a target='_blank' href='https://coracle.copylaradio.com' class='cta-button'>🚀 Join Coracle</a>
                        </div>
                        <div class='lang-content' data-lang='fr'>
                            <h3>💎 Gagnez des Ẑen Facilement !</h3>
                            <p>Besoin de Ẑen ? Rejoignez Coracle et gagnez <span class='highlight'>1 Ẑen par like</span> sur vos messages ! Partagez vos idées et soyez récompensé par la communauté.</p>
                            <a target='_blank' href='https://coracle.copylaradio.com' class='cta-button'>🚀 Rejoindre Coracle</a>
                        </div>
                    </div>

                    <div class='section keys'>
                        <div class='lang-content' data-lang='en'>
                            <h4>🔑 Your Recovery Keys (Keep Safe!)</h4>
                            <p><strong>Salt:</strong> <code>${salt}</code></p>
                            <p><strong>Pepper:</strong> <code>${pepper}</code></p>
                            <small>Store these securely - you'll need them to reactivate your account!</small>
                        </div>
                        <div class='lang-content' data-lang='fr'>
                            <h4>🔑 Vos Clés de Récupération (Gardez-les en Sécurité !)</h4>
                            <p><strong>Sel :</strong> <code>${salt}</code></p>
                            <p><strong>Poivre :</strong> <code>${pepper}</code></p>
                            <small>Conservez-les en sécurité - vous en aurez besoin pour réactiver votre compte !</small>
                        </div>
                    </div>

                    <div class='section rejoin'>
                        <div class='lang-content' data-lang='en'>
                            <h3>🚀 Ready to Reactivate?</h3>
                            <p>Get your Ẑen and come back stronger! Your community is waiting for you.</p>
                            <div class='button-group'>
                                <a target='_blank' href='${uSPOT}/g1' class='cta-button'>🌟 Reactivate My MULTIPASS</a>
                                <a target='_blank' href='https://opencollective.com/uplanet-zero#category-CONTRIBUTE' class='cta-button'>💎 Get Ẑen on OpenCollective</a>
                            </div>
                        </div>
                        <div class='lang-content' data-lang='fr'>
                            <h3>🚀 Prêt à Réactiver ?</h3>
                            <p>Obtenez vos Ẑen et revenez plus fort ! Votre communauté vous attend.</p>
                            <div class='button-group'>
                                <a target='_blank' href='${uSPOT}/g1' class='cta-button'>🌟 Réactiver Mon MULTIPASS</a>
                                <a target='_blank' href='https://opencollective.com/uplanet-zero#category-CONTRIBUTE' class='cta-button'>💎 Obtenir des Ẑen sur OpenCollective</a>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </body>
    </html>" \
    "${youser} : MULTIPASS #BRO access temporarily paused - your data is safe!"

## REMOVE NOSTR IPNS VAULT key
#~ ipfs name publish -k "${g1pubnostr}:NOSTR" $(cat "${HOME}/.zen/game/nostr/${player}/MULTIPASS.QR.png.cid") ## "G1QR" CID
ipfs key rm "${g1pubnostr}:NOSTR" > /dev/null 2>&1

## Cleaning local cache
rm ~/.zen/tmp/coucou/${g1pubnostr-null}.*
rm -Rf ~/.zen/game/nostr/${player-null}
exit 0
