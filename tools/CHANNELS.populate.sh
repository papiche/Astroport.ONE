#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# Construction du canal 'qo-op' à partir des journaux qo-op_$PLAYER
#
################################################################################
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

for player in $(ls ~/.zen/game/players/); do

    echo $player
    qoopns=$(cat ~/.zen/game/players/$PLAYER/.qoopns)
    moans=$(cat ~/.zen/game/players/$PLAYER/.moans)
    playerns=$(cat ~/.zen/game/players/$PLAYER/.playerns)

done

exit 0
