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
    rm ~/.zen/tmp/${IPFSNODEID}/x_*.sh 2>/dev/null
    rm ~/.zen/tmp/${IPFSNODEID}/y_ssh.pub 2>/dev/null
    rm ~/.zen/tmp/${IPFSNODEID}/z_ssh.pub 2>/dev/null
    echo "STOP" && exit 0
fi


############################################
## Y LEVEL = SSH PUBKEY OVER IPFS y_ssh.pub
## https://pad.p2p.legal/keygen
if [[ -s ~/.ssh/id_ed25519.pub ]]; then
    ## TEST IF TRANSMUTATION IS MADE
    YIPNS=$(${MY_PATH}/../tools/ssh_to_g1ipfs.py "$(cat ~/.ssh/id_ed25519.pub)")
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

## DRAGONz PGP style
gpg --export-ssh-key $(cat ~/.zen/game/players/.current/.player) 2>/dev/null > ~/.zen/tmp/${IPFSNODEID}/z_ssh.pub
[[ ! -s ~/.zen/tmp/${IPFSNODEID}/z_ssh.pub ]] && rm ~/.zen/tmp/${IPFSNODEID}/z_ssh.pub 2>/dev/null # remove empty file

## PRODUCE SWARM SEED PART - used to create swarm.key
if [[ -s ~/.zen/tmp/${IPFSNODEID}/z_ssh.pub || -s ~/.zen/tmp/${IPFSNODEID}/y_ssh.pub ]]; then
    [[ ! -s ~/.zen/tmp/${IPFSNODEID}/_swarm.egg.txt ]] \
        && head -c 12 /dev/urandom | od -t x1 -A none - | tr -d ' ' \
                > ~/.zen/tmp/${IPFSNODEID}/_swarm.egg.txt
fi

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
    ${MY_PATH}/../tools/nostr_update_profile.py \
    "${CAPTAINEMAIL}" \
    "wss://relay.copylaradio.com" "$myRELAY" \
    --g1pub "$CAPTAING1PUB" \
    --picture "${myIPFS}/ipfs/QmfBK5h8R4LjS2qMtHKze3nnFrtdm85pCbUw3oPSirik5M/logo.uplanet.png" \
    --banner "${myIPFS}/ipfs/QmVwnUSH9ZAUfHxh9FU19szax2F8ukcfJMeDfH8UQHXkrY/FutureFork.png" \
    --zencard "$(cat ~/.zen/game/players/${CAPTAINEMAIL}/.g1pub 2>/dev/null)" \
    --ipns_vault "$(cat ~/.zen/game/nostr/${CAPTAINEMAIL}/NOSTRNS 2>/dev/null)" \
    --ipfs_gw "$myIPFS" \
    --email "$CAPTAINEMAIL" >/dev/null 2>&1
    
    # Update DID document - Read from NOSTR relay (source of truth) instead of local cache
    # IMPORTANT: Preserve existing contract status (sociétaire, infrastructure, etc.)
    if [[ -f "${MY_PATH}/../tools/did_manager_nostr.sh" ]] && [[ -f "${MY_PATH}/../tools/nostr_get_events.sh" ]]; then
        echo "Reading DID document from NOSTR relay (source of truth)"
        
        # Get Captain's HEX pubkey
        CAPTAIN_HEX=$(cat ~/.zen/game/nostr/${CAPTAINEMAIL}/HEX 2>/dev/null)
        
        if [[ -n "$CAPTAIN_HEX" ]]; then
            # Query NOSTR relay for DID document (kind 30800 with d=did tag)
            did_event=$(${MY_PATH}/../tools/nostr_get_events.sh \
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
            ${MY_PATH}/../tools/did_manager_nostr.sh update "${CAPTAINEMAIL}" "$update_type" "0" "0" >/dev/null 2>&1
            
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
    [[ -z "${NSEC:-}" ]] && NSEC=$(grep -oP 'NSEC=\K[^;]+' ~/.zen/game/nostr/${CAPTAINEMAIL}/.secret.nostr 2>/dev/null)
    nostrhex=($(cat ~/.zen/game/nostr/*@*.*/HEX 2>/dev/null))
    umaphex=()
    if [[ -d ~/.zen/tmp/${IPFSNODEID}/UPLANET ]]; then
        umaphex=($(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_*/*/*/HEX 2>/dev/null))
    fi
    ## Same-uplanet captains (kind 30850, swarm_id = UPLANETG1PUB, station != me) so Captain follows other captains on NOSTR
    captainhex=()
    if [[ -n "${UPLANETG1PUB:-}" ]] && [[ -f "${MY_PATH}/../tools/nostr_get_events.sh" ]] && command -v jq &>/dev/null; then
        UPLANET_30850=$("${MY_PATH}/../tools/nostr_get_events.sh" --kind 30850 --limit 300 2>/dev/null)
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
    # Combine all lists (NOSTR cards, UMAP nodes, same-uplanet captains)
    allhex=("${nostrhex[@]}" "${umaphex[@]}" "${captainhex[@]}")
    
    if [[ ${#allhex[@]} -gt 0 ]] && [[ -n "${NSEC:-}" ]]; then
        echo "Following ${#nostrhex[@]} NOSTR cards, ${#umaphex[@]} UMAP nodes, ${#captainhex[@]} same-uplanet captains (single kind3)"
        ${MY_PATH}/../tools/nostr_follow.sh "$NSEC" "${allhex[@]}" >/dev/null 2>&1
    fi
fi
##################################################################################

##################################################################################
##################################################################################
############################################ $HOME/.zen/game/My_boostrap_ssh.txt
## DISTRIBUTE DRAGON SSH WOT AUTHORIZED KEYS
SSHAUTHFILE="${MY_PATH}/../A_boostrap_ssh.txt"
[[ -s $HOME/.zen/game/My_boostrap_ssh.txt ]] && SSHAUTHFILE="$HOME/.zen/game/My_boostrap_ssh.txt"
############################################
[[ -s ~/.ssh/authorized_keys ]] \
    && cp ~/.ssh/authorized_keys ~/.zen/tmp/${MOATS}/authorized_keys \
    || echo "# ASTRO # ~/.ssh/authorized_keys" > ~/.zen/tmp/${MOATS}/authorized_keys

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
if [[ -n "${UPLANETG1PUB:-}" ]] && [[ -f "${MY_PATH}/../tools/nostr_get_events.sh" ]] && command -v jq &>/dev/null; then
    UPLANET_30850=$("${MY_PATH}/../tools/nostr_get_events.sh" --kind 30850 --limit 300 2>/dev/null)
    if [[ -n "$UPLANET_30850" ]]; then
        echo "$UPLANET_30850" | jq -c --arg sid "$UPLANETG1PUB" --arg me "$IPFSNODEID" '
            select(
                ([(.tags[]? | select(.[0]=="swarm_id"))] | .[0][1]) == $sid
                and ([(.tags[]? | select(.[0]=="station"))] | .[0][1]) != $me
            )
        ' 2>/dev/null | while read -r ev; do
            ssh_pub=$(echo "$ev" | jq -r '[.tags[]? | select(.[0]=="ssh_pub")] | .[0][1] // empty' 2>/dev/null)
            if [[ -n "$ssh_pub" ]] && echo "$ssh_pub" | grep -q "ssh-ed25519"; then
                if ! grep -qF "$ssh_pub" ~/.zen/tmp/${MOATS}/authorized_keys 2>/dev/null; then
                    echo "Adding same-uplanet captain SSH key to authorized_keys"
                    echo "$ssh_pub" >> ~/.zen/tmp/${MOATS}/authorized_keys
                fi
            fi
        done
    fi
fi
### REMOVING DUPLICATION (NO ORDER CHANGING)
awk '!seen[$0]++' ~/.zen/tmp/${MOATS}/authorized_keys > ~/.zen/tmp/${MOATS}/authorized_keys.clean
cat ~/.zen/tmp/${MOATS}/authorized_keys.clean > ~/.ssh/authorized_keys
echo "SSH authorized_keys updated"
##################################################################################
##################################################################################
cp ~/.zen/install.errors.log ~/.zen/tmp/${IPFSNODEID}/ 2>/dev/null

##################################################################################
############################################
### FORWARD SSH PORT over /x/ssh-${IPFSNODEID}
############################################
## Detect local SSH port (default 22)
## 1. Read from sshd_config (most reliable)
SSHPORT=$(grep -E "^Port " /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' | head -1)
## 2. If not found, check if port 22 is listening
[[ -z "$SSHPORT" ]] && ss -tln 2>/dev/null | grep -qE ":22\s" && SSHPORT=22
## 3. Default to 22
[[ -z "$SSHPORT" ]] && SSHPORT=22
echo "SSH tunnel: /x/ssh-${IPFSNODEID} (local SSH port: ${SSHPORT})"
[[ ! $(ipfs p2p ls | grep "/x/ssh-${IPFSNODEID}") ]] \
    && ipfs p2p listen /x/ssh-${IPFSNODEID} /ip4/127.0.0.1/tcp/${SSHPORT}
############################################
## PREPARE x_ssh.sh
## REMOTE ACCESS COMMAND FROM DRAGONS
############################################
PORT=22000
PORT=$((PORT+${RANDOM:0:3}))
echo '#!/bin/bash
if [[ ! $(ipfs p2p ls | grep x/ssh-'${IPFSNODEID}') ]]; then
    ipfs --timeout=10s ping -n 4 /p2p/'${IPFSNODEID}'
    [[ $? == 0 ]] \
        && ipfs p2p forward /x/ssh-'${IPFSNODEID}' /ip4/127.0.0.1/tcp/'${PORT}' /p2p/'${IPFSNODEID}' \
        && echo "ssh '${USER}'@127.0.0.1 -p '${PORT}'" \
        || echo "CONTACT IPFSNODEID FAILED - ERROR -"
else
    echo "Tunnel /x/ssh '${PORT}' already active..."
    echo "ssh '${USER}'@127.0.0.1 -p '${PORT}'"
    echo "ipfs p2p close -p /x/ssh-'${IPFSNODEID}'"
fi
' > ~/.zen/tmp/${IPFSNODEID}/x_ssh.sh

echo "ipfs cat /ipns/${IPFSNODEID}/x_ssh.sh | bash"
chmod +x ~/.zen/tmp/${IPFSNODEID}/x_ssh.sh


############################################
## PREPARE x_ollama.sh
## REMOTE ACCESS COMMAND FROM DRAGONS
############################################
rm -f ~/.zen/tmp/${IPFSNODEID}/x_ollama.sh 2>/dev/null
if [[ ! -z $(pgrep ollama) ]]; then
    PORT=11434
    echo "Ollama tunnel: /x/ollama-${IPFSNODEID}"
    [[ ! $(ipfs p2p ls | grep "/x/ollama-${IPFSNODEID}") ]] \
        && ipfs p2p listen /x/ollama-${IPFSNODEID} /ip4/127.0.0.1/tcp/${PORT}

    echo '#!/bin/bash
    if [[ ! $(ipfs p2p ls | grep x/ollama-'${IPFSNODEID}') ]]; then
        ipfs --timeout=10s ping -n 4 /p2p/'${IPFSNODEID}'
        [[ $? == 0 ]] \
            && ipfs p2p forward /x/ollama-'${IPFSNODEID}' /ip4/127.0.0.1/tcp/'${PORT}' /p2p/'${IPFSNODEID}' \
            && echo "OLLAMA PORT FOR '${IPFSNODEID}'" \
            && export OLLAMA_API_BASE="http://127.0.0.1:'${PORT}'" \
            && echo "OLLAMA_API_BASE=$OLLAMA_API_BASE" \
            || echo "CONTACT IPFSNODEID FAILED - ERROR -"
    else
            echo "Tunnel /x/ollama '${PORT}' already active..."
            echo "ipfs p2p close -p /x/ollama-'${IPFSNODEID}'"
    fi
    ' > ~/.zen/tmp/${IPFSNODEID}/x_ollama.sh
    #~ cat ~/.zen/tmp/${IPFSNODEID}/x_ollama.sh

    echo "ipfs cat /ipns/${IPFSNODEID}/x_ollama.sh | bash"
    chmod +x ~/.zen/tmp/${IPFSNODEID}/x_ollama.sh

fi

############################################
## PREPARE x_comfyui.sh
## REMOTE ACCESS COMMAND FROM DRAGONS
############################################
rm -f ~/.zen/tmp/${IPFSNODEID}/x_comfyui.sh 2>/dev/null
if [[ ! -z $(systemctl status comfyui.service 2>/dev/null | grep "active (running)") ]]; then
    PORT=8188
    echo "ComfyUI tunnel: /x/comfyui-${IPFSNODEID}"
    [[ ! $(ipfs p2p ls | grep "/x/comfyui-${IPFSNODEID}") ]] \
        && ipfs p2p listen /x/comfyui-${IPFSNODEID} /ip4/127.0.0.1/tcp/${PORT}

    echo '#!/bin/bash
    if [[ ! $(ipfs p2p ls | grep x/comfyui-'${IPFSNODEID}') ]]; then
        ipfs --timeout=10s ping -n 4 /p2p/'${IPFSNODEID}'
        [[ $? == 0 ]] \
            && ipfs p2p forward /x/comfyui-'${IPFSNODEID}' /ip4/127.0.0.1/tcp/'${PORT}' /p2p/'${IPFSNODEID}' \
            && echo "xdg-open http://127.0.0.1:'${PORT}'" \
            || echo "CONTACT IPFSNODEID FAILED - ERROR -"
    else
            echo "Tunnel /x/comfyui '${PORT}' already active..."
            echo "ipfs p2p close -p /x/comfyui-'${IPFSNODEID}'"
    fi
    ' > ~/.zen/tmp/${IPFSNODEID}/x_comfyui.sh

    echo "ipfs cat /ipns/${IPFSNODEID}/x_comfyui.sh | bash"
    chmod +x ~/.zen/tmp/${IPFSNODEID}/x_comfyui.sh

fi

############################################
## PREPARE x_orpheus.sh
## https://chaton.g1sms.fr/fr/blog/orpheus-fastapi-tts
## REMOTE ACCESS COMMAND FROM DRAGONS
############################################
rm -f ~/.zen/tmp/${IPFSNODEID}/x_orpheus.sh 2>/dev/null
if [[ ! -z $(docker ps | grep orpheus) ]]; then
    PORT=5005

    echo "Orpheus tunnel: /x/orpheus-${IPFSNODEID}"
    [[ ! $(ipfs p2p ls | grep "/x/orpheus-${IPFSNODEID}") ]] \
        && ipfs p2p listen /x/orpheus-${IPFSNODEID} /ip4/127.0.0.1/tcp/${PORT}

    echo '#!/bin/bash
    if [[ ! $(ipfs p2p ls | grep x/orpheus-'${IPFSNODEID}') ]]; then
        ipfs --timeout=10s ping -n 4 /p2p/'${IPFSNODEID}'
        [[ $? == 0 ]] \
            && ipfs p2p forward /x/orpheus-'${IPFSNODEID}' /ip4/127.0.0.1/tcp/'${PORT}' /p2p/'${IPFSNODEID}' \
            && echo "xdg-open http://127.0.0.1:'${PORT}'" \
            || echo "CONTACT IPFSNODEID FAILED - ERROR -"
    else
            echo "Tunnel /x/orpheus '${PORT}' already active..."
            echo "ipfs p2p close -p /x/orpheus-'${IPFSNODEID}'"
    fi
    ' > ~/.zen/tmp/${IPFSNODEID}/x_orpheus.sh

    echo "ipfs cat /ipns/${IPFSNODEID}/x_orpheus.sh | bash"
    chmod +x ~/.zen/tmp/${IPFSNODEID}/x_orpheus.sh

fi


############################################
## PREPARE x_perplexica.sh
## REMOTE ACCESS COMMAND FROM DRAGONS
############################################
rm -f ~/.zen/tmp/${IPFSNODEID}/x_perplexica.sh 2>/dev/null
if [[ ! -z $(docker ps | grep perplexica) ]]; then
    PORT=3001

    echo "Perplexica tunnel: /x/perplexica-${IPFSNODEID}"
    [[ ! $(ipfs p2p ls | grep "/x/perplexica-${IPFSNODEID}") ]] \
        && ipfs p2p listen /x/perplexica-${IPFSNODEID} /ip4/127.0.0.1/tcp/${PORT}

    echo '#!/bin/bash
    if [[ ! $(ipfs p2p ls | grep x/perplexica-'${IPFSNODEID}') ]]; then
        ipfs --timeout=10s ping -n 4 /p2p/'${IPFSNODEID}'
        [[ $? == 0 ]] \
            && ipfs p2p forward /x/perplexica-'${IPFSNODEID}' /ip4/127.0.0.1/tcp/'${PORT}' /p2p/'${IPFSNODEID}' \
            && echo "xdg-open http://127.0.0.1:'${PORT}'" \
            || echo "CONTACT IPFSNODEID FAILED - ERROR -"
    else
            echo "Tunnel /x/perplexica '${PORT}' already active..."
            echo "ipfs p2p close -p /x/perplexica-'${IPFSNODEID}'"
    fi
    ' > ~/.zen/tmp/${IPFSNODEID}/x_perplexica.sh

    echo "ipfs cat /ipns/${IPFSNODEID}/x_perplexica.sh | bash"
    chmod +x ~/.zen/tmp/${IPFSNODEID}/x_perplexica.sh

fi

############################################
## PREPARE x_strfry.sh
## REMOTE ACCESS COMMAND FROM DRAGONS FOR STRFRY RELAY
############################################
rm -f ~/.zen/tmp/${IPFSNODEID}/x_strfry.sh 2>/dev/null
if [[ ! -z $(ps auxf | grep "strfry relay" | grep -v grep) ]]; then
    PORT=7777

    echo "STRFRY relay tunnel: /x/strfry-${IPFSNODEID}"
    [[ ! $(ipfs p2p ls | grep "/x/strfry-${IPFSNODEID}") ]] \
        && ipfs p2p listen /x/strfry-${IPFSNODEID} /ip4/127.0.0.1/tcp/${PORT}

    echo '#!/bin/bash
    if [[ ! $(ipfs p2p ls | grep x/strfry-'${IPFSNODEID}') ]]; then
        ipfs --timeout=10s ping -n 4 /p2p/'${IPFSNODEID}'
        [[ $? == 0 ]] \
            && ipfs p2p forward /x/strfry-'${IPFSNODEID}' /ip4/127.0.0.1/tcp/9999 /p2p/'${IPFSNODEID}' \
            && echo "STRFRY RELAY PORT FOR '${IPFSNODEID}'" \
            && echo "WebSocket URL: ws://127.0.0.1:9999" \
            && echo "NOSTR Relay accessible via IPFS P2P tunnel on local port 9999" \
            && echo "Local relay: ws://127.0.0.1:9999" \
            || echo "CONTACT IPFSNODEID FAILED - ERROR -"
    else
            echo "Tunnel /x/strfry already active..."
            echo "ipfs p2p close -p /x/strfry-'${IPFSNODEID}'"
    fi
    ' > ~/.zen/tmp/${IPFSNODEID}/x_strfry.sh

    echo "ipfs cat /ipns/${IPFSNODEID}/x_strfry.sh | bash"
    chmod +x ~/.zen/tmp/${IPFSNODEID}/x_strfry.sh

fi


############################################
## PREPARE x_cups.sh
## REMOTE ACCESS TO CUPS PRINT SERVICE
## Detects USB printer (/dev/usb/lp*) or active CUPS service
############################################
rm -f ~/.zen/tmp/${IPFSNODEID}/x_cups.sh 2>/dev/null
LP=$(ls /dev/usb/lp* 2>/dev/null)
CUPS_ACTIVE=$(systemctl is-active cups 2>/dev/null)
if [[ ! -z "$LP" || "$CUPS_ACTIVE" == "active" ]]; then
    PORT=631

    echo "CUPS print service tunnel: /x/cups-${IPFSNODEID}"
    [[ -n "$LP" ]] && echo "Detected USB printer: $LP"
    [[ ! $(ipfs p2p ls | grep "/x/cups-${IPFSNODEID}") ]] \
        && ipfs p2p listen /x/cups-${IPFSNODEID} /ip4/127.0.0.1/tcp/${PORT}

    ## Get short IPFSNODEID for printer naming (last 8 chars)
    NODEID_SHORT="${IPFSNODEID: -8}"
    
    echo '#!/bin/bash
############################################
## x_cups.sh - CUPS Print Service Tunnel
## Forward CUPS port from Astroport station
## Auto-configures remote printers locally
############################################
## Usage: x_cups.sh [command]
##   (no arg) : setup tunnel and auto-add printers
##   list     : list available remote printers
##   remove   : remove astro printers and close tunnel
##   print <file> [printer] : print file to remote printer
############################################
IPFSNODEID="'${IPFSNODEID}'"
NODEID_SHORT="'${NODEID_SHORT}'"
LOCAL_PORT=6310
PRINTER_PREFIX="astro_${NODEID_SHORT}"

## Function: Establish IPFS P2P tunnel
setup_tunnel() {
    if [[ ! $(ipfs p2p ls | grep "x/cups-${IPFSNODEID}") ]]; then
        echo "Connecting to CUPS service on ${IPFSNODEID}..."
        ipfs --timeout=10s ping -n 4 /p2p/${IPFSNODEID}
        if [[ $? != 0 ]]; then
            echo "ERROR: Cannot reach IPFSNODEID ${IPFSNODEID}"
            return 1
        fi
        ipfs p2p forward /x/cups-${IPFSNODEID} /ip4/127.0.0.1/tcp/${LOCAL_PORT} /p2p/${IPFSNODEID}
        echo "Tunnel established on port ${LOCAL_PORT}"
        sleep 2  # Wait for tunnel to be ready
    else
        echo "Tunnel already active on port ${LOCAL_PORT}"
    fi
    return 0
}

## Function: List remote printers
list_printers() {
    echo "Querying remote printers..."
    # Try lpstat first (use cut instead of awk for simpler escaping)
    PRINTERS=$(lpstat -h 127.0.0.1:${LOCAL_PORT} -a 2>/dev/null | cut -d" " -f1)
    if [[ -z "$PRINTERS" ]]; then
        # Fallback: query CUPS API directly
        PRINTERS=$(curl -s "http://127.0.0.1:${LOCAL_PORT}/printers/" 2>/dev/null \
            | grep -oP "(?<=<A HREF=\"/printers/)[^\"]+(?=\">)" | head -10)
    fi
    echo "$PRINTERS"
}

## Function: Auto-add remote printers to local system
auto_add_printers() {
    PRINTERS=$(list_printers)
    if [[ -z "$PRINTERS" ]]; then
        echo "No printers found on remote station"
        return 1
    fi
    
    echo "=========================================="
    echo "Found printers on ${IPFSNODEID}:"
    echo "$PRINTERS"
    echo "=========================================="
    
    ADDED=0
    for PRINTER in $PRINTERS; do
        LOCAL_NAME="${PRINTER_PREFIX}_${PRINTER}"
        # Check if already exists
        if lpstat -p "$LOCAL_NAME" &>/dev/null; then
            echo "Printer $LOCAL_NAME already configured"
        else
            echo "Adding printer: $LOCAL_NAME"
            # Add printer via IPP protocol
            lpadmin -p "$LOCAL_NAME" \
                -E \
                -v "ipp://127.0.0.1:${LOCAL_PORT}/printers/${PRINTER}" \
                -m everywhere \
                -o printer-is-shared=false \
                2>/dev/null
            
            if [[ $? == 0 ]]; then
                echo "  OK: $LOCAL_NAME added"
                ((ADDED++))
            else
                # Try with raw driver if "everywhere" fails
                lpadmin -p "$LOCAL_NAME" \
                    -E \
                    -v "ipp://127.0.0.1:${LOCAL_PORT}/printers/${PRINTER}" \
                    -m raw \
                    -o printer-is-shared=false \
                    2>/dev/null
                [[ $? == 0 ]] && echo "  OK: $LOCAL_NAME added (raw)" && ((ADDED++))
            fi
        fi
    done
    
    if [[ $ADDED -gt 0 ]]; then
        # Set first printer as default if no default exists
        if [[ -z $(lpstat -d 2>/dev/null | grep "system default") ]]; then
            FIRST_PRINTER="${PRINTER_PREFIX}_$(echo $PRINTERS | head -1)"
            lpadmin -d "$FIRST_PRINTER" 2>/dev/null
            echo "Default printer set to: $FIRST_PRINTER"
        fi
    fi
    
    echo "=========================================="
    echo "Local printers from this Astroport station:"
    lpstat -p 2>/dev/null | grep "$PRINTER_PREFIX"
    echo "=========================================="
    echo "Print command: lp -d ${PRINTER_PREFIX}_<name> <file>"
    echo "Or simply: lp <file>  (uses default printer)"
    echo "=========================================="
}

## Function: Remove astro printers and close tunnel
remove_printers() {
    echo "Removing Astroport printers (${PRINTER_PREFIX}_*)..."
    for PRINTER in $(lpstat -p 2>/dev/null | grep "$PRINTER_PREFIX" | cut -d" " -f2); do
        echo "Removing: $PRINTER"
        lpadmin -x "$PRINTER" 2>/dev/null
    done
    
    echo "Closing IPFS tunnel..."
    ipfs p2p close -p /x/cups-${IPFSNODEID} 2>/dev/null
    echo "Done."
}

## Function: Print a file
print_file() {
    FILE="$1"
    PRINTER="$2"
    
    if [[ ! -f "$FILE" ]]; then
        echo "ERROR: File not found: $FILE"
        return 1
    fi
    
    if [[ -z "$PRINTER" ]]; then
        # Use first astro printer or default
        PRINTER=$(lpstat -p 2>/dev/null | grep "$PRINTER_PREFIX" | cut -d" " -f2 | head -1)
        [[ -z "$PRINTER" ]] && PRINTER=$(lpstat -d 2>/dev/null | sed "s/.*: //")
    fi
    
    if [[ -z "$PRINTER" ]]; then
        echo "ERROR: No printer available"
        return 1
    fi
    
    echo "Printing $FILE to $PRINTER..."
    lp -d "$PRINTER" "$FILE"
}

## Main
case "${1:-setup}" in
    setup)
        setup_tunnel && auto_add_printers
        ;;
    list)
        setup_tunnel && list_printers
        ;;
    remove)
        remove_printers
        ;;
    print)
        setup_tunnel && print_file "$2" "$3"
        ;;
    *)
        echo "Usage: $0 [setup|list|remove|print <file> [printer]]"
        ;;
esac
' > ~/.zen/tmp/${IPFSNODEID}/x_cups.sh

    echo "ipfs cat /ipns/${IPFSNODEID}/x_cups.sh | bash"
    chmod +x ~/.zen/tmp/${IPFSNODEID}/x_cups.sh

fi

echo "Active P2P tunnels:"
ipfs p2p ls

############################################
echo "DRAGON WOKE UP"
############################################

exit 0
