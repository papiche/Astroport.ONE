#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.2
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# Activate SUPPORT MODE: open ssh over IPFS
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "$MY_PATH/../tools/my.sh"
########################################################################
YOU=$(pgrep -au $USER -f "ipfs daemon" > /dev/null && echo "$USER") || er+=" ipfs daemon not running"
[[ "$YOU" == "" || "${IPFSNODEID}" == "" ]] && echo "ERROR : $er " && exit 1
########################################################################
## THIS SCRIPT COPY BOOSTRAP PUBKEY
### AND OPEN IPFS P2P SSH FORWARD ON CHANNEL
# Make Station publish SSH port on "/x/ssh-$(IPFSNODEID)"
########################################################################
## use STOP or OFF to finish forwarding

PARAM="$1"
if [[ "${PARAM,,}" == "off" || "${PARAM,,}" == "stop" ]]; then
    ipfs p2p close --all
	### RESET NODE & UPLANET KEYS -- will be refreshed on next astroport restart
	rm ~/.zen/game/myswarm_secret.*
	rm ~/.zen/game/uplanet.*
	########################################################################################
    rm ~/.zen/tmp/${IPFSNODEID}/x_*.sh 2>/dev/null
    rm ~/.zen/tmp/${IPFSNODEID}/y_ssh.pub 2>/dev/null
    rm ~/.zen/tmp/${IPFSNODEID}/z_ssh.pub 2>/dev/null
    echo "STOP" && exit 0
fi


########################################################################################
### CHECK & FORCE YLEVEL 
~/.zen/Astroport.ONE/tools/Ylevel.sh
########################################################################################
############################################
## Y LEVEL = SSH PUBKEY OVER IPFS y_ssh.pub
## https://pad.p2p.legal/keygen
if [[ -s ~/.ssh/id_ed25519.pub ]]; then
    ## TEST IF TRANSMUTATION IS MADE
    YIPNS=$($HOME/.zen/Astroport.ONE/tools/ssh_to_g1ipfs.py "$(cat ~/.ssh/id_ed25519.pub)")
    if [[ ${IPFSNODEID} == ${YIPNS} ]]; then
        # Y LEVEL CONFIRMED !
            echo "Y LEVEL CONFIRMED !" \
            && cat ~/.ssh/id_ed25519.pub > ~/.zen/tmp/${IPFSNODEID}/y_ssh.pub
    else
        # DEFAULT X LEVEL - IPFSNODEID not linked with SSH
        rm -f ~/.zen/tmp/${IPFSNODEID}/y_ssh.pub 2>/dev/null
        echo "LEVEL X - IPFSNODEID not linked with SSH _____ ٩(̾●̮̮̃̾•̃̾)۶ _____"
        echo "${YIPNS} != ${IPFSNODEID}"
        cp ~/.ssh/id_ed25519.pub ~/.zen/tmp/${IPFSNODEID}/x_ssh.pub
    fi
fi

## DRAGONz PGP style - UBiKEY mode - foopgp.org 
gpg --export-ssh-key $(cat ~/.zen/game/players/.current/.player) 2>/dev/null > ~/.zen/tmp/${IPFSNODEID}/z_ssh.pub
[[ ! -s ~/.zen/tmp/${IPFSNODEID}/z_ssh.pub ]] && rm ~/.zen/tmp/${IPFSNODEID}/z_ssh.pub 2>/dev/null # remove empty file

## PRODUCE SWARM SEED PART - used to create swarm.key
if [[ -s ~/.zen/tmp/${IPFSNODEID}/z_ssh.pub || -s ~/.zen/tmp/${IPFSNODEID}/y_ssh.pub ]]; then
    [[ ! -s ~/.zen/tmp/${IPFSNODEID}/_swarm.egg.txt ]] \
        && head -c 12 /dev/urandom | od -t x1 -A none - | tr -d ' ' \
                > ~/.zen/tmp/${IPFSNODEID}/_swarm.egg.txt
fi

################################################################
# Créer le fichier swarm.key UPlanet ORIGIN
if [[ ! -s ~/.ipfs/swarm.key ]]; then
cat > ~/.ipfs/swarm.key <<EOF
/key/swarm/psk/1.0.0/
/base16/
0000000000000000000000000000000000000000000000000000000000000000
EOF
chmod 600 ~/.ipfs/swarm.key
fi
################################################################

echo "${YIPNS}

                      /|               /\\
                 /^^^/ |^\Z           /  |
                |         \Z         /   |
                / @        \Z       /   / \_______
   (  \      _ /            \Z     /   /         /
 (     ---- /G       |\      |Z   /   /         /
  (  / ---- \    /---'/\     |Z  /   /         /
             \/--'   /--/   /Z  /             /
              |     /--/   |Z  /            / \_______
             /     /--/    |Z  \           /         /
          --/     /--/     \Z   |         /         /
           /     /--/       \Z  /                  /
                |--|         \Z/                  /
                |---|        /              /----'
                 \---|                     /^^^^^^^^^^^^\Z
                  \-/                                    \Z
                   /     /        |                       \Z
               \---'    |\________|      |_______          |Z
             \--'     /\/ \|_|_|_||      |_|_|_|_|\_       |Z
              '------'            /     /  /      |_       /Z
                              \---'    |  / ²²²²²²        /Z
                            \--'     /\/  \ _____________/Z
                             '------'      \

"
[[ -z ${MOATS} ]] && MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
mkdir -p ~/.zen/tmp/${MOATS}

##################################################################################
############################################ UPDATE CAPTAIN NOSTR PROFILE (preserves existing data)
if [[ -s ~/.zen/game/nostr/${CAPTAINEMAIL}/.secret.nostr ]]; then
    YOUSER=$($MY_PATH/../tools/clyuseryomail.sh "${CAPTAINEMAIL}")

    echo "Update Captain NOSTR profile (preserves existing data)"
    
    # Use nostr_update_profile.py instead of nostr_setup_profile.py to preserve existing profile data
    # Note: We don't update all to let the captain modify them manually
    ## Use cached IPCity (Ville,Pays from ip-api.com) for NOSTR profile city field
    [[ ! -s ~/.zen/IPCity ]] && my_IPCity > ~/.zen/IPCity
    CAPTAIN_CITY=$(cat ~/.zen/IPCity 2>/dev/null)
    [[ -z "$CAPTAIN_CITY" ]] && CAPTAIN_CITY="UPlanet"
    $HOME/.zen/Astroport.ONE/tools/nostr_update_profile.py \
    "${CAPTAINEMAIL}" \
    "wss://relay.copylaradio.com" "$myRELAY" \
    --g1pub "$CAPTAING1PUB" \
    --city "$CAPTAIN_CITY" \
    --picture "${myIPFS}/ipfs/QmfBK5h8R4LjS2qMtHKze3nnFrtdm85pCbUw3oPSirik5M/logo.uplanet.png" \
    --banner "${myIPFS}/ipfs/QmVwnUSH9ZAUfHxh9FU19szax2F8ukcfJMeDfH8UQHXkrY/FutureFork.png" \
    --zencard "$(cat ~/.zen/game/players/${CAPTAINEMAIL}/.g1pub 2>/dev/null)" \
    --ipns_vault "$(cat ~/.zen/game/nostr/${CAPTAINEMAIL}/NOSTRNS 2>/dev/null)" \
    --ipfs_gw "$myIPFS" \
    --email "$CAPTAINEMAIL" >/dev/null 2>&1
    
    # Update DID document - Read from NOSTR relay (source of truth) instead of local cache
    # IMPORTANT: Preserve existing contract status (sociétaire, infrastructure, etc.)
    if [[ -f "$HOME/.zen/Astroport.ONE/tools/did_manager_nostr.sh" ]] && [[ -f "$HOME/.zen/Astroport.ONE/tools/nostr_get_events.sh" ]]; then
        echo "Reading DID document from NOSTR relay (source of truth)"
        
        # Get Captain's HEX pubkey
        CAPTAIN_HEX=$(cat ~/.zen/game/nostr/${CAPTAINEMAIL}/HEX 2>/dev/null)
        
        if [[ -n "$CAPTAIN_HEX" ]]; then
            # Query NOSTR relay for DID document (kind 30800 with d=did tag)
            did_event=$($HOME/.zen/Astroport.ONE/tools/nostr_get_events.sh \
                --kind 30800 \
                --author "$CAPTAIN_HEX" \
                --tag-d "did" \
                --limit 1 2>/dev/null | jq -c 'select(.kind == 30800)' 2>/dev/null | head -n 1)
            
            update_type="MULTIPASS"
            current_status=""
            
            if [[ -n "$did_event" ]] && command -v jq &>/dev/null; then
                # Extract contract status from DID content (NOSTR source of truth)
                did_content=$(echo "$did_event" | jq -r '.content' 2>/dev/null)
                
                if [[ -n "$did_content" && "$did_content" != "null" ]]; then
                    # Parse DID JSON content to extract contractStatus
                    current_status=$(echo "$did_content" | jq -r '.metadata.contractStatus // "active_rental"' 2>/dev/null)
                    
                    # Map contract status to update type to preserve it
                    case "$current_status" in
                        "cooperative_member_satellite")
                            update_type="SOCIETAIRE_SATELLITE"
                            echo "Preserving sociétaire satellite status from NOSTR DID"
                            ;;
                        "cooperative_member_constellation")
                            update_type="SOCIETAIRE_CONSTELLATION"
                            echo "Preserving sociétaire constellation status from NOSTR DID"
                            ;;
                        "infrastructure_contributor")
                            update_type="INFRASTRUCTURE"
                            echo "Preserving infrastructure contributor status from NOSTR DID"
                            ;;
                        "cooperative_treasury_contributor"|"cooperative_rnd_contributor"|"cooperative_assets_contributor")
                            echo "Preserving contribution status from NOSTR DID: ${current_status}"
                            # Check services to determine if also sociétaire
                            has_satellite=$(echo "$did_content" | jq -r '.metadata.services // ""' 2>/dev/null | grep -q "satellite" && echo "yes" || echo "no")
                            has_constellation=$(echo "$did_content" | jq -r '.metadata.services // ""' 2>/dev/null | grep -q "constellation" && echo "yes" || echo "no")
                            if [[ "$has_constellation" == "yes" ]]; then
                                update_type="SOCIETAIRE_CONSTELLATION"
                            elif [[ "$has_satellite" == "yes" ]]; then
                                update_type="SOCIETAIRE_SATELLITE"
                            fi
                            ;;
                        "active_rental"|""|"null")
                            update_type="MULTIPASS"
                            ;;
                        *)
                            echo "Unknown contract status from NOSTR DID: ${current_status}, using MULTIPASS"
                            update_type="MULTIPASS"
                            ;;
                    esac
                    
                    echo "DID found in NOSTR relay, updating with preserved status"
                else
                    echo "DID event found but content is empty, creating new DID"
                fi
            else
                echo "No DID document found in NOSTR relay, creating new DID with default type"
            fi
            
            # Update or create DID document
            $HOME/.zen/Astroport.ONE/tools/did_manager_nostr.sh update "${CAPTAINEMAIL}" "$update_type" "0" "0" >/dev/null 2>&1
            
            if [[ $? -eq 0 ]]; then
                echo "✅ DID document updated for Captain (type: ${update_type})"
            else
                echo "⚠️ Failed to update DID document for Captain"
            fi
        else
            echo "⚠️ Captain HEX not found, skipping DID update"
        fi
    else
        echo "⚠️ did_manager_nostr.sh or nostr_get_events.sh not found, skipping DID update"
    fi

    ## FOLLOW EVERY NOSTR CARD AND ACTIVE UMAP NODE (single kind3 event)
    ## Note: List is built from existing ~/.zen/game/nostr/*/HEX only. When an account
    ## is destroyed (nostr_DESTROY_TW.sh), its directory is removed, so that HEX is
    ## automatically excluded on next DRAGON run; captain's kind3 is republished without it.
    [[ -z "${NSEC:-}" ]] && NSEC=$(grep -oP 'NSEC=\K[^;]+' ~/.zen/game/nostr/${CAPTAINEMAIL}/.secret.nostr 2>/dev/null)
    nostrhex=($(cat ~/.zen/game/nostr/*@*.*/HEX 2>/dev/null))
    umaphex=()
    sectorhex=()
    regionhex=()
    if [[ -d ~/.zen/tmp/${IPFSNODEID}/UPLANET ]]; then
        umaphex=($(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_*/*/*/HEX 2>/dev/null))
        sectorhex=($(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/SECTORS/_*/*/SECTORHEX 2>/dev/null))
        regionhex=($(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/REGIONS/_*_*/REGIONHEX 2>/dev/null))
    fi
    ## Same-uplanet captains (kind 30850, swarm_id = UPLANETG1PUB, station != me) so Captain follows other captains on NOSTR
    captainhex=()
    if [[ -n "${UPLANETG1PUB:-}" ]] && [[ -f "$HOME/.zen/Astroport.ONE/tools/nostr_get_events.sh" ]] && command -v jq &>/dev/null; then
        UPLANET_30850=$("$HOME/.zen/Astroport.ONE/tools/nostr_get_events.sh" --kind 30850 --limit 300 2>/dev/null)
        if [[ -n "$UPLANET_30850" ]]; then
            while read -r pub; do
                [[ -n "$pub" ]] && captainhex+=("$pub")
            done < <(echo "$UPLANET_30850" | jq -r --arg sid "$UPLANETG1PUB" --arg me "$IPFSNODEID" '
                select(
                    ([(.tags[]? | select(.[0]=="swarm_id"))] | .[0][1]) == $sid
                    and ([(.tags[]? | select(.[0]=="station"))] | .[0][1]) != $me
                ) | .pubkey
            ' 2>/dev/null)
        fi
    fi
    # Combine all lists (NOSTR cards, UMAP, SECTOR, REGION nodes, same-uplanet captains)
    allhex=("${nostrhex[@]}" "${umaphex[@]}" "${sectorhex[@]}" "${regionhex[@]}" "${captainhex[@]}")
    
    if [[ ${#allhex[@]} -gt 0 ]] && [[ -n "${NSEC:-}" ]]; then
        echo "Following ${#nostrhex[@]} NOSTR cards, ${#umaphex[@]} UMAP, ${#sectorhex[@]} SECTOR, ${#regionhex[@]} REGION, ${#captainhex[@]} same-uplanet captains (single kind3)"
        $HOME/.zen/Astroport.ONE/tools/nostr_follow.sh "$NSEC" "${allhex[@]}" >/dev/null 2>&1
    fi
fi
##################################################################################
## DISTRIBUTE DRAGON SSH WOT AUTHORIZED KEYS
##################################################################################
######################################## $HOME/.zen/game/(A)(My)_boostrap_ssh.txt
SSHAUTHFILE="$HOME/.zen/Astroport.ONE/A_boostrap_ssh.txt"
#~ [[ -s $HOME/.zen/game/My_boostrap_ssh.txt ]] \
    #~ && SSHAUTHFILE="$HOME/.zen/game/My_boostrap_ssh.txt" ### AUTHORIZED KEYS ARE CAPTAIN from same UPLANET
##################################################################################
[[ -s ~/.ssh/authorized_keys ]] \
    && cp ~/.ssh/authorized_keys ~/.zen/tmp/${MOATS}/authorized_keys \
    || echo "# ASTRO # ~/.ssh/authorized_keys" > ~/.zen/tmp/${MOATS}/authorized_keys

## Remove old same-uplanet captain keys (tagged with " uplanet:") 
## so they are replaced by current uplanet's captains (if station changed UPlanet)
grep -v " uplanet:" ~/.zen/tmp/${MOATS}/authorized_keys > ~/.zen/tmp/${MOATS}/authorized_keys.no_uplanet 2>/dev/null
mv ~/.zen/tmp/${MOATS}/authorized_keys.no_uplanet ~/.zen/tmp/${MOATS}/authorized_keys 2>/dev/null || true

## Ajout clefs publiques de SSHAUTHFILE
while IFS= read -r line
do
    LINE=$(echo "$line" | grep "ssh-ed25519" | grep -Ev "#") # Remove # & not ssh-ed25519
    [[ ! ${LINE} ]] && continue
    if [[ ! $(cat ~/.zen/tmp/${MOATS}/authorized_keys | grep "${LINE}") ]]
    then
        echo "Adding SSH key to authorized_keys"
        mkdir -p ~/.ssh && echo "${LINE}" >> ~/.zen/tmp/${MOATS}/authorized_keys
    else
        echo "SSH key already trusted"
    fi
done < ${SSHAUTHFILE} ## INITIALIZED DURING BLOOM.Me PRIVATE SWARM ACTIVATION

## ADDING ${HOME}/.zen/game/players/${PLAYER}/ssh.pub (made during PLAYER.refresh)
cat ${HOME}/.zen/game/players/*/ssh.pub >> ~/.zen/tmp/${MOATS}/authorized_keys 2>/dev/null

## ADDING SSH KEYS OF CAPTAINS FROM SAME UPLANET (kind 30850 economic-health, swarm_id = UPLANETG1PUB)
## Links captains of the same uplanet for P2P SSH (see ECONOMY.broadcast.sh ssh_pub tag and economy.Swarm.html)
if [[ -n "${UPLANETG1PUB:-}" ]] && [[ -f "$HOME/.zen/Astroport.ONE/tools/nostr_get_events.sh" ]] && command -v jq &>/dev/null; then
    UPLANET_30850=$("$HOME/.zen/Astroport.ONE/tools/nostr_get_events.sh" --kind 30850 --limit 300 2>/dev/null)
    if [[ -n "$UPLANET_30850" ]]; then
        echo "$UPLANET_30850" | jq -c --arg sid "$UPLANETG1PUB" --arg me "$IPFSNODEID" '
            select(
                ([(.tags[]? | select(.[0]=="swarm_id"))] | .[0][1]) == $sid
                and ([(.tags[]? | select(.[0]=="station"))] | .[0][1]) != $me
            )
        ' 2>/dev/null | while read -r ev; do
            ssh_pub=$(echo "$ev" | jq -r '[.tags[]? | select(.[0]=="ssh_pub")] | .[0][1] // empty' 2>/dev/null)
            if [[ -n "$ssh_pub" ]] && echo "$ssh_pub" | grep -q "ssh-ed25519"; then
                # Comment with uplanet id so these keys can be removed if station changes UPlanet (grep -v "uplanet:...")
                ssh_line="${ssh_pub} uplanet:${UPLANETG1PUB:0:8}"
                if ! grep -qF "$ssh_pub" ~/.zen/tmp/${MOATS}/authorized_keys 2>/dev/null; then
                    echo "Adding same-uplanet captain SSH key to authorized_keys (uplanet:${UPLANETG1PUB:0:8})"
                    echo "$ssh_line" >> ~/.zen/tmp/${MOATS}/authorized_keys
                fi
            fi
        done
    fi
fi

### REMOVING DUPLICATION (NO ORDER CHANGING)
awk '!seen[$0]++' ~/.zen/tmp/${MOATS}/authorized_keys > ~/.zen/tmp/${MOATS}/authorized_keys.clean
cat ~/.zen/tmp/${MOATS}/authorized_keys.clean > ~/.ssh/authorized_keys
echo "##################################################################################"
echo "SSH authorized_keys updated"
cat ~/.ssh/authorized_keys
echo "##################################################################################"
##################################################################################
cp ~/.zen/install.errors.log ~/.zen/tmp/${IPFSNODEID}/ 2>/dev/null

##################################################################################
##################################################################################
# HELPER : vrai si un processus NATIF (pas ipfs) écoute sur le port
# Évite de republier dans le swarm un tunnel IPFS P2P déjà établi (tunnel→tunnel)
_is_native_process() {
    local _PORT=$1
    # 1. Le port doit être en écoute
    ss -tln 2>/dev/null | grep -qw ":${_PORT}" || return 1
    # 2. Récupérer le PID du process en écoute sur ce port
    local _PID
    _PID=$(ss -tlnp 2>/dev/null | awk -v p=":${_PORT} " '$0~p {match($0,/pid=([0-9]+)/,a); if(a[1]) {print a[1]; exit}}')
    # Si ss ne donne pas le PID (pas de sudo), essayer lsof
    [[ -z "$_PID" ]] && _PID=$(lsof -t -i ":${_PORT}" -sTCP:LISTEN 2>/dev/null | head -1)
    # Pas de PID détectable → supposer service natif (meilleure hypothèse)
    [[ -z "$_PID" ]] && return 0
    # 3. Lire le nom du processus
    local _PROC; _PROC=$(cat "/proc/${_PID}/comm" 2>/dev/null)
    # Si c'est `ipfs` → c'est un ipfs p2p forward (tunnel client) → PAS un service natif
    [[ "$_PROC" == "ipfs" ]] && {
        echo "  [SKIP] Port ${_PORT}: occupé par 'ipfs' (tunnel forward entrant) — tunnel→tunnel évité"
        return 1
    }
    return 0
}

##################################################################################
# FONCTION GÉNÉRATRICE DE TUNNEL (Double Bind)
##################################################################################
# $1: Port, $2: Nom court (ex: paperclip), $3: Description
generate_p2p_service() {
    local PORT=$1
    local SLUG=$2
    local NAME=$3
    local CHANNEL="/x/${SLUG}-${IPFSNODEID}"

    # Vérification : port en écoute ET processus NATIF (pas un tunnel ipfs forward)
    if _is_native_process "${PORT}"; then
        echo "Publie le service $NAME sur $CHANNEL"
        
        # Le serveur écoute
        [[ ! $(ipfs p2p ls | grep "$CHANNEL") ]] \
            && ipfs p2p listen "$CHANNEL" /ip4/127.0.0.1/tcp/${PORT}

        # Génération du script client x_service.sh
        echo '#!/bin/bash
        # Détection dynamique de l IP Docker chez le CLIENT
        DOCKER_IP=$(ip addr show docker0 2>/dev/null | grep -oP "(?<=inet\s)\d+(\.\d+){3}" || echo "172.17.0.1")
        NODE_ID="'${IPFSNODEID}'"
        LPORT="'${PORT}'"
        PROTO="'$CHANNEL'"
        NAME="'$NAME'"

        check_bind() { ipfs p2p ls | grep "$PROTO" | grep "$1" > /dev/null; }

        if [[ "${1,,}" == "off" || "${1,,}" == "stop" ]]; then
            echo "Closing $NAME tunnel..."
            ipfs p2p close -p "$PROTO"
            exit 0
        fi

        # Priorité au service local : si le port est occupé par un process local
        # (et qu'aucun tunnel IPFS n'est déjà établi), le service natif prend la main.
        if ! check_bind "127.0.0.1" && ss -tln 2>/dev/null | grep -qw ":$LPORT"; then
            echo "$NAME : port $LPORT occupé localement — service natif prioritaire, tunnel non requis."
            exit 0
        fi

        ipfs --timeout=10s ping -n 2 "/p2p/$NODE_ID" > /dev/null
        if [[ $? == 0 ]]; then
            echo "Establishing Double Tunnel for $NAME ($NODE_ID)..."
            if ! check_bind "127.0.0.1"; then
                ipfs p2p forward "$PROTO" "/ip4/127.0.0.1/tcp/$LPORT" "/p2p/$NODE_ID"
                echo "  [OK] Host Access: http://localhost:$LPORT"
            fi
            if ! check_bind "$DOCKER_IP"; then
                ipfs p2p forward "$PROTO" "/ip4/$DOCKER_IP/tcp/$LPORT" "/p2p/$NODE_ID"
                echo "  [OK] Docker Access: http://$DOCKER_IP:$LPORT"
            fi
        else
            echo "ERROR: Node $NODE_ID unreachable."
            exit 1
        fi
        ' > ~/.zen/tmp/${IPFSNODEID}/x_${SLUG}.sh
        
        chmod +x ~/.zen/tmp/${IPFSNODEID}/x_${SLUG}.sh
        echo "  -> x_${SLUG}.sh généré"
    fi
}

##################################################################################
# WRAPPER publish_service : respecte DRAGON_PRIVATE_SERVICES depuis ~/.zen/Astroport.ONE/.env
# (my.sh source déjà .env, donc DRAGON_PRIVATE_SERVICES est disponible ici)
publish_service() {
    local _slug="$2"
    if [[ -n "${DRAGON_PRIVATE_SERVICES:-}" ]] && \
       echo " ${DRAGON_PRIVATE_SERVICES} " | grep -qw " ${_slug} "; then
        echo "SKIP ${_slug} (privé — DRAGON_PRIVATE_SERVICES)"
        return 0
    fi
    publish_service "$@"
}
##################################################################################
# DÉTECTION ET PUBLICATION DES SERVICES (ai-company + standard)
# Architecture des ports (voir firewall.sh pour la politique UFW) :
#   NPM admin        : 81
#   NextCloud Apache : 8001 (proxied NPM → cloud.DOMAIN)
#   Open WebUI       : 8000 (Interface web IA)
#   Perplexica       : 3002
#   Webtop           : 3000 HTTP | 3001 HTTPS — accès SSH tunnel recommandé
##################################################################################

## ── Profil ai-company : Stack IA Swarm ──────────────────────────
# Paperclip (3100)
publish_service 3100 "paperclip" "Paperclip AI Agents"

# Open WebUI interface IA (8000) — (supporte Ollama natif)
publish_service 8000 "open-webui" "Open WebUI Interface IA"

## Port 8001 : NextCloud Apache uniquement (proxied NPM → cloud.DOMAIN)
if ss -tln 2>/dev/null | grep -q ":8001 "; then
    publish_service 8001 "nextcloud-app" "NextCloud Apache App (via NPM cloud.DOMAIN)"
fi

# --- NOT SHARED --- used locally as ollama proxy for paperclip
# LiteLLM proxy (8010)
# generate_p2p_service 8010 "litellm" "LiteLLM Proxy"

# Qdrant vector database (6333) -- could be hidden too
publish_service 6333 "qdrant" "Qdrant VectorDB"

# Ollama LLM API (11434)
if pgrep ollama >/dev/null 2>&1 || ss -tln 2>/dev/null | grep -q ":11434 "; then
    publish_service 11434 "ollama" "Ollama LLM API"
fi

## ── Services standard ───────────────────────────────────────────────

# SSH (toujours prioritaire)
SSHPORT=$(grep -E "^Port " /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' | head -1)
[[ -z "$SSHPORT" ]] && SSHPORT=22
publish_service "$SSHPORT" "ssh" "SSH Remote Access"

# Nginx Proxy Manager admin (port 81)
publish_service 81 "npm" "Nginx Proxy Manager Admin"

# NextCloud AIO admin setup (port 8443 — HTTPS auto-signé)
publish_service 8443 "nextcloud-aio" "NextCloud AIO Admin Setup"

## ── Webtop KasmVNC (VDI) ────────────────────────────────────────────
## ⚠️  Port 3001 = Webtop HTTPS
## Accès recommandé via SSH tunnel :
##   ssh -L 3000:localhost:3000 user@HOST
if docker ps --format '{{.Image}}' 2>/dev/null | grep -q 'linuxserver/webtop'; then
    publish_service 3000 "webtop-http"  "Webtop KasmVNC HTTP"
    publish_service 3001 "webtop-https" "Webtop KasmVNC HTTPS"
fi

## ── Services complémentaires ────────────────────────────────────────

# ComfyUI (8188)
if systemctl is-active comfyui.service >/dev/null 2>&1; then
    publish_service 8188 "comfyui" "ComfyUI"
fi

# Orpheus TTS (5005)
if docker ps 2>/dev/null | grep -q orpheus; then
    publish_service 5005 "orpheus" "Orpheus TTS"
fi

# Perplexica Search (3002)
if docker ps 2>/dev/null | grep -q perplexica; then
    publish_service 3002 "perplexica" "Perplexica Search"
fi

##################################################################################
echo "Active Swarm Tunnels:"
ipfs p2p ls
echo "DRAGON WOKE UP - AI Swarm is Ready"
##################################################################################
rm -f ~/.zen/tmp/${IPFSNODEID}/x_cups.sh 2>/dev/null
exit 0
## ── CUPS (désactivé — décommentez si imprimante USB) ─────────────────────────
## Pour activer, créez x_cups.sh manuellement ou décommentez tools/x_cups.sh.template
