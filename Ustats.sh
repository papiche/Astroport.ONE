#!/bin/bash
####################################
# stats.sh
# analyse LOCAL & SWARM data structure
####################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

. "${MY_PATH}/tools/my.sh"
echo "==========================================================="

####################################
# search for active TWS
####################################
echo " ## SEARCH TW in UPLANET/__/_*_*/_*.?_*.?/_*.??_*.??/TW/*"
METW=($(ls -d ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_*_*/_*.?_*.?/_*.??_*.??/TW/* 2>/dev/null | rev | cut -d '/' -f 1 | rev | sort | uniq))
SWARMTW=($(ls -d ~/.zen/tmp/swarm/*/UPLANET/__/_*_*/_*.?_*.?/_*.??_*.??/TW/* 2>/dev/null | rev | cut -d '/' -f 1 | rev | sort | uniq))
combined=("${METW[@]}" "${SWARMTW[@]}")
unique_combined=($(echo "${combined[@]}" | tr ' ' '\n' | sort -u))

echo "${#unique_combined[@]} TW(S) : ${unique_combined[@]}"
echo "==========================================================="

####################################
# search for active UMAPS
####################################
echo " ## SEARCH UMAPS in UPLANET/__/_*_*/_*.?_*.?/*"
MEMAPS=($(ls -td ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_*_*/_*.?_*.?/* 2>/dev/null | rev | cut -d '/' -f 1 | rev | sort | uniq))
SWARMMAPS=($(ls -Gd ~/.zen/tmp/swarm/*/UPLANET/__/_*_*/_*.?_*.?/* 2>/dev/null | rev | cut -d '/' -f 1 | rev | sort | uniq))
combined=("${MEMAPS[@]}" "${SWARMMAPS[@]}")
unique_combined=($(echo "${combined[@]}" | tr ' ' '\n' | sort -u))

echo "${#unique_combined[@]} UMAP(S) : ${unique_combined[@]}"
echo "==========================================================="
for umap in ${unique_combined[@]}; do
    lat=$(echo $umap | cut -d '_' -f 2)
    lon=$(echo $umap | cut -d '_' -f 3)
    echo $lat $lon
    ${MY_PATH}/tools/getUMAP_ENV.sh $lat $lon | tail -n 1
    echo
done
