#!/bin/bash
########################################################################
# Author: Fred (support@qo-op.com)
# Version: 2022.10.28
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)

########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

## --help traité AVANT exec/log pour rester visible dans le terminal
for _arg in "$@"; do
    if [[ "$_arg" == "--help" || "$_arg" == "-h" ]]; then
        cat <<EOF
USAGE
    $ME [OPTIONS] EMAIL MESSAGE_FILE SUBJECT [TW_INDEX]

DESCRIPTION
    Envoie un email HTML via l'API Mailjet v3.1 au nom de la station UPlanet.
    Le contenu est publié sur IPFS, un lien "lire en ligne" est injecté dans
    le corps. Si un profil NOSTR existe pour EMAIL, les coordonnées sont
    récupérées. En mode UPlanet ORIGIN (UPLANETNAME=0000…), le chemin du
    template source est affiché en pied de message (avec --template).

ARGUMENTS POSITIONNELS
    EMAIL           Adresse email du destinataire.
    MESSAGE_FILE    Fichier HTML (ou texte brut) constituant le corps du
                    message. Si le fichier n'existe pas, la valeur est
                    utilisée directement comme contenu inline.
    SUBJECT         Objet du message. Préfixé automatiquement par "[UPlanet]".
    TW_INDEX        (optionnel) Chemin vers un TiddlyWiki local : le message
                    est importé comme tiddler IFRAME dans ce fichier.

OPTIONS
    --expire DURATION
        Durée avant expiration du lien IPFS du message. Formats :
          0s   →  pas d'expiration (envoi immédiat permanent)
          30m  →  30 minutes
          2h   →  2 heures
          48h  →  48 heures
          7d   →  7 jours   (défaut recommandé pour les notifications)
          2w   →  2 semaines
        Sans cette option, le message n'expire pas.

    --template PATH
        Chemin du fichier template HTML source ayant servi à générer
        MESSAGE_FILE. Affiché en pied de message sur UPlanet ORIGIN pour
        identifier facilement quel template modifier.
        Utiliser \$0 quand le HTML est généré inline dans le script appelant.

    --help, -h
        Affiche cette aide et quitte (sans écrire dans mailjet.log).

CREDENTIALS
    Cherchés dans cet ordre de priorité :
      1. cooperative-config (NOSTR DID, chiffré avec UPLANETNAME) via
         tools/cooperative_config.sh → MJ_APIKEY_PUBLIC, MJ_APIKEY_PRIVATE,
         MJ_SENDER_EMAIL
      2. ~/.zen/MJ_APIKEY  (fichier local, format legacy)
    Sans credentials valides, l'email n'est pas envoyé (sortie silencieuse).

COMPORTEMENT INTERNE
    1. Recherche le destinataire dans ~/.zen/game/players/ (ASTROPORT,
       ASTRONAUTENS, ASTROG1, EMAIL, FEEDNS, TW, source).
    2. Recherche le profil NOSTR associé à EMAIL (HEX, NPUB, RELAY, LAT, LON).
    3. Détecte le mode station :
         UPlanet ORIGIN  si UPLANETNAME = 0000…000
         UPlanet Ẑen     si UPLANETNAME ≠ 0000…000 (affiche UPLANETG1PUB:0:8)
    4. Publie le contenu sur IPFS (ipfs add --pin=false, timeout 15 s).
    5. Si TW_INDEX fourni : importe le message comme tiddler IFRAME.
    6. Construit le payload JSON via jq et appelle l'API Mailjet v3.1.
    7. Envoie une copie BCC à SENDER_EMAIL (compte SUPPORT).

EXEMPLES
    # Envoi simple
    $ME user@example.com message.html 'Bienvenue'

    # Avec import TiddlyWiki
    $ME user@example.com zine.html 'Zine #7' ~/.zen/game/players/user@example.com/TW/index.html

    # Welcome depuis template (trace du fichier source)
    $ME --template "\${MY_PATH}/../templates/NOSTR/welcome.html" \\
        --expire 7d \\
        user@example.com ~/.zen/game/nostr/user@example.com/.welcome.html \\
        'Welcome on UPlanet'

    # Alerte générée inline (template = script lui-même)
    $ME --template "\$0" --expire 48h captain@node.net /tmp/alert.html '🚨 Alerte'

    # Envoi immédiat sans expiration
    $ME --expire 0s user@example.com multipass.html 'MULTIPASS[Ẑ]'

FICHIERS
    ~/.zen/MJ_APIKEY          Credentials Mailjet legacy
                              (MJ_APIKEY_PUBLIC, MJ_APIKEY_PRIVATE, SENDER_EMAIL)
    ~/.zen/tmp/mailjet.log    Log complet de toutes les exécutions
    tools/my.sh               Bibliothèque centrale (myIPFS, myDOMAIN, uSPOT,
                              UPLANETNAME, UPLANETG1PUB, IPFSNODEID, CAPTAINEMAIL…)
    templates/NOSTR/          Templates HTML des notifications UPlanet
    templates/UPlanetZINE/    Templates HTML des ZINEs d'onboarding
EOF
        exit 0
    fi
done

. "$MY_PATH/my.sh"

## LOG OUTPUT
exec 2>&1 >> ~/.zen/tmp/mailjet.log

echo '
########################################################################
# \\///
# qo-op
############# '$MY_PATH/$ME'
########################################################################'

# Parse command line arguments
EPHEMERAL_DURATION=""
TEMPLATE_SRC=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --expire)
            EPHEMERAL_DURATION="$2"
            shift 2
            ;;
        --template)
            TEMPLATE_SRC="$2"
            shift 2
            ;;
        --help|-h)
            exec "$0" --help
            ;;
        -*)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

[[ ! $1 ]] \
    && echo "MISSING DESTINATION EMAIL" \
    && echo "Use --help for usage information" \
    && exit 1

mail="$1" # EMAIL DESTINATAIRE
############################################## SEARCH in players
$($MY_PATH/../tools/search_for_this_email_in_players.sh ${mail} | tail -n 1)
echo "ASTROPORT=$ASTROPORT
ASTROTW=$ASTRONAUTENS
ASTROG1=$ASTROG1
ASTROMAIL=$EMAIL
ASTROFEED=$FEEDNS
TW=$TW
source=$source"

############################################## SEARCH in NOSTR
echo "🔍 Searching for NOSTR profile for ${mail}..."
NOSTR_LINE=$($MY_PATH/search_for_this_email_in_nostr.sh "${mail}" 2>/dev/null | tail -n 1)
if [[ -n "$NOSTR_LINE" && "$NOSTR_LINE" == export\ * ]]; then
    echo "✅ NOSTR profile found"
    echo "$NOSTR_LINE"
    # Extraction sécurisée : aucun eval — chaque variable extraite individuellement par grep -oP
    # Cela protège contre toute injection de code depuis un profil NOSTR malveillant
    HEX=$(echo "$NOSTR_LINE"       | grep -oP '(?<=\bHEX=)[^ ]+')
    NPUB=$(echo "$NOSTR_LINE"      | grep -oP '(?<=\bNPUB=)[^ ]+')
    RELAY=$(echo "$NOSTR_LINE"     | grep -oP '(?<=\bRELAY=)[^ ]+')
    G1PUBNOSTR=$(echo "$NOSTR_LINE"| grep -oP '(?<=\bG1PUBNOSTR=)[^ ]+')
    LAT=$(echo "$NOSTR_LINE"       | grep -oP '(?<=\bLAT=)[^ ]+')
    LON=$(echo "$NOSTR_LINE"       | grep -oP '(?<=\bLON=)[^ ]+')
    echo "NOSTR_HEX=$HEX"
    echo "NOSTR_NPUB=$NPUB"
    echo "NOSTR_RELAY=$RELAY"
else
    echo "❌ No NOSTR profile found for ${mail}"
    HEX=""
    NPUB=""
    RELAY=""
    G1PUBNOSTR=""
    LAT=""
    LON=""
fi

## Is it UPlanet ORIGIN or Ẑen ?
[[ $UPLANETNAME != "0000000000000000000000000000000000000000000000000000000000000000" ]] \
	&& UPLANET="UPlanet Ẑen ${UPLANETG1PUB:0:8}" \
	|| UPLANET="UPlanet ORIGIN"

#~ echo "DEST=$mail"
# mail=geg-la_debrouille@super.chez-moi.com
YUSER=$(echo ${mail} | cut -d '@' -f1)    # YUSER=geg-la_debrouille
LYUSER=($(echo "$YUSER" | sed 's/[^a-zA-Z0-9]/\ /g')) # LYUSER=(geg la debrouille)
CLYUSER=$(printf '%s\n' "${LYUSER[@]}" | tac | tr '\n' '.' ) # CLYUSER=debrouille.la.geg.
YOMAIN=$(echo ${mail} | cut -d '@' -f 2)    # YOMAIN=super.chez-moi.com
pseudo="${CLYUSER}${YOMAIN}.${myDOMAIN}"
#~ echo "PSEUDO=$pseudo"

messfile="$2" # FICHIER A AJOUTER AU CORPS MESSAGE

## add a tittle in message
title="$3"

# Function to convert human-readable duration to seconds
convert_duration_to_seconds() {
    local duration="$1"
    local seconds=0
    
    # Remove any whitespace
    duration=$(echo "$duration" | tr -d ' ')
    
    # Check if it's already a number (seconds) or has 's' suffix
    if [[ "$duration" =~ ^[0-9]+$ ]] || [[ "$duration" =~ ^[0-9]+s$ ]]; then
        # Remove 's' suffix if present
        duration=$(echo "$duration" | sed 's/s$//')
        echo "$duration"
        return
    fi
    
    # Parse duration with units
    if [[ "$duration" =~ ^([0-9]+)([smhdw])$ ]]; then
        local value="${BASH_REMATCH[1]}"
        local unit="${BASH_REMATCH[2]}"
        
        case "$unit" in
            s) seconds=$((value)) ;;
            m) seconds=$((value * 60)) ;;
            h) seconds=$((value * 3600)) ;;
            d) seconds=$((value * 86400)) ;;
            w) seconds=$((value * 604800)) ;;
        esac
        
        echo "$seconds"
    else
        echo "0"
    fi
}

# Function to convert seconds back to human-readable format
convert_seconds_to_human() {
    local seconds="$1"
    local result=""
    
    # Weeks
    if [[ $seconds -ge 604800 ]]; then
        local weeks=$((seconds / 604800))
        result="${weeks}w"
        seconds=$((seconds % 604800))
    fi
    
    # Days
    if [[ $seconds -ge 86400 ]]; then
        local days=$((seconds / 86400))
        result="${result}${days}d"
        seconds=$((seconds % 86400))
    fi
    
    # Hours
    if [[ $seconds -ge 3600 ]]; then
        local hours=$((seconds / 3600))
        result="${result}${hours}h"
        seconds=$((seconds % 3600))
    fi
    
    # Minutes
    if [[ $seconds -ge 60 ]]; then
        local minutes=$((seconds / 60))
        result="${result}${minutes}m"
        seconds=$((seconds % 60))
    fi
    
    # Seconds
    if [[ $seconds -gt 0 ]]; then
        result="${result}${seconds}s"
    fi
    
    echo "$result"
}

# Convert ephemeral duration to seconds if provided
if [[ -n "$EPHEMERAL_DURATION" ]]; then
    ephemeral_duration=$(convert_duration_to_seconds "$EPHEMERAL_DURATION")
    if [[ "$ephemeral_duration" -eq 0 ]]; then
        echo "ERROR: Invalid duration format: $EPHEMERAL_DURATION"
        echo "Valid formats: 60s, 30m, 2h, 7d, 1w"
        exit 1
    fi
    echo "⏰ Ephemeral message duration: $EPHEMERAL_DURATION = ${ephemeral_duration}s"
else
    ephemeral_duration=""
fi

SUBJECT="[UPlanet] ${title}"

MESSAGESIGN="---<br>message sent by <a href='${myIPFS}/ipns/$IPFSNODEID'>$(myHostName)</a> (Station Astroport.ONE)"

echo "
########################################################################
# $SUBJECT + $messfile -> $mail
########################################################################"

# + HTML in FILE
# 1. Récupération du contenu (fichier ou texte direct)
if [[ -s "$messfile" ]]; then
    RAW_CONTENT=$(cat "$messfile")
else
    RAW_CONTENT="$messfile"
fi

# 2. Génération du lien IPFS (Conservé pour Nostr et TiddlyWiki)
EMAILZ=$(echo "$RAW_CONTENT" | timeout 15s ipfs add -q --pin=false)
export TEXTPART="${myIPFS}/ipfs/${EMAILZ}"

################### IMPORT MAILJET INTO IF $4=TW
INDEX="$4"
if [[ -s ${INDEX} ]]; then
    echo "INSERT ZINE INTO TW"
    MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
    mkdir -p ~/.zen/tmp/${MOATS}

    cat ${MY_PATH}/../templates/data/IFRAME.json \
    | sed -e "s~_MOATS_~${MOATS}~g" \
    -e "s~_TITLE_~/MAILJET/${SUBJECT^^}~g" \
    -e "s~_CID_~${EMAILZ}~g" \
    -e "s~_PLAYER_~${mail}~g" \
        > ~/.zen/tmp/iframe.json

    ### IMPORT INTO TW
    tiddlywiki --load ${INDEX} \
                --import ~/.zen/tmp/iframe.json "application/json" \
                --output ~/.zen/tmp/${MOATS} --render "$:/core/save/all" "newindex.html" "text/plain"

    if [[ -s ~/.zen/tmp/${MOATS}/newindex.html ]]; then
        [[ $(diff ~/.zen/tmp/${MOATS}/newindex.html ${INDEX} ) ]] \
            && mv ~/.zen/tmp/${MOATS}/newindex.html ${INDEX} \
            && echo "===> Mise à jour ${INDEX}"
    else
        echo "Problem with tiddlywiki command. Missing ~/.zen/tmp/${MOATS}/newindex.html"
        echo "XXXXXXXXXXXXXXXXXXXXXXX"
    fi
fi

[[ $title == "" ]] && title="MESSAGE"

############# GETTING MAILJET API ############### from cooperative-config or ~/.zen/MJ_APIKEY
## Try cooperative-config first (shared via NOSTR, encrypted with UPLANETNAME)
if [[ -f "${MY_PATH}/cooperative_config.sh" ]]; then
    source "${MY_PATH}/cooperative_config.sh"
    _mj_pub=$(coop_config_get "MJ_APIKEY_PUBLIC" 2>/dev/null)
    _mj_priv=$(coop_config_get "MJ_APIKEY_PRIVATE" 2>/dev/null)
    _mj_sender=$(coop_config_get "MJ_SENDER_EMAIL" 2>/dev/null)
    if [[ -n "$_mj_pub" && -n "$_mj_priv" && -n "$_mj_sender" ]]; then
        export MJ_APIKEY_PUBLIC="$_mj_pub"
        export MJ_APIKEY_PRIVATE="$_mj_priv"
        export SENDER_EMAIL="$_mj_sender"
        echo "MailJet credentials loaded from cooperative-config (NOSTR DID)"
    fi
fi
## Fallback: local file (legacy)
if [[ -z "$MJ_APIKEY_PUBLIC" && -s ~/.zen/MJ_APIKEY ]]; then
    source ~/.zen/MJ_APIKEY
    echo "MailJet credentials loaded from ~/.zen/MJ_APIKEY (legacy)"
fi

if [[ -n "$MJ_APIKEY_PUBLIC" && -n "$MJ_APIKEY_PRIVATE" && -n "$SENDER_EMAIL" ]]; then
    export RECIPIENT_EMAIL=${mail}

    # 3. Préparation du corps de l'email
    # On intègre RAW_CONTENT directement dans le HTML
    IPFS_ONLINE_LINK="<p style=\"text-align:center; font-size:0.85em; color:#888;\"><a href=\"${myIPFS}/ipfs/${EMAILZ}\">🌐 Lire ce message en ligne (IPFS)</a></p><hr style=\"border:none; border-top:1px solid #eee;\">"

    TEMPLATE_INFO=""
    if [[ "$UPLANET" == "UPlanet ORIGIN" && -n "$TEMPLATE_SRC" ]]; then
        TEMPLATE_INFO="<p style=\"font-size:0.75em; color:#aaa; font-family:monospace;\">📄 Template: <code>${TEMPLATE_SRC}</code></p>"
    fi

    FULL_HTML="${IPFS_ONLINE_LINK}<h3>${title}</h3><br><br>${RAW_CONTENT}<br><br><hr><p><a href=\"${uSPOT}/nostr\">${UPLANET}</a> [ /ipns/${pseudo} ]<br />${MESSAGESIGN}</p>${TEMPLATE_INFO}"
    
    # Fallback en texte brut contenant le lien IPFS
    PLAIN_TEXT="Voir le message sur le réseau IPFS : ${myIPFS}/ipfs/${EMAILZ}\n\nMessage de ${UPLANET}"

    # 4. Construction du JSON sécurisé via jq (Gère automatiquement l'échappement des guillemets et retours à la ligne du HTML)
    json_payload=$(jq -n \
        --arg sender_email "$SENDER_EMAIL" \
        --arg recipient_email "$RECIPIENT_EMAIL" \
        --arg pseudo "$pseudo" \
        --arg subject "$SUBJECT" \
        --arg text_part "$PLAIN_TEXT" \
        --arg html_part "$FULL_HTML" \
        '{
            "Messages": [
                {
                    "From": {
                        "Email": $sender_email,
                        "Name": "UPlanet Keeper"
                    },
                    "To": [
                        {
                            "Email": $recipient_email,
                            "Name": ($pseudo + " Astronaut")
                        }
                    ],
                    "Bcc": [
                        {
                            "Email": $sender_email,
                            "Name": "SUPPORT"
                        }
                    ],
                    "Subject": $subject,
                    "TextPart": $text_part,
                    "HTMLPart": $html_part
                }
            ]
        }')

    # Verify the JSON structure (optional, good for logs)
    # echo "$json_payload" | jq .

    echo "Envoi du mail avec contenu HTML embarqué via Mailjet API v3.1..."
    curl -s -m 15 \
        -X POST \
        --user "${MJ_APIKEY_PUBLIC}:${MJ_APIKEY_PRIVATE}" \
        https://api.mailjet.com/v3.1/send \
        -H 'Content-Type: application/json' \
        -d "$json_payload"

fi