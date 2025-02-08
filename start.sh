#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized

echo "ASTROPORT.ONE START
@@@@@@@@@@@@@@@@@@
$USER@$HOSTNAME
@@@@@@@@@@@@@@@@@@"
RUNLEVEL=$1
[[ ! $RUNLEVEL ]] && RUNLEVEL="ON"

echo "cron_VRFY.sh $RUNLEVEL"
###################################################
${MY_PATH}/tools/cron_VRFY.sh $RUNLEVEL
echo "ipfs start"
sudo systemctl start ipfs
sleep 5
echo "astroport start"
sudo systemctl start astroport
echo "g1billet start"
sudo systemctl start g1billet
echo "upassport start"
sudo systemctl start upassport

########################################## NO systemctl mode ########
### OLD METHOD USING SELF PID
#~ echo "(RE)STARTING 12345.sh"
#~ ###################################################
#~ [[ -s ~/.zen/.pid ]] && kill -9 $(cat ~/.zen/.pid) \
                                 #~ || ( killall "12345.sh"; killall "_12345.sh"; killall "nc" )

#~ mkdir -p ~/.zen/tmp
#~ sleep 5

#~ ~/.zen/Astroport.ONE/12345.sh > ~/.zen/tmp/12345.log &
#~ echo $! > ~/.zen/.pid
