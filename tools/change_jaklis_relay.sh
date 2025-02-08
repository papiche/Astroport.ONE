#!/bin/bash
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized

################################################################################
## SELECT RANDOM IN SYNC NODE
${HOME}/.zen/Astroport.ONE/tools/duniter_getnode.sh > /tmp/duniter_getnode.out
GVA=$(cat /tmp/duniter_getnode.out | tail -n 1)
cat /tmp/duniter_getnode.out
rm /tmp/duniter_getnode.out
################################################################################
## Changing GVA SERVER in tools/jaklis/.env
################################################################################
if [[ ! -z $GVA ]]; then
    sed -i '/^NODE=/d' ${MY_PATH}/../tools/jaklis/.env
    echo "NODE=$GVA" >> ${MY_PATH}/../tools/jaklis/.env
    echo "NEW GVA NODE=$GVA"
else
    echo "ERROR duniter GVA server unchanged"
    exit 1
fi
exit 0
