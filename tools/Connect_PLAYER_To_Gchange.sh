#!/bin/bash
######################################################################### CONNECT PLAYER WITH GCHANGE
# Check who is .current PLAYER
PLAYER=$(cat ~/.zen/game/players/.current/.player 2>/dev/null) || ( echo "noplayer" && exit 1 )
PSEUDO=$(cat ~/.zen/game/players/.current/.pseudo 2>/dev/null) || ( echo "nopseudo" && exit 1 )
G1PUB=$(cat ~/.zen/game/players/.current/.g1pub 2>/dev/null) || ( echo "nog1pub" && exit 1 )
IPFSNODEID=$(cat ~/.zen/game/players/.current/.ipfsnodeid 2>/dev/null) || ( echo "noipfsnodeid" && exit 1 )

########################################################################
echo "CREATING $PLAYER GCHANGE+ PROFILE"
########################################################################
~/.zen/astrXbian/zen/jaklis/jaklis.py -k ~/.zen/secret.dunikey -n "https://data.gchange.fr" set --name "Astronaute $PLAYER" --avatar "/home/$USER/.zen/astrXbian/logo.png" --site "https://astroport.com/ipns/$(cat ~/.zen/game/players/$PLAYER/.qoopns)" #GCHANGE+
[[ ! $? == 0 ]] && echo "GCHANGE PROFILE CREATION FAILED" && exit 1
########################################################################
echo "CREATING $PLAYER CESIUM+ PROFILE"
########################################################################
~/.zen/astrXbian/zen/jaklis/jaklis.py -k ~/.zen/secret.dunikey -n "https://g1.data.e-is.pro" set --name "Astronaute $PLAYER" --avatar "/home/$USER/.zen/astrXbian/logo.png" --site "https://astroport.com/ipns/$(cat ~/.zen/game/players/$PLAYER/.moans)" #CESIUM+
[[ ! $? == 0 ]] && echo "CESIUM PROFILE CREATION FAILED" && exit 1
########################################################################

########################################################################
echo "BECOME FRIEND with A_boostrap_nodes.txt"
########################################################################
for bootnode in $(cat ~/.zen/astrXbian/A_boostrap_nodes.txt | grep -Ev "#") # remove comments
do
if [[ $bootnode != "" ]]; then
    ipfsnodeid=${bootnode##*/}
    g1node=$(~/.zen/astrXbian/zen/tools/ipfs_to_g1.py $ipfsnodeid)
    echo "SENDING STAR TO BOOTSTRAP NODE : $g1node"
    ~/.zen/astrXbian/zen/jaklis/jaklis.py -k ~/.zen/secret.dunikey -n "https://data.gchange.fr" stars -p $g1node -n 1
    ### DELETE
    # ~/.zen/astrXbian/zen/jaklis/jaklis.py -k ~/.zen/secret.dunikey -n "https://data.gchange.fr" unstars -p $g1node
fi
done

########################################################################
echo 'Creating "ipfstryme" message'
########################################################################
~/.zen/astrXbian/zen/tools/add_externIP_to_ipfstryme.sh

[[ $(cat ~/.zen/ipfs/.${IPFSNODEID}/tryme.addr) == "" ]] && echo "Your Swarm Address is unavailable" && exit 0

########################################################################
echo 'Sending \"ipfstryme\" message to BOOTSTRAP nodes' # Add bootstrap in A_boostrap_nodes.txt
########################################################################
for bootnode in $(cat ~/.zen/astrXbian/A_boostrap_nodes.txt | grep -Ev "#") # remove comments
do
if [[ $bootnode != "" ]]; then
    ipfsnodeid=${bootnode##*/}
    g1node=$(~/.zen/astrXbian/zen/tools/ipfs_to_g1.py $ipfsnodeid)
    echo "SENDING ipfstryme to BOOTSTRAP node : $g1node"
    filelines=$(cat ~/.zen/ipfs/.${IPFSNODEID}/tryme.addr | wc -l)
    [[ "$filelines" != "0" ]] && ~/.zen/astrXbian/zen/jaklis/jaklis.py -k ~/.zen/secret.dunikey -n "https://data.gchange.fr" send -d $g1node -t "ipfstryme" -f ~/.zen/ipfs/.${IPFSNODEID}/tryme.addr
fi
done

## # TODO ADD FRIENDS FROM
