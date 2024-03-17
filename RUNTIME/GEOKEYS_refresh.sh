#!/bin/bash
########################################################################
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
## EXPLORE SWARM MAPNS
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

. "$MY_PATH/../tools/my.sh"
## LOG into ~/.zen/tmp/_12345.log
exec 2>&1 >> ~/.zen/tmp/_12345.log

echo "=========================="
echo "(◕‿◕ ) ${ME} (◕‿◕ ) "
#~ ## CHECK IF ALREADY MErunning
countMErunning=$(ps auxf --sort=+utime | grep -w $ME | grep -v -E 'color=auto|grep' | wc -l)
[[ $countMErunning -gt 2 ]] && echo "$ME already running $countMErunning time" && exit 0

echo "(◕‿◕ ) ${ME} starting UPlanet Key Scan _______________________________"

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

## COMBINE & SHUFFLE KEYS
combined=("${LWKEYS[@]}" "${LSKEYS[@]}" "${LRKEYS[@]}" "${WKEYS[@]}" "${SKEYS[@]}" "${RKEYS[@]}")
UKEYS=($(echo "${combined[@]}" | tr ' ' '\n' | sort -u))
echo "SYNC ${#UKEYS[@]} GEOKEYS..."

## STORAGE FOR IPFS GET UplanetKeyS
mkdir -p ~/.zen/tmp/flashmem

## Remove flashmem/UplanetKey older than 3 hours
find ~/.zen/tmp/flashmem -mmin +180 -exec rm -rf {} +

floop=0
medo=0
for key in ${UKEYS[@]}; do

    [[ -d ~/.zen/tmp/flashmem/$key ]] \
        && echo "$key already copied" && medo=$((medo +1)) && continue

    floop=$((floop +1))
    mkdir -p ~/.zen/tmp/flashmem/$key

    echo "ipfs --timeout 180s get -o ~/.zen/tmp/flashmem/$key /ipns/$key"
    ipfs --timeout 180s get -o ~/.zen/tmp/flashmem/$key /ipns/$key
    [[ $? == 0 ]] \
        && medo=$((medo +1)) && floop=$((floop -1)) \
        || rm -Rf ~/.zen/tmp/flashmem/$key # GOT IT or NOT ?

    [ $floop -gt 33 ] && break

done
echo "=========================="
echo "(◕‿◕ ) ${ME} :: $medo SUCCESS missing $floop KEYS from ${#UKEYS[@]} GEOKEYS"
echo "=========================="

## Search for TW /ipfs/ and refresh
TWS=($(cat ~/.zen/tmp/flashmem/*/TWz/*/_index.html | grep -o "url='/[^']*'"| sed "s/url='\(.*\)'/\1/" | awk -F"/" '{print $3}' | shuf))
echo "SYNC ${#TWS[@]} TWs..."
floop=0
medo=0
for tw in ${TWS[@]}; do

    [[ -d ~/.zen/tmp/flashmem/tw/$tw ]] \
        && echo "$key already copied" && medo=$((medo +1)) && continue

    floop=$((floop +1))
    mkdir -p ~/.zen/tmp/flashmem/tw/$tw

    ipfs --timeout 180s get -o ~/.zen/tmp/flashmem/tw/$tw /ipns/$tw
    [[ $? == 0 ]] \
        && medo=$((medo +1)) && floop=$((floop -1)) \
        || rm -Rf ~/.zen/tmp/flashmem/tw/$tw

    [ $floop -gt 33 ] && break

done

echo "=========================="
echo "(✜‿‿✜) ${ME} :: $medo SUCCESS missing $floop KEYS from ${#TWS[@]} TWS"
echo "=========================="

exit 0
