#!/bin/bash
########################################################################
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
## EXPLORE SWARM MAPNS
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

. "$MY_PATH/tools/my.sh"
## LOG into ~/.zen/tmp/_12345.log
exec 2>&1 >> ~/.zen/tmp/_12345.log

echo "(◕‿◕ ) ${ME} (◕‿◕ ) "

## LOCAL
LWKEYS=($(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_*_*/_*.?_*.?/_*.??_*.??/_index.html 2>/dev/null | grep -o "url='/[^']*'"| sed "s/url='\(.*\)'/\1/" | awk -F"/" '{print $3}' | shuf ))
echo ${#LWKEYS[@]}  " local UMAPS"
LSKEYS=($(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/SECTORS/_*_*/_*.?_*.?/_index.html 2>/dev/null | grep -o "url='/[^']*'"| sed "s/url='\(.*\)'/\1/" | awk -F"/" '{print $3}' | shuf ))
echo ${#LSKEYS[@]}  " local SECTORS"
LRKEYS=($(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/REGIONS/_*_*/_index.html 2>/dev/null | grep -o "url='/[^']*'"| sed "s/url='\(.*\)'/\1/" | awk -F"/" '{print $3}' | shuf ))
echo ${#LRKEYS[@]} " local REGIONS"

## SWARM
WKEYS=($(cat ~/.zen/tmp/swarm/12D*/UPLANET/__/_*_*/_*.?_*.?/_*.??_*.??/_index.html  2>/dev/null | grep -o "url='/[^']*'"| sed "s/url='\(.*\)'/\1/" | awk -F"/" '{print $3}' | shuf ))
echo ${#WKEYS[@]}  " swarm  UMAPS"
SKEYS=($(cat ~/.zen/tmp/swarm/12D*/UPLANET/SECTORS/_*_*/_*.?_*.?/_index.html 2>/dev/null | grep -o "url='/[^']*'"| sed "s/url='\(.*\)'/\1/" | awk -F"/" '{print $3}' | shuf ))
echo ${#SKEYS[@]}  " swarm SECTORS"
RKEYS=($(cat ~/.zen/tmp/swarm/12D*/UPLANET/REGIONS/_*_*/_index.html 2>/dev/null | grep -o "url='/[^']*'"| sed "s/url='\(.*\)'/\1/" | awk -F"/" '{print $3}' | shuf ))
echo ${#RKEYS[@]} " swarm REGIONS"

## CHECK FOR ANY ALREADY MErunning
MErunning=$(ps axf --sort=+utime | grep -w ${ME} | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1)
[[ $MErunning ]] && echo "${ME} MErunning for too long..." && kill -9 $MErunning

echo "(◕‿◕ ) ${ME} starting UPlanet Terraformation _______________________________"

combined=("${LWKEYS[@]}" "${LSKEYS[@]}" "${LRKEYS[@]}" "${WKEYS[@]}" "${SKEYS[@]}" "${RKEYS[@]}")
UKEYS=($(echo "${combined[@]}" | tr ' ' '\n' | sort -u))
echo ${#UKEYS[@]} "  JOBS..."

## STORAGE FOR IPFS GET on UPLANET KEYS
mkdir -p ~/.zen/tmp/flashmem

floop=0
medo=0

for key in ${UKEYS[@]}; do
    [[ -d ~/.zen/tmp/flashmem/$key ]] \
        && echo "$key already copied" && medo=$((medo +1)) && continue

    mkdir -p ~/.zen/tmp/flashmem/$key
    echo "ipfs --timeout 180s get -o ~/.zen/tmp/flashmem/$key /ipns/$key"
    ipfs --timeout 180s get -o ~/.zen/tmp/flashmem/$key /ipns/$key
    [[ $? == 0 ]] && medo=$((medo +1)) || rm -Rf ~/.zen/tmp/flashmem/$key

    floop=$((floop +1))
    [ $floop -gt 33 ] && break
done

echo "(◕‿◕ ) ${ME} :: $medo SUCCESS over $floop KEYS from ${#UKEYS[@]} JOBS"
