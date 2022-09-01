#!/bin/bash
########################################################################
# Version: 0.3
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

## PROCESS TW BACKOFFICE TREATMENT

~/.zen/Astroport.ONE/tools/VOEUX.refresh.sh
~/.zen/Astroport.ONE/tools/PLAYER.refresh.sh
