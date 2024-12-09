#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "$MY_PATH/my.sh"
ME="${0##*/}"

mkdir -p ~/.zen/game

## CE SCRIPT ASSURE LA COHERENCE CRYPTO ENTRE USER SSH ET IPFSNODEID
## A CAPTAIN IS ACTIVATING ASTROPORT
## Convert SSH key into IPFS key (Node ID) & USER NEW SSH ASTROPORT KEY

if [[ -s ~/.ssh/id_ed25519 ]]; then
    echo ‎"(/.__.)/   \(.__.\)"
    echo "SSH ED25519 KEY EXISTING"
    if [[ -s ~/.zen/game/id_ssh.pub ]]; then
        echo "****** __̴ı̴̴̡̡̡ ̡͌l̡̡̡ ̡͌l̡*̡̡ ̴̡ı̴̴̡ ̡̡͡|̲̲̲͡͡͡ ̲▫̲͡ ̲̲̲͡͡π̲̲͡͡ ̲̲͡▫̲̲͡͡ ̲|̡̡̡ ̡ ̴̡ı̴̡̡ ̡͌l̡̡̡̡.___ ******* ${IPFSNODEID}"
        echo "Astroport SSH Key Transmutation Already Done/"
        cat ~/.ssh/id_ed25519.pub
        YIPNS=$(${MY_PATH}/../tools/ssh_to_g1ipfs.py "$(cat ~/.ssh/id_ed25519.pub)")
        [[ $(diff ~/.zen/game/id_ssh.pub ~/.ssh/id_ed25519.pub) || ${YIPNS} != ${IPFSNODEID} ]] \
            && echo "SSH/IPFS KEY NOT MATCHING... CONTACT SUPPORT (_8^( l)" && exit 1
        echo "SSH + IPFS : OK"
        exit 0
    fi

    echo "<(''<)  <( ' SSH TRANSMUTATION )>  (> '')>"
    PS3="Choose KEY type : "
    choices=("CAPTAIN" "PLAYER")
    select fav in  "${choices[@]}"; do
        case $fav in
        "CAPTAIN")
            ### GET SHA512 SSH PRIVATE KEY AS SEED FOR SECRETS SPLIT
            SSHASH=$(cat ~/.ssh/id_ed25519 | sha512sum | cut -d ' ' -f 1)
            SECRET1=$(echo "$SSHASH" | cut -c 1-64)
            SECRET2=$(echo "$SSHASH" | cut -c 65-128)

            break
            ;;

        "PLAYER")
            echo "ENTER MULTIPASS SALT & PEPPER ?"
            echo "Salt ?"
            read SECRET1
            echo "Pepper ?"
            read SECRET2

            break
            ;;

        "")
            echo "Mauvais choix."
            ;;

        esac
    done

    SSHYNODEID=$(~/.zen/Astroport.ONE/tools/keygen -t ipfs "$SECRET1" "$SECRET2")
    echo "??? ${SSHYNODEID} = ${IPFSNODEID} ???"

   if [[ ${SSHYNODEID} != ${IPFSNODEID} ]]; then
        echo "
        <(''<)  <( ' ' )>  (> '')>
        ACTIVATING Y LEVEL"
        echo "SALT=$SECRET1; PEPPER=$SECRET2" > ~/.zen/game/secret.june
        chmod 600 ~/.zen/game/secret.june
        ## supprimer les anciennes clef de SWARM
        rm ~/.zen/game/myswarm_secret.*

        ## Creating IPNSNODEID from SECRETS
        ~/.zen/Astroport.ONE/tools/keygen -t ipfs -o ~/.zen/game/secret.ipns "$SECRET1" "$SECRET2"
        ## Convert IPFS key to Duniter key (G1 Wallet)
        ~/.zen/Astroport.ONE/tools/keygen -i ~/.zen/game/secret.ipns -t duniter -o ~/.zen/game/secret.dunikey

        ## Creating SSH from SECRETS
        ~/.zen/Astroport.ONE/tools/keygen -t ssh -o ~/.zen/game/id_ssh "$SECRET1" "$SECRET2"

        ## BitCOIN key reveal (BONUS)
        ~/.zen/Astroport.ONE/tools/keygen -t bitcoin "$SECRET1" "$SECRET2"

        ##### IPFSNODEID UPGRADE
        ## EXTRACT PUB/PRIV KEY
        PeerID=$(~/.zen/Astroport.ONE/tools/keygen -i ~/.zen/game/secret.ipns -t ipfs)
        echo $PeerID
        PrivKey=$(~/.zen/Astroport.ONE/tools/keygen -i ~/.zen/game/secret.ipns -t ipfs -s)
        echo $PrivKey

        ### STOPPING ASTROPORT SERVICE
        ~/.zen/Astroport.ONE/stop.sh

        # Backup actual Node ID
        cat ~/.ipfs/config | jq -r '.Identity.PeerID' \
            > ~/.zen/game/ipfsnodeid.bkp
        cat ~/.ipfs/config | jq -r '.Identity.PrivKey' \
            >> ~/.zen/game/ipfsnodeid.bkp

        # Insert new Node ID
        cp ~/.ipfs/config ~/.ipfs/config.bkp
        jq '.Identity.PeerID="'$PeerID'"' ~/.ipfs/config > ~/.ipfs/config.tmp
        jq '.Identity.PrivKey="'$PrivKey'"' ~/.ipfs/config.tmp > ~/.ipfs/config && rm ~/.ipfs/config.tmp

        # Verify & restart IPFS daemon
        [[ "$(cat ~/.ipfs/config | jq -r '.Identity.PrivKey' )" != "$PrivKey" ]] \
            && blurp="ERROR" \
            || blurp="SUCCESS"

        echo "##############################################################"
        echo ">>> IPFS KEY TRANSMUTATION ? " ${blurp}
        [[ ${blurp} != "SUCCESS" ]] \
            && rm ~/.ipfs/config \
                && mv ~/.ipfs/config.bkp ~/.ipfs/config \
                    && echo "IPFS CONFIG ROLL BACK" && exit 1

        ## Réactivation Astroport.ONE
        ~/.zen/Astroport.ONE/start.sh

        echo "##############################################################"
        echo ">>> SSH LINK ACTIVATION ~/.zen/game/id_ssh == ~/.ssh/id_ed25519"
        echo "##############################################################"
        mv ~/.ssh/id_ed25519 ~/.ssh/origin.key
        mv ~/.ssh/id_ed25519.pub ~/.ssh/origin.pub
        mv ~/.zen/game/id_ssh ~/.ssh/id_ed25519 && chmod 600 ~/.ssh/id_ed25519
        cp ~/.zen/game/id_ssh.pub ~/.ssh/id_ed25519.pub && chmod 644 ~/.ssh/id_ed25519.pub

        ## SUCCESS
        echo "YOUR PREVIOUS SSH KEY IS ~/.ssh/origin.key"
        echo "\(^-^)/ SSH/IPFS Twin key secrets"
        echo "SECRET1=$SECRET1"
        echo "SECRET2=$SECRET2"

    else
        echo "Y LEVEL ALREADY ACTIVATED : $IPFSNODEID "
    fi

    NODEG1PUB=$(cat ~/.zen/game/secret.dunikey | grep 'pub:' | cut -d ' ' -f 2)
    echo "NODEG1PUB=${NODEG1PUB}"
else
    echo "GENERATING FIRST SSH ED25519 KEY"
    ssh-keygen -t ed25519
    echo "FINISH YOUR NODE TRANSFORMATION. PLEASE RUN $ME AGAIN
    (╯°□°)--︻╦╤─ - - - "
fi

