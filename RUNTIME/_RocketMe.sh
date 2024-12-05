#!/bin/bash
########################################################################
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

. "${MY_PATH}/../tools/my.sh"
#~ exec 2>&1 >> ~/.zen/game/RocketMe.log

## Ce Script permet à la Station de générer ou rejoindre un swarm privé
## Il vérifie la concordance "SSH IPFSNODEID" des noeuds
## Contrôle ou déclenche l'echange de 1 G1 en chacun pour décider du "domaine.tld" commun
## Au minimum 3 Stations peuvent forger un nouvel essaim par jour.

echo "$ME RUNNING $(date)"
#################################################################
## CHECK MY Y/Z LEVEL tools/ssh_to_g1ipfs.py
YNODE=$(${MY_PATH}/../tools/ssh_to_g1ipfs.py)
[[ $YNODE != $IPFSNODEID || -z $YNODE ]] \
    && echo "NOT WILLING TO FORK... $YNODE != $IPFSNODEID" \
    && exit 0

## CHECK OTHER ASTROPORT PUBLISHING Y LEVEL
nodes=($(ls ~/.zen/tmp/swarm/*/y_ssh.pub | rev | cut -d '/' -f 2 | rev 2>/dev/null))
for aport in ${nodes[@]};
do
    ## Contenu de la clef publique ssh
    cat ~/.zen/tmp/swarm/${aport}/y_ssh.pub
    ## Test de concordance avec "ipfsNodeID"
    ynodeid=$(${MY_PATH}/../tools/ssh_to_g1ipfs.py "$(cat ~/.zen/tmp/swarm/${aport}/y_ssh.pub)")
    [[ ${ynodeid} != ${aport} ]] \
        && echo " ${ynodeid} != ${aport} - NOT SSH=IPFS READY" \
        && continue
    echo "${aport} : OK"
    OKSTATIONS=("${OKSTATIONS[@]}" "${aport}")
done

ZENSTATIONS=($(echo "${OKSTATIONS[@]}" | tr ' ' '\n' | sort -u)) ## SORT & REMOVE DUPLICATE
echo "<<< Y Level Stations are ${#nodes[@]} ASTROPORT(s) over ${#ZENSTATIONS[@]} are READY >>>"

## IPFSNODEID IS FORKING TO NEW UPLANET
if [[ ${#ZENSTATIONS[@]} -ge 3 ]]; then
    echo "UPlanet.ZERO /// ENTERING WARPING ZONE /// ${UPNAME} ACTIVATION"

    SECRETNAME=$(cat $HOME/.zen/game/players/${PLAYER}/.ipfs/${UPNAME}.swarm.key | tail -n 1)
    echo "SECRETNAME=$SECRETNAME"

#######################################################################
    echo "# UPlanet Swarm Bootstrap Stations #
# https://ipfs.${UPNAME} ipfs.${UPNAME}
#################################################################
" > ~/.zen/tmp/${MOATS}/new_straps.list

    # Prepare "new_straps.list" from WAN only
    for station in ${ZENSTATIONS[@]}; do
        [[ ! -s ~/.zen/tmp/swarm/${station}/myIPFS.txt ]] \
            && echo "Missing swarm/${station}/myIPFS.txt" \
            && continue

        bootnode=$(cat ~/.zen/tmp/swarm/${station}/myIPFS.txt)
        echo "${bootnode}"
        iptype=$(echo ${bootnode} | cut -d '/' -f 2)
        nodeip=$(echo ${bootnode} | cut -d '/' -f 3)
        isnodeipLAN=$(echo $nodeip | grep -E "/(^127\.)|(^192\.168\.)|(^10\.)|(^172\.1[6-9]\.)|(^172\.2[0-9]\.)|(^172\.3[0-1]\.)|(^::1$)|(^[fF][cCdD])/")
        echo " ${iptype} address :: ${nodeip} (= ${isnodeipLAN})"
        [[ ${nodeip} == ${isnodeipLAN} ]] && echo "LAN NODE... no good for bootstrap" && continue

        echo "### OK adding to new_straps.list"
        echo "${bootnode}" >> ~/.zen/tmp/${MOATS}/new_straps.list

    done

    ## INTRODUCE NEW BOOSTRAP LIST
    cp ~/.zen/tmp/${MOATS}/new_straps.list ~/.zen/game/MY_boostrap_nodes.txt
    #######################################################################
    ## UPNAME = domain.tld
    # PACTHING Astroport.ONE code
    grep -rl --exclude-dir='.git*' 'copylaradio.com' ~/.zen | xargs sed -i "s~copylaradio.com~${UPNAME,,}~g"
    rm ~/.zen/game/myswarm_secret.dunikey
    # now we add key into ~/.ipfs/swarm.key
    #~ cp $HOME/.zen/game/players/${PLAYER}/.ipfs/${UPNAME}.swarm.key ~/.ipfs/swarm.key
    # it will make IPFSNODEID restarting in private mode

fi


rm -Rf ~/.zen/tmp/${MOATS}

exit 0
