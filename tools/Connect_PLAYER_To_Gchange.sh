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

if [[ ! -d ~/.zen/game/players/$PLAYER/FRIENDS/ ]]; then
    ########################################################################
    echo "CREATING $PLAYER GCHANGE+ PROFILE"
    ########################################################################
    $MY_PATH/jaklis/jaklis.py -k ~/.zen/game/players/$PLAYER/secret.dunikey -n "https://data.gchange.fr" set --name "Astronaute $PSEUDO" --avatar "/home/$USER/.zen/Astroport.ONE/images/logo.png" --site "https://astroport.com/ipns/$ASTRONAUTENS" #GCHANGE+
    [[ ! $? == 0 ]] && echo "GCHANGE PROFILE CREATION FAILED" && echo "Action Manuelle " $MY_PATH/jaklis/jaklis.py -k ~/.zen/game/players/$PLAYER/secret.dunikey -n "https://data.gchange.fr" set --name "Astronaute $PSEUDO" --avatar "/home/$USER/.zen/Astroport.ONE/images/logo.png" --site "https://tube.copylaradio.com/ipns/$ASTRONAUTENS" #GCHANGE+

    ########################################################################
    #echo "CREATING $PLAYER CESIUM+ PROFILE"
    ########################################################################
    $MY_PATH/jaklis/jaklis.py -k ~/.zen/game/players/$PLAYER/secret.dunikey -n "https://g1.data.presles.fr" set --name "Astronaute $PSEUDO" --avatar "/home/$USER/.zen/Astroport.ONE/images/logo.png" --site "http://127.0.0.1:8080/ipns/$ASTRONAUTENS" #CESIUM+
    [[ ! $? == 0 ]] && echo "CESIUM PROFILE CREATION FAILED" && echo "Action Manuelle " $ $MY_PATH/jaklis/jaklis.py -k ~/.zen/game/players/$PLAYER/secret.dunikey -n "https://g1.data.presles.fr" set --name "Astronaute $PLAYER" --avatar "/home/$USER/.zen/Astroport.ONE/images/logo.png" --site "http://127.0.0.1:8080/ipns/$ASTRONAUTENS" #CESIUM+
fi

########################################################################

########################################################################
echo "SCANNING $PLAYER Gchange FRIENDS"
########################################################################
################## CHECKING WHO GAVE ME STARS
################## BOOTSTRAP LIKES THEM BACK
################## SEND ipfstryme MESSAGES to FRIENDS
rm -f ~/.zen/tmp/my_star_level
## Getting Gchange  liking_me list
echo "Reading received stars"
~/.zen/Astroport.ONE/tools/timeout.sh -t 20 ~/.zen/Astroport.ONE/tools/jaklis/jaklis.py -k ~/.zen/game/players/$PLAYER/secret.dunikey -n "https://data.gchange.fr" stars | jq -r '.likes[].issuer' | uniq > ~/.zen/tmp/liking_me

for liking_me in $(cat ~/.zen/tmp/liking_me | sort | uniq);
do
    [[ "$liking_me" == "" ]] && continue ## Protect from empty line !!

    ipfsnodeid=$(~/.zen/Astroport.ONE/tools/g1_to_ipfs.py $liking_me)
    echo "$liking_me is Astronaut ?"
    echo "Check TW Capsule https://tube.copylaradio.com/ipns/$ipfsnodeid "

##### CHECKING IF WE LIKE EACH OTHER Ŋ1 LEVEL
    ~/.zen/Astroport.ONE/tools/timeout.sh -t 20 ~/.zen/Astroport.ONE/tools/jaklis/jaklis.py -k ~/.zen/game/players/$PLAYER/secret.dunikey -n "https://data.gchange.fr" stars -p $liking_me > ~/.zen/tmp/Gstars.json
    ## ZOMBIE PROTECTION
    [[ "$?" == "0" && ! -s ~/.zen/tmp/Gstars.json ]] && rm -Rf ~/.zen/game/players/$PLAYER/FRIENDS/$liking_me && echo "$liking_me is a ZOMBIE..." && continue

#### RECUP ANNONCES Gchange
## https://www.gchange.fr/#/app/records/wallet?q=2geH4d2sndR47XWtfDWsfLLDVyNNnRsnUD3b1sk9zYc4&old
## https://www.gchange.fr/#/app/market/records/42LqLa7ARTZqUKGz2Msmk79gwsY8ZSoFyMyPyEnoaDXR

    my_star_level=$(cat ~/.zen/tmp/Gstars.json | jq -r '.yours.level');
    f_score=$(cat ~/.zen/tmp/Gstars.json | jq -r '.score');
    myfriendship=$(cat ~/.zen/tmp/Gstars.json | jq -r '.likes[] | select(.issuer | strings | test("'$G1PUB'"))')
    if [[ "$my_star_level" != "null" && "$liking_me" != "$G1PUB" ]]
    then
        # ADD $liking_me TO MY ipfs FRIENDS list
        echo "$liking_me is Ŋ1 $f_score FRIEND ($my_star_level)"
        mkdir -p ~/.zen/game/players/$PLAYER/FRIENDS/$liking_me

        # REFRESH & PUBLISH stars friends map
        if [[ "$my_star_level" == "null" || "$my_star_level" == "" ]]; then
            rm -Rf ~/.zen/game/players/$PLAYER/FRIENDS/$liking_me
            echo "$my_star_level NO STAR !! Removing $liking_me"
            ## TODO : remove "ipfs pin" in "~/.zen/PIN/"
            continue ## REMOVE NO GOOD FRIENDS (no star)
        fi
        cp ~/.zen/tmp/Gstars.json ~/.zen/game/players/$PLAYER/FRIENDS/$liking_me/ && rm -f ~/.zen/tmp/Gstars.json
        echo "$my_star_level" > ~/.zen/game/players/$PLAYER/FRIENDS/$liking_me/stars.level && echo "***** $my_star_level STARS *****"

        ## Get Ŋ2 LEVEL
        for nid in $(cat ~/.zen/game/players/$PLAYER/FRIENDS/$liking_me/Gstars.json | jq -r '.likes[].issuer');
        do
            echo "Ami(s) de cet Ami $linking_me : $nid"
            friend_of_friend=$(~/.zen/game/players/$PLAYER/FRIENDS/$liking_me/Gstars.json | jq -r '.likes[] | select(.issuer | strings | test("'$nid'"))')
            echo "$friend_of_friend" | jq -r > ~/.zen/game/players/$PLAYER/FRIENDS/$liking_me/fof.json

        done

        echo "***** Convert $liking_me to ipfsnodeid *****"
        ipfsnodeid=$(~/.zen/Astroport.ONE/tools/g1_to_ipfs.py $liking_me)
        echo ${ipfsnodeid} > ~/.zen/game/players/$PLAYER/FRIENDS/$liking_me/ipfsnodeid
    fi

    sleep $((1 + RANDOM % 2)) # SLOW DOWN
done


exit 0
