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

echo '
        ()    /)
----.---/----(  )
     \        \)
     ()
'

## Ce Script permet à la Station de générer ou rejoindre un swarm privé
## Il vérifie la concordance "SSH IPFSNODEID" des noeuds
## Contrôle ou déclenche l'echange de 1 G1 en chacun pour décider du "domaine.tld" commun
## Au minimum 3 Stations peuvent forger un nouvel essaim par jour.

echo "$ME RUNNING $(date)"
#################################################################
## CHECK MY Y/Z LEVEL tools/ssh_to_g1ipfs.py
YNODE=$(${MY_PATH}/../tools/ssh_to_g1ipfs.py)
[[ $YNODE != $IPFSNODEID || -z $YNODE ]] \
    && echo "MY NODE IS NOT READY ... SSH != IPFS ... $YNODE != $IPFSNODEID" \
    && exit 0

## Init SEEDS
SEEDS=$(cat ~/.zen/tmp/${IPFSNODEID}/_swarm_part.12.txt)
[[ $SEEDS == "" ]] \
    && echo "NOT READY MISSING _swarm_part.12.txt" && exit 1

## CHECK IF ALREADY IPFS PRIVATE SWARM
[[ -s ~/.ipfs/swarm.key ]] \
    && echo "PRIVATE SWARM ALREADY ACTIVATED ~/.ipfs/swarm.key" \
    && exit 0

## CHECK OTHER ASTROPORT PUBLISHING Y LEVEL
nodes=($(ls ~/.zen/tmp/swarm/*/y_ssh.pub | rev | cut -d '/' -f 2 | rev 2>/dev/null))
for aport in ${nodes[@]};
do
    ## Test de concordance de la clef publique ssh avec "ipfsNodeID"
    ynodeid=$(${MY_PATH}/../tools/ssh_to_g1ipfs.py "$(cat ~/.zen/tmp/swarm/${aport}/y_ssh.pub)")
    [[ ${ynodeid} != ${aport} ]] \
        && echo " ${ynodeid} != ${aport} " \
        && continue
    [[ ${aport} != ${IPFSNODEID} ]] \
        && echo "${aport} : READY TO BLOOM" \
        && OKSTATIONS=("${OKSTATIONS[@]}" "${aport}")
done

ZENSTATIONS=($(echo "${OKSTATIONS[@]}" | tr ' ' '\n' | sort -u)) ## SORT & REMOVE DUPLICATE
echo "<<< ${#nodes[@]} ASTROPORT(s) are YLevel : ${#ZENSTATIONS[@]} are READY >>>"

## FIND MY DOMAIN
MYASTROPORT="$(cat ~/.zen/tmp/${IPFSNODEID}/12345.json | jq -r .myASTROPORT)"
echo $MYASTROPORT
[[ $(echo ${MYASTROPORT} | grep 'https') ]] \
    && UPNAME=$(echo ${MYASTROPORT} | rev | cut -d '.' -f -2 | rev) \
    || UPNAME="copylaradio.com"

## IS IPFSNODEID FORGING NEW UPLANET
echo "UPlanet.ZERO /// ENTERING WARPING ZONE /// ${UPNAME} ACTIVATION"
#######################################################################
if [[ ${#ZENSTATIONS[@]} -ge 3 ]]; then
    echo "# UPlanet Swarm Bootstrap Stations #
# https://ipfs.${UPNAME} ipfs.${UPNAME}
#################################################################
" > ~/.zen/tmp/${MOATS}/new_straps.list

    # Prepare "new_straps.list" from WAN only
    for station in ${ZENSTATIONS[@]}; do
        ## COLLECT _swarm_part.12.txt SEEDS
        seed=$(cat ~/.zen/tmp/swarm/${station}/_swarm_part.12.txt)
        SEEDS=("${SEEDS[@]}" "${seed}")

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
    cat ~/.zen/tmp/${MOATS}/new_straps.list ## NEW BOOTSTRAP LIST

    #### SWARM KEY SHARED SECRET CREATION
    #... TODO ... Add "zero proof knowledge" using "IPFS/SSH" contact
    MAGIX=($(echo "${SEEDS[@]}" | tr ' ' '\n' | sort -u)) ## SORT
    echo "MAGIX : ${MAGIX[@]}" ## DEBUG
    MAGIH=$(echo "${MAGIX[@]}" | sha512sum | cut -d ' ' -f 1) ## HASH512
    echo "${MAGIX[@]}"  | tr -d ' ' | head -c 32 | od -t x1 -A none - | tr -d '\n ' \
            > $HOME/.zen/tmp/${MOATS}/swarm.key ## NEW SWARM KEY

    cat $HOME/.zen/tmp/${MOATS}/swarm.key
    ## INJECT NEW BOOSTRAP LIST
    echo "cp ~/.zen/tmp/${MOATS}/new_straps.list ~/.zen/game/MY_boostrap_nodes.txt"
    #######################################################################
    ## UPNAME = domain.tld
    # PACTHING Astroport.ONE code --- breaks automatic git pull... manual update
    ##
    #~ grep -rl --exclude-dir='.git*' 'copylaradio.com' ~/.zen | xargs sed -i "s~copylaradio.com~${UPNAME,,}~g"
    #~ rm ~/.zen/game/myswarm_secret.dunikey

    # PUT key into ~/.ipfs/swarm.key
    echo "cp $HOME/.zen/tmp/${MOATS}/swarm.key ~/.ipfs/swarm.key"
    # it will make IPFSNODEID restarting in private mode
echo '
        /\_ _  __
  __  _ \( ! )/_/  __
  \_\( % )>o<})# )/_/
   _(%>o<(_!_)>o<#)_
  /_/(_% ( | (_#_)/_/
    ( ! (~>O<~) % ) _
  _({>O<}(_|_)%>O<%)_>
 /_/(_!_)# )( (_%_)
     _(#>o<#)>o< )_
    /_/(_#_)(_|_)\_\
            \/      ${UPNAME}
------------------------------------------------
'

fi


rm -Rf ~/.zen/tmp/${MOATS}

exit 0
