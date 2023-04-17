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
############# '$MY_PATH/$ME $1'
########################################################################
# Activate / Desactivate ASTROPORT 20h12.process.sh job & IPFS daemon
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

crontest=$(cat /tmp/mycron | grep -F '20h12.process.sh')

## TODO check for Station geoposition in ~/.zen/GPS and calibrate 20H12
cat ~/.zen/GPS 2>/dev/null && echo " TODO calibrate 20H12 with GPS"

if [[ ! $crontest ]]; then
    ## HEADER
    [[ $1 == "OFF" ]] && exit 0
    [[ ! $(cat /tmp/mycron | grep -F 'SHELL') ]] && echo "SHELL=/bin/bash" > /tmp/newcron
    [[ ! $(cat /tmp/mycron | grep -F 'PATH') ]] && echo "PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin" >> /tmp/newcron
    cat /tmp/mycron >> /tmp/newcron
    # ADD  20h12.process.sh line
    echo "12  20  *  *  *   /bin/bash $MY_PATH/../20h12.process.sh > /tmp/20h12.log 2>&1" >> /tmp/newcron
    crontab /tmp/newcron
    [[ $1 != "LOW" ]] && sudo systemctl enable ipfs
    sudo systemctl enable astroport
    sudo systemctl enable g1billet
    [[ $1 != "LOW" ]] && sudo systemctl start ipfs
    sudo systemctl start astroport
    sudo systemctl start g1billet
    echo "ASTROPORT is ON"

else
    ## HEADER
    [[ $1 == "ON" ]] && exit 0
    [[ ! $(cat /tmp/mycron | grep -F 'SHELL') ]] && echo "SHELL=/bin/bash" > /tmp/newcron
    [[ ! $(cat /tmp/mycron | grep -F 'PATH') ]] && echo "PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin" >> /tmp/newcron
    ## REMOVE 20h12.process.sh line
    cat /tmp/mycron | grep -Ev '20h12.process.sh' >> /tmp/newcron
    crontab /tmp/newcron
    sudo systemctl stop ipfs
    sudo systemctl disable ipfs
    echo "ASTROPORT IPFS is OFF (20H12 START ONLY)"

    if [[ $1 == "LOW" ]]; then
        echo "KEEPING 20H12 CRON ACTIVATED"
        ## LOW DISK RESSOURCES IPFS MODE
        [[ ! $(cat /tmp/mycron | grep -F 'SHELL') ]] && echo "SHELL=/bin/bash" > /tmp/newcron
        [[ ! $(cat /tmp/mycron | grep -F 'PATH') ]] && echo "PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin" >> /tmp/newcron
        cat /tmp/mycron >> /tmp/newcron
        # ADD  20h12.process.sh line
        [[ ! $(cat /tmp/mycron | grep '20h12.process.sh') ]] && echo "12  20  *  *  *   /bin/bash $MY_PATH/../20h12.process.sh > /tmp/20h12.log 2>&1" >> /tmp/newcron
        crontab /tmp/newcron

    fi


fi


exit 0
