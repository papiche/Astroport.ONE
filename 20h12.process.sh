#!/bin/bash
########################################################################
# Version: 0.3
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"
start=`date +%s`
## PROCESS TW BACKOFFICE TREATMENT

cd ~/.zen/Astroport.ONE/
git pull

~/.zen/Astroport.ONE/ASTROBOT/VOEUX.refresh.sh
~/.zen/Astroport.ONE/ASTROBOT/PLAYER.refresh.sh


########################################################################
end=`date +%s`
echo Execution time was `expr $end - $start` seconds.
exit 0
