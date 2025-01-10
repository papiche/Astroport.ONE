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
if [ -s "$HOME/.astro/bin/activate" ]; then
    source $HOME/.astro/bin/activate
fi
echo '
        ()    /)
----.---/----(  )
     \        \)
     ()
'

[[ "$1" == "reset" ]] && rm ~/.zen/game/UPLANETG1PUB ~/.ipfs/swarm.key ~/.zen/game/MY_boostrap_nodes.txt ~/.zen/game/My_boostrap_ssh.txt && exit 0
## Ce Script permet à la Station de générer ou rejoindre un swarm privé
## Il vérifie la concordance "SSH IPFSNODEID" des noeuds
## Au minimum 4 Stations peuvent forker un nouvel essaim par jour.

echo "$ME RUNNING $(date)"
## CHECK IF ALREADY IPFS PRIVATE SWARM
if [[ -s ~/.ipfs/swarm.key ]]; then
    cat ~/.ssh/authorized_keys
    echo "
                __====-_  _-====__
         _--^^^#####//      \\#####^^^--_
      _-^##########// (    ) \\##########^-_
     -############//  |\^^/|  \\############-
   _/############//   (@::@)   \\############^_
 /##############((     \\//     ))#############_
-###############\\     (oo)     //###############-
-################\\   / "" \   //#################-
-#################\\ / /  \ \ //###################-
-##################\\/     \\//####################-
_#/|##########/\#####(      )######/\##########|\#_
|/ |#/\#/\#/\/  \#/\#/       /##/\#/  \/\#/\#/\#|
    |/  V  |/      \|        |/         |V  \|
    DRAGON PRIVATE SWARM ${UPLANETG1PUB}
------------------------------------------------
"
    ipfs p2p ls
    exit 0
fi
#################################################################
## CHECK MY Y/Z LEVEL tools/ssh_to_g1ipfs.py
YNODE=$(${MY_PATH}/../tools/ssh_to_g1ipfs.py)
[[ $YNODE != $IPFSNODEID || -z $YNODE ]] \
    && echo "$YNODE != $IPFSNODEID" \
    && echo "YLEVEL NOT READY ... SSH != IPFS ..." \
    && exit 0

## Init SEEDS - DRAGON made it
[[ ! -s ~/.zen/tmp/${IPFSNODEID}/_swarm.egg.txt ]] \
    && head -c 12 /dev/urandom | od -t x1 -A none - | tr -d ' ' \
    > ~/.zen/tmp/${IPFSNODEID}/_swarm.egg.txt

SEEDS=$(cat ~/.zen/tmp/${IPFSNODEID}/_swarm.egg.txt)

totnodes=($(ls ~/.zen/tmp/swarm/*/12345.json | rev | cut -d '/' -f 2 | rev 2>/dev/null))

## CHECK OTHER ASTROPORT PUBLISHING Y LEVEL
nodes=($(ls ~/.zen/tmp/swarm/*/y_ssh.pub | rev | cut -d '/' -f 2 | rev 2>/dev/null))
for aport in ${nodes[@]};
do
    ## Test  "REAL YLEVEL" : clef publique ssh = "ipfsNodeID"
    ynodeid=$(${MY_PATH}/../tools/ssh_to_g1ipfs.py "$(cat ~/.zen/tmp/swarm/${aport}/y_ssh.pub)")
    [[ ${ynodeid} != ${aport} ]] \
        && echo " ${ynodeid} != ${aport} " \
        && continue

    echo "${aport} : READY TO BLOOM" \
    && OKSTATIONS=("${OKSTATIONS[@]}" "${aport}")
done

## ADD MYSELF
OKSTATIONS=("${OKSTATIONS[@]}" "${IPFSNODEID}")
ZENSTATIONS=($(echo "${OKSTATIONS[@]}" | tr ' ' '\n' | sort -u)) ## SORT & REMOVE DUPLICATE
echo "<<< TOTAL ${#totnodes[@]} ~~~ ${#nodes[@]} in swarm ~~~ ${#ZENSTATIONS[@]} READY TO BLOOM >>>"

## FIND MY DOMAIN
MYhostname="$(cat ~/.zen/tmp/${IPFSNODEID}/12345.json | jq -r .hostname)"
MYASTROPORT="$(cat ~/.zen/tmp/${IPFSNODEID}/12345.json | jq -r .myASTROPORT)"
echo $MYASTROPORT
[[ $(echo ${MYASTROPORT} | grep 'https') ]] \
    && UPNAME=$(echo ${MYASTROPORT} | rev | cut -d '.' -f -2 | rev) \
    || UPNAME="copylaradio.com"

## IS IPFSNODEID FORGING NEW UPLANET
echo "UPlanet ORIGIN /// $MYhostname WARPING /// ${UPNAME} ACTIVATION"
#######################################################################
if [[ ${#ZENSTATIONS[@]} -ge 4 ]]; then
    [[ -z ${MOATS} ]] && MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
    mkdir -p ~/.zen/tmp/${MOATS}
    # Prepare "new_straps.list" from WAN only
    for station in ${ZENSTATIONS[@]}; do
        echo '---------------------------------------------------------------------------'
        [[ $station != ${IPFSNODEID} ]] \
            && NodePath=${HOME}/.zen/tmp/swarm/${station} \
            || NodePath=${HOME}/.zen/tmp/${station}

        [[ ! -s ${NodePath}/myIPFS.txt ]] \
            && echo "Missing /${station}/myIPFS.txt" \
            && continue

        ## Check if same UPNAME
        mystro="$(cat ${NodePath}/12345.json | jq -r .myASTROPORT)"
        captain="$(cat ${NodePath}/12345.json | jq -r .captain)"
        echo $mystro
        hopname=$(echo ${mystro} | rev | cut -d '.' -f -2 | rev)
        echo "${captain} STATION (${hopname})"

        ## COLLECT _swarm.egg.txt SEEDS
        seed=$(cat ${NodePath}/_swarm.egg.txt)
        echo "cat ${NodePath}/_swarm.egg.txt : ${seed}"
        SEEDS=("${SEEDS[@]}" "${seed}")

        ## Adding to ~/.zen/Astroport.ONE/A_boostrap_ssh.txt
        [[ -s ${NodePath}/y_ssh.pub && ! -z ${seed} ]] \
            && cat ${NodePath}/y_ssh.pub >> ~/.zen/game/My_boostrap_ssh.txt
        ## Remove duplicate
        awk '!seen[$0]++' ~/.zen/game/My_boostrap_ssh.txt > ~/.zen/tmp/${MOATS}/My_boostrap_ssh.temp
        mv ~/.zen/tmp/${MOATS}/My_boostrap_ssh.temp ~/.zen/game/My_boostrap_ssh.txt

        ## Adding to MY Bootstrap List
        bootnode=$(cat ${NodePath}/myIPFS.txt)
        iptype=$(echo ${bootnode} | cut -d '/' -f 2)
        if [[ $iptype == "dnsaddr" ]]; then
            echo "### Heading ${bootnode} to new_straps.list"
            echo "${bootnode}" > ~/.zen/tmp/${MOATS}/new_straps.temp ## write first in list
            cat ~/.zen/tmp/${MOATS}/new_straps.list >> ~/.zen/tmp/${MOATS}/new_straps.temp
            mv ~/.zen/tmp/${MOATS}/new_straps.temp ~/.zen/tmp/${MOATS}/new_straps.list
            continue
        fi

        nodeip=$(echo ${bootnode} | cut -d '/' -f 3)
        isnodeipLAN=$(echo $nodeip | grep -E "/(^127\.)|(^192\.168\.)|(^10\.)|(^172\.1[6-9]\.)|(^172\.2[0-9]\.)|(^172\.3[0-1]\.)|(^::1$)|(^[fF][cCdD])/")
        echo " ${iptype} address :: ${nodeip} (= ${isnodeipLAN})"
        [[ ${nodeip} == ${isnodeipLAN} ]] && echo "LAN NODE... no good for bootstrap" && continue

        echo "### Adding ${bootnode} to new_straps.list"
        echo "${bootnode}" >> ~/.zen/tmp/${MOATS}/new_straps.list

    done

    ## DEDOUBLAGE DE LIGNE
    awk '!seen[$0]++' ~/.zen/tmp/${MOATS}/new_straps.list > ~/.zen/tmp/${MOATS}/new_straps.temp
    mv ~/.zen/tmp/${MOATS}/new_straps.temp ~/.zen/tmp/${MOATS}/new_straps.list
    cat ~/.zen/tmp/${MOATS}/new_straps.list ## NEW BOOTSTRAP LIST

    #### SWARM KEY SHARED SECRET CREATION
    #... TODO ... Add "zero proof knowledge" using "IPFS/SSH" contact
    MAGIX=($(printf "%s\n" "${SEEDS[@]}" | sort -u))
    echo "／人 ◕‿‿◕ 人＼ : ${MAGIX[@]}" ## DEBUG
    ## NEW SWARM KEY
echo "/key/swarm/psk/1.0.0/
/base16/
$(echo "${MAGIX[@]}" | tr -d '\n ' | head -c 64)" > $HOME/.zen/tmp/${MOATS}/swarm.key
    UPLANETNAME=$(cat $HOME/.zen/tmp/${MOATS}/swarm.key | tail -n 1) ## THIS IS OUR SECRET
    UPLANETG1PUB=$(${MY_PATH}/../tools/keygen -t duniter "${UPLANETNAME}" "${UPLANETNAME}")


if [[ -s ~/.zen/tmp/${MOATS}/new_straps.list ]]; then
    ## INJECT NEW BOOSTRAP LIST
    if [[ ! -s ~/.zen/game/MY_boostrap_nodes.txt ]]; then
        echo "# UPlanet Swarm Bootstrap Stations #
    # https://ipfs.${UPNAME} ipfs.${UPNAME}
    #################################################################
    " > ~/.zen/tmp/${MOATS}/MY_boostrap_nodes.txt
    fi
    cat ~/.zen/tmp/${MOATS}/new_straps.list >> ~/.zen/game/MY_boostrap_nodes.txt
fi

#######################################################################
## RESET SWARM KEY
rm -f ~/.zen/game/myswarm_secret.*
echo ${UPLANETG1PUB} > ~/.zen/game/UPLANETG1PUB

#####################################################
echo "# ACTIVATING ~/.ipfs/swarm.key"
cat $HOME/.zen/tmp/${MOATS}/swarm.key > ~/.ipfs/swarm.key
# IPFSNODEID will restart in private mode

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
            \/      '${UPNAME}'
------------------------------------------------
'${UPLANETG1PUB}

fi

#### DEBUG
echo "~/.ipfs/swarm.key_______________"
cat ~/.ipfs/swarm.key
echo "~/.zen/game/MY_boostrap_nodes.txt_________"
cat ~/.zen/game/MY_boostrap_nodes.txt
echo "~/.zen/game/My_boostrap_ssh.txt__________"
cat ~/.zen/game/My_boostrap_ssh.txt

#~ ## DRY RUN
[[ "$1" == "reset" ]] \
&& rm ~/.zen/game/UPLANETG1PUB ~/.ipfs/swarm.key ~/.zen/game/MY_boostrap_nodes.txt ~/.zen/game/My_boostrap_ssh.txt

###### REFRESH IPFS BOOSTRAP LIST
source ~/.zen/Astroport.ONE/tools/my.sh
for bootnode in $(cat ${STRAPFILE} | grep -Ev "#") # parse STRAPFILE
do
    ipfsnodeid=${bootnode##*/}
    ipfs bootstrap add $bootnode
done

rm -Rf ~/.zen/tmp/${MOATS}

exit 0
