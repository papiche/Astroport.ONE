#!/bin/bash
# Run After PLAYER.entrance.sh
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
myIP=$(hostname -I | awk '{print $1}' | head -n 1)

ME="${0##*/}"
######################################################################### CONNECT PLAYER WITH GCHANGE
# Check who is .current PLAYER
PLAYER="$1"

[[ $PLAYER == "" ]] && PLAYER=$(cat ~/.zen/game/players/.current/.player 2>/dev/null)
[[ $PLAYER == "" ]] && echo "ERROR PLAYER - EXIT" && exit 1
PSEUDO=$(cat ~/.zen/game/players/$PLAYER/.pseudo 2>/dev/null)
[[ $G1PUB == "" ]] && G1PUB=$(cat ~/.zen/game/players/$PLAYER/.g1pub 2>/dev/null)
[[ $G1PUB == "" ]] && echo "ERROR G1PUB - EXIT" && exit 1

ASTRONAUTENS=$(ipfs key list -l | grep -w "$PLAYER" | cut -d ' ' -f 1)
[[ ! $ASTRONAUTENS ]] &&  echo "ERROR ASTRONAUTENS - EXIT" && exit 1

## Directory is created, So this script already run once.
if [[ ! -d ~/.zen/game/players/$PLAYER/FRIENDS/ ]]; then
    ########################################################################
    echo "CREATING $PLAYER GCHANGE+ PROFILE"
    ########################################################################
    $MY_PATH/jaklis/jaklis.py -k ~/.zen/game/players/$PLAYER/secret.dunikey -n "https://data.gchange.fr" set --site "http://tube.copylaradio.com:8080/ipns/$ASTRONAUTENS" #GCHANGE+
    [[ ! $? == 0 ]] && echo "GCHANGE PROFILE CREATION FAILED" && echo "Action Manuelle " $MY_PATH/jaklis/jaklis.py -k ~/.zen/game/players/$PLAYER/secret.dunikey -n "https://data.gchange.fr" set --name "Astronaute $PSEUDO" --avatar "/home/$USER/.zen/Astroport.ONE/images/logo.png" --site "http://qo-op.com:8080/ipns/$ASTRONAUTENS" #GCHANGE+

    ########################################################################
    #echo "CREATING $PLAYER CESIUM+ PROFILE"
    ########################################################################
    $MY_PATH/jaklis/jaklis.py -k ~/.zen/game/players/$PLAYER/secret.dunikey -n "https://g1.data.presles.fr" set --site "http://127.0.0.1:8080/ipns/$ASTRONAUTENS" #CESIUM+
    [[ ! $? == 0 ]] && echo "CESIUM PROFILE CREATION FAILED" && echo "Action Manuelle " $ $MY_PATH/jaklis/jaklis.py -k ~/.zen/game/players/$PLAYER/secret.dunikey -n "https://g1.data.presles.fr" set --name "Astronaute $PLAYER" --avatar "/home/$USER/.zen/Astroport.ONE/images/logo.png" --site "http://127.0.0.1:8080/ipns/$ASTRONAUTENS" #CESIUM+
fi

########################################################################

########################################################################
echo "SCANNING $PLAYER - $G1PUB - Gchange FRIENDS"
########################################################################
################## CHECKING WHO GAVE ME STARS
################## BOOTSTRAP LIKES THEM BACK
################## SEND ipfstryme MESSAGES to FRIENDS
rm -f ~/.zen/tmp/my_star_level
## Getting Gchange  liking_me list
echo "Getting received stars"
################################## JAKLIS PLAYER stars
~/.zen/Astroport.ONE/tools/timeout.sh -t 20 \
~/.zen/Astroport.ONE/tools/jaklis/jaklis.py \
-k ~/.zen/game/players/$PLAYER/secret.dunikey \
-n "https://data.gchange.fr" stars > ~/.zen/tmp/received_stars.json

cat ~/.zen/tmp/received_stars.json | jq -r '.likes[].issuer' | uniq > ~/.zen/tmp/liking_me
echo "cat ~/.zen/tmp/received_stars.json | jq -r"

for liking_me in $(cat ~/.zen/tmp/liking_me | sort | uniq);
do
    [[ "${liking_me}" == "" ]] && continue ## Protect from empty line !!
    echo "........................."
    ASTRONAUTENS=$(~/.zen/Astroport.ONE/tools/g1_to_ipfs.py ${liking_me})
    echo "${liking_me} is Astronaut ?"
    echo "Get TW Capsule http://qo-op.com:8080/ipns/$ASTRONAUTENS "

##### CHECKING IF WE LIKE EACH OTHER Ŋ1 LEVEL
    ################################## JAKLIS LIKING_ME stars
    ~/.zen/Astroport.ONE/tools/timeout.sh -t 20 \
    ~/.zen/Astroport.ONE/tools/jaklis/jaklis.py \
    -k ~/.zen/game/players/$PLAYER/secret.dunikey \
    -n "https://data.gchange.fr" \
    stars -p ${liking_me} > ~/.zen/tmp/${liking_me}.Gstars.json

    echo "Got Stars - DEBUG - cat ~/.zen/tmp/${liking_me}.Gstars.json | jq -r"
    ## ZOMBIE PROTECTION
    [[ "$?" == "0" && ! -s ~/.zen/tmp/${liking_me}.Gstars.json ]] && rm -Rf ~/.zen/game/players/$PLAYER/FRIENDS/${liking_me} && echo "${liking_me} is a ZOMBIE..." && continue

#### RECUP ANNONCES Gchange
## https://www.gchange.fr/#/app/records/wallet?q=2geH4d2sndR47XWtfDWsfLLDVyNNnRsnUD3b1sk9zYc4&old
## https://www.gchange.fr/#/app/market/records/42LqLa7ARTZqUKGz2Msmk79gwsY8ZSoFyMyPyEnoaDXR

    ## DATA EXTRACTION FROM ~/.zen/tmp/${liking_me}.Gstars.json
    my_star_level=$(cat ~/.zen/tmp/${liking_me}.Gstars.json | jq -r '.yours.level');
    f_score=$(cat ~/.zen/tmp/${liking_me}.Gstars.json | jq -r '.score');
    myfriendship=$(cat ~/.zen/tmp/${liking_me}.Gstars.json | jq -r '.likes[] | select(.issuer | strings | test("'$G1PUB'"))')

    ## OH MY FRIEND !
    if [[ "$my_star_level" != "null" && "${liking_me}" != "$G1PUB" ]]
    then
        # ADD ${liking_me} TO MY ipfs FRIENDS list
        echo "${liking_me} ($my_star_level stars) : Ŋ1 SCORE  $f_score "
        mkdir -p ~/.zen/game/players/$PLAYER/FRIENDS/${liking_me}

        cp ~/.zen/tmp/${liking_me}.Gstars.json ~/.zen/game/players/$PLAYER/FRIENDS/${liking_me}/ && rm -f ~/.zen/tmp/${liking_me}.Gstars.json
        echo "$my_star_level" > ~/.zen/game/players/$PLAYER/FRIENDS/${liking_me}/stars.level && echo "***** $my_star_level STARS *****"

        ## GET FRIEND TW !!
        echo "Getting latest online TW..."
        YOU=$(ps auxf --sort=+utime | grep -w ipfs | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1);
        LIBRA=$(head -n 2 ~/.zen/Astroport.ONE/A_boostrap_nodes.txt | tail -n 1 | cut -d ' ' -f 2)
        echo "$LIBRA/ipns/$ASTRONAUTENS"
        echo "http://$myIP:8080/ipns/$ASTRONAUTENS ($YOU)"
        [[ $YOU ]] && ipfs --timeout 12s cat  /ipns/$ASTRONAUTENS > ~/.zen/game/players/$PLAYER/FRIENDS/${liking_me}/index.html \
                            || curl -m 12 -so ~/.zen/game/players/$PLAYER/FRIENDS/${liking_me}/index.html "$LIBRA/ipns/$ASTRONAUTENS"

        ## PLAYER TW IS ONLINE ?
        if [ ! -s ~/.zen/game/players/$PLAYER/FRIENDS/${liking_me}/index.html ]; then
                        # # # # # # # # # # # # # # #
            ## AUCUN VISA ASTRONAUTE ENVOYER UN MESSAGE PAR GCHANGE
            echo "AUCUN TW ACTIF. ENVOYONS LUI UN MESSAGE..."
            $MY_PATH/jaklis/jaklis.py -k ~/.zen/game/players/$PLAYER/secret.dunikey -n "https://data.gchange.fr" send -d "${liking_me}" -t "SALUT. Je suis sur Astroport. Tu viens." -m "Active ton TW avec moi : http://libra.copylaradio.com:1234 - DEV MODE -"
        else
            echo "COOL MON AMI PUBLIE SUR IPFS"
            ls -al ~/.zen/game/players/$PLAYER/FRIENDS/${liking_me}/index.html
            # # # # # # # # # # # # # # # TODO
                 # CHECK Dessin de Moa ?? (DIS)CONNECT PLAYERS
                        # # # # # # # # # # # # # # #

        fi

        ## ACTIVER FILTRAGE TAG...

        ## Get Ŋ2 LEVEL
        for nid in $(cat ~/.zen/game/players/$PLAYER/FRIENDS/${liking_me}/${liking_me}.Gstars.json | jq -r '.likes[].issuer');
        do
            echo "Ami(s) de cet Ami $linking_me : $nid"
            friend_of_friend=$(cat ~/.zen/game/players/$PLAYER/FRIENDS/${liking_me}/${liking_me}.Gstars.json | jq -r '.likes[] | select(.issuer | strings | test("'$nid'"))')
            echo "$friend_of_friend" | jq -r > ~/.zen/game/players/$PLAYER/FRIENDS/${liking_me}/friend_of_friend.json

        done

        echo "***** Keep G1/IPNS conversion *****"
        echo ${ASTRONAUTENS} > ~/.zen/game/players/$PLAYER/FRIENDS/${liking_me}/.astronautens

    else
        echo "ETOILES RECUES!! ... ENVOI MOI UN MESSAGE POUR CONNAITRE QUI"
        $MY_PATH/jaklis/jaklis.py -k ~/.zen/game/players/$PLAYER/secret.dunikey -n "https://data.gchange.fr" send -d "${G1PUB}" -t "ETOILES RECUES (G1STARS  $f_score)" -m "https://www.gchange.fr/#/app/user/${liking_me}/"
         echo "Not Linking ;( YET."
    fi


    sleep $((1 + RANDOM % 2)) # SLOW DOWN
done


exit 0
