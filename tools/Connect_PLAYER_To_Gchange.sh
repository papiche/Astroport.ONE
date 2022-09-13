#!/bin/bash
# Run After PLAYER.entrance.sh
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"
######################################################################### CONNECT PLAYER WITH GCHANGE
# Check who is .current PLAYER
PLAYER=$(cat ~/.zen/game/players/.current/.player 2>/dev/null) || ( echo "noplayer" && exit 1 )
PSEUDO=$(cat ~/.zen/game/players/.current/.pseudo 2>/dev/null) || ( echo "nopseudo" && exit 1 )
G1PUB=$(cat ~/.zen/game/players/.current/.g1pub 2>/dev/null) || ( echo "nog1pub" && exit 1 )

ASTRONAUTENS=$(ipfs key list -l | grep -w "$PLAYER" | cut -d ' ' -f 1)

########################################################################
echo "CREATING $PLAYER GCHANGE+ PROFILE"
########################################################################
$MY_PATH/jaklis/jaklis.py -k ~/.zen/game/players/$PLAYER/secret.dunikey -n "https://data.gchange.fr" set --name "Astronaute $PSEUDO" --avatar "/home/$USER/.zen/Astroport.ONE/images/logo.png" --site "https://astroport.com/ipns/$ASTRONAUTENS" #GCHANGE+
[[ ! $? == 0 ]] && echo "GCHANGE PROFILE CREATION FAILED" && echo "Action Manuelle " $MY_PATH/jaklis/jaklis.py -k ~/.zen/game/players/$PLAYER/secret.dunikey -n "https://data.gchange.fr" set --name "Astronaute $PSEUDO" --avatar "/home/$USER/.zen/Astroport.ONE/images/logo.png" --site "https://astroport.com/ipns/$ASTRONAUTENS" #GCHANGE+

########################################################################
#echo "CREATING $PLAYER CESIUM+ PROFILE"
########################################################################
$MY_PATH/jaklis/jaklis.py -k ~/.zen/game/players/$PLAYER/secret.dunikey -n "https://g1.data.presles.fr" set --name "Astronaute $PLAYER" --avatar "/home/$USER/.zen/Astroport.ONE/images/logo.png" --site "http://127.0.0.1:8080/ipns/$ASTRONAUTENS" #CESIUM+
[[ ! $? == 0 ]] && echo "CESIUM PROFILE CREATION FAILED" && echo "Action Manuelle " $ $MY_PATH/jaklis/jaklis.py -k ~/.zen/game/players/$PLAYER/secret.dunikey -n "https://g1.data.presles.fr" set --name "Astronaute $PLAYER" --avatar "/home/$USER/.zen/Astroport.ONE/images/logo.png" --site "http://127.0.0.1:8080/ipns/$ASTRONAUTENS" #CESIUM+

########################################################################

########################################################################
echo "BECOME FRIEND with A_boostrap_nodes.txt"
########################################################################
#for bootnode in $(cat ~/.zen/Astroport.ONE/A_boostrap_nodes.txt | grep -Ev "#") # remove comments
#do
#if [[ $bootnode != "" ]]; then
#    ipfsnodeid=${bootnode##*/}
#    g1node=$(~/.zen/astrXbian/zen/tools/ipfs_to_g1.py $ipfsnodeid)
#    echo "SENDING STAR TO BOOTSTRAP NODE : $g1node"
#    $MY_PATH/jaklis/jaklis.py -k ~/.zen/game/players/$PLAYER/secret.dunikey -n "https://data.gchange.fr" stars -p $g1node -n 1
#    ### DELETE
#    # jaklis.py -k ~/.zen/secret.dunikey -n "https://data.gchange.fr" unstars -p $g1node
#fi
#done

########################################################################
# echo 'Creating "ipfstryme" message'
########################################################################
# ~/.zen/astrXbian/zen/tools/add_externIP_to_ipfstryme.sh
# [[ $(cat ~/.zen/ipfs/.${IPFSNODEID}/tryme.addr) == "" ]] && echo "IPFS Friendly Swarm Layer rewriting"

exit 0
