#!/bin/bash
########################################################################
# Author: Fred (support@qo-op.com)
# Version: 2020.03.21
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"
echo '
########################################################################
# \\///
# qo-op
############# '$MY_PATH/$ME'
########################################################################
# Activate / Desactivate ASTROPORT 20h12.sh job
########################################################################'
# Clean
rm -f /tmp/mycron /tmp/newcron
# Get crontab
crontab -l > /tmp/mycron

# DOUBLE CHECK (awk = nawk or gawk -i ?)
# Remove any previous line containing "SHELL & PATH"
# awk -i inplace -v rmv="20h12" '!index($0,rmv)' /tmp/mycron
awk -i inplace -v rmv="SHELL" '!index($0,rmv)' /tmp/mycron
awk -i inplace -v rmv="PATH" '!index($0,rmv)' /tmp/mycron

crontest=$(cat /tmp/mycron | grep -F '20h12.sh')

if [[ ! $crontest ]]; then
    ## HEADER
    [[ ! $(cat /tmp/mycron | grep -F 'SHELL') ]] && echo "SHELL=/bin/bash" > /tmp/newcron
    [[ ! $(cat /tmp/mycron | grep -F 'PATH') ]] && echo "PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin" >> /tmp/newcron
    cat /tmp/mycron >> /tmp/newcron
    # ADD  20h12.sh line
    echo "12  20  *  *  *   /bin/bash $MY_PATH/../20h12.sh 2>&1>/dev/null" >> /tmp/newcron
    crontab /tmp/newcron
    sudo systemctl enable ipfs
    sudo systemctl start ipfs
    echo "ASTROPORT is ON"
    [[ $1 == "ON" ]] && exit 0
else
    ## HEADER
    [[ ! $(cat /tmp/mycron | grep -F 'SHELL') ]] && echo "SHELL=/bin/bash" > /tmp/newcron
    [[ ! $(cat /tmp/mycron | grep -F 'PATH') ]] && echo "PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin" >> /tmp/newcron
    ## REMOVE 20h12.sh line
    cat /tmp/mycron | grep -Ev '20h12.sh' >> /tmp/newcron
    crontab /tmp/newcron
    sudo systemctl stop ipfs
    sudo systemctl disable ipfs
    echo "ASTROPORT is OFF"
    [[ $1 == "OFF" ]] && exit 0
fi


exit 0
