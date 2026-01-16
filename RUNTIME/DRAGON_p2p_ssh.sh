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
    nostrhex=($(cat ~/.zen/game/nostr/*@*.*/HEX 2>/dev/null))
    umaphex=()
    if [[ -d ~/.zen/tmp/${IPFSNODEID}/UPLANET ]]; then
        umaphex=($(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_*/*/*/HEX 2>/dev/null))
    fi
    
    # Combine both lists
    allhex=("${nostrhex[@]}" "${umaphex[@]}")
    
    if [[ ${#allhex[@]} -gt 0 ]]; then
        echo "Following ${#nostrhex[@]} NOSTR cards and ${#umaphex[@]} active UMAP nodes (single kind3)"
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

fi

echo "Active P2P tunnels:"
ipfs p2p ls

############################################
echo "DRAGON WOKE UP"
############################################

exit 0
