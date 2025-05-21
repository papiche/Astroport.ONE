#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.2
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "$MY_PATH/../tools/my.sh"
################################################################################
start=`date +%s`
## SECTOR REFRESH
# SHARE & UPDATE IPNS TOGETHER
############################################
echo
echo
echo "############################################"
echo "############################################"
echo "> RUNNING SECTOR.refresh"
echo "############################################"
echo "############################################"
[[ ${IPFSNODEID} == "" ]] && echo "IPFSNODEID is empty - EXIT -" && exit 1

MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
mkdir ~/.zen/tmp/${MOATS}

## UMAPS list made BY UPLANET.refresh.sh
for i in $*; do
    UMAPS=("$i" ${UMAPS[@]})
done

## NO $i PARAMETERS - GET ALL UMAPS
if [[ ${#UMAPS[@]} == 0 ]]; then
    MEMAPS=($(ls -td ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_*_*/_*.?_*.?/* 2>/dev/null | rev | cut -d '/' -f 1 | rev | sort | uniq))
    SWARMMAPS=($(ls -Gd ~/.zen/tmp/swarm/*/UPLANET/__/_*_*/_*.?_*.?/* 2>/dev/null | rev | cut -d '/' -f 1 | rev | sort | uniq))
    combined=("${MEMAPS[@]}" "${SWARMMAPS[@]}")
    UMAPS=($(echo "${combined[@]}" | tr ' ' '\n' | sort -u))
fi
######## INIT SECTORS ########################
for UMAP in ${UMAPS[@]}; do

    LAT=$(echo ${UMAP} | cut -d '_' -f 2)
    LON=$(echo ${UMAP} | cut -d '_' -f 3)

    [[ ${LAT} == "" || ${LON} == "" ]] && echo ">> ERROR BAD ${LAT} ${LON}" && continue
    [[ ${LAT} == "null" || ${LON} == "null" ]] && echo ">> ERROR BAD ${LAT} ${LON}" && continue

    SLAT="${LAT::-1}"
    SLON="${LON::-1}"

    MYSECTORS=("_${SLAT}_${SLON}" ${MYSECTORS[@]})

done

## GET UNIQ SECTORS LIST
SECTORS=($(echo "${MYSECTORS[@]}" | tr ' ' '\n' | sort -u))

[[ ${SECTORS[@]} == "" ]] && echo "> NO SECTOR FOUND" && exit 0
#########################################################""
echo "ACTIVATED SECTORS : ${SECTORS[@]}"

for SECTOR in ${SECTORS[@]}; do
    echo "############################################"
    echo "_____SECTOR ${SECTOR}"
    echo "################################  $(date)"
    mkdir -p ~/.zen/tmp/${MOATS}/${SECTOR}/CHAIN/
    SLAT=$(echo ${SECTOR} | cut -d '_' -f 2)
    SLON=$(echo ${SECTOR} | cut -d '_' -f 3)

    ##############################################################
    ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/tmp/${MOATS}/${SECTOR}.dunikey "${UPLANETNAME}${SECTOR}" "${UPLANETNAME}${SECTOR}"
    G1PUB=$(cat ~/.zen/tmp/${MOATS}/${SECTOR}.dunikey | grep 'pub:' | cut -d ' ' -f 2)
    [[ ! ${G1PUB} ]] && echo "ERROR generating SECTOR WALLET" && exit 1

    COINS=$($MY_PATH/../tools/COINScheck.sh ${G1PUB} | tail -n 1)
    ZEN=$(echo "($COINS - 1) * 10" | bc | cut -d '.' -f 1)

    ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/${SECTOR}.priv "${UPLANETNAME}${SECTOR}" "${UPLANETNAME}${SECTOR}"
    ipfs key rm ${G1PUB} > /dev/null 2>&1 ## AVOID ERROR ON IMPORT
    SECTORNS=$(ipfs key import ${G1PUB} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/${SECTOR}.priv)

    echo "___ ORIGIN ___ ${myIPFS}/ipns/${SECTORNS}/"
    echo "SECTOR : ${SECTOR} (${COINS} G1 <=> ${ZEN} ZEN) : ${G1PUB}"

    ###################### SPATIO TEMPORAL KEYS
    ## YESTERDATE ###############
    ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/${YESTERDATE}.priv "${YESTERDATE}${UPLANETNAME}${SECTOR}" "${YESTERDATE}${UPLANETNAME}${SECTOR}"
    ipfs key rm ${YESTERDATE}${G1PUB} > /dev/null 2>&1
    YESTERDATENS=$(ipfs key import ${YESTERDATE}${G1PUB} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/${YESTERDATE}.priv)
    echo "YESTERDAY : ${myIPFS}/ipns/${YESTERDATENS}"

    ## TODATE #########################################
    ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/${TODATE}.priv  "${TODATE}${UPLANETNAME}${SECTOR}" "${TODATE}${UPLANETNAME}${SECTOR}"
    ipfs key rm ${TODATE}${G1PUB} > /dev/null 2>&1
    TODATENS=$(ipfs key import ${TODATE}${G1PUB} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/${TODATE}.priv)
    echo "TODAY : ${myIPFS}/ipns/${TODATENS}"

    # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    start=`date +%s`
    # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    #~ ## IPFS GET ONLINE YESTERDATE SECTORNS
    ipfs --timeout 180s get --progress=false -o ~/.zen/tmp/${MOATS}/${SECTOR}/ /ipns/${YESTERDATENS}/
    if [[ $? != 0 ]]; then
        echo "(╥☁╥ ) swarm memory empty (╥☁╥ )"
        # Try retieve memory from UPlanet ZEN Memory
        [[ ${ZEN} -gt 0 ]] \
            && echo "INTERCOM Refreshing from ZEN MEMORY" \
            && ${MY_PATH}/../RUNTIME/ZEN.SECTOR.memory.sh "${SECTOR}" "${MOATS}" "${G1PUB}"
    fi
    # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    end=`date +%s`
    echo "_____SECTOR${SECTOR} GET time was "`expr $end - $start` seconds.
    # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

    ### SHOW ${SECTOR}
    mkdir -p ~/.zen/tmp/${MOATS}/${SECTOR}/${SECTOR}
    ## CONTROL CHAIN TIME
    ZCHAIN=$(cat ~/.zen/tmp/${MOATS}/${SECTOR}/CHAIN/_chain | rev | cut -d ':' -f 1 | rev 2>/dev/null)
    ZMOATS=$(cat ~/.zen/tmp/${MOATS}/${SECTOR}/CHAIN/_moats 2>/dev/null)
    [[ ${ZCHAIN} && ${ZMOATS} ]] \
        && cp ~/.zen/tmp/${MOATS}/${SECTOR}/CHAIN/_chain ~/.zen/tmp/${MOATS}/${SECTOR}/CHAIN/_chain.${ZMOATS} \
        && echo "UPDATING MOATS ${MOATS}"

    MOATS_SECONDS=$(${MY_PATH}/../tools/MOATS2seconds.sh ${MOATS})
    ZMOATS_SECONDS=$(${MY_PATH}/../tools/MOATS2seconds.sh ${ZMOATS})
    DIFF_SECONDS=$((MOATS_SECONDS - ZMOATS_SECONDS))
    hours=$((DIFF_SECONDS / 3600))
    minutes=$(( (DIFF_SECONDS % 3600) / 60 ))
    seconds=$((DIFF_SECONDS % 60))
    echo "SECTOR DATA is ${hours} hours ${minutes} minutes ${seconds} seconds OLD"

    # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    ## CONTROL ACTINGNODE : BOOSTRAP DISTRIBUTED (jeu du mouchoir, token ring aléatoire)
    UREFRESH="${HOME}/.zen/tmp/${MOATS}/${SECTOR}/CHAIN/SECTOR.refresher"
    ALLNODES=($(cat ${UREFRESH}  | grep -v '^[[:space:]]*$' 2>/dev/null)) # ${ALLNODES[@]} without empty line
    STRAPS=($(cat ${STRAPFILE} | grep -Ev "#" | rev | cut -d '/' -f 1 | rev | grep -v '^[[:space:]]*$')) ## ${STRAPS[@]}

    if [[ ${ALLNODES[@]} == "" ]]; then
        for STRAP in ${STRAPS[@]}; do
                echo ${STRAP} >> ${UREFRESH} ## FILL SECTOR.refresher file with all STRAPS
        done
        ALLNODES=($(cat ${UREFRESH} 2>/dev/null)) # ${ALLNODES[@]}
    fi

    ACTINGNODE=${ALLNODES[0]} ## FIST NODE IN SECTOR.refresher

    ## IN CASE OLD BOOSTRAP IS STILL IN CHARGE - CHOOSE 1ST STRAP -
    [[ ! $(echo ${STRAPS[@]} | grep  ${ACTINGNODE}) ]] && ACTINGNODE=${STRAPS[0]}

    ## IF NOT UPDATED FOR TOO LONG : STRAPS[0] get key control
    [ ${DIFF_SECONDS} -gt $(( 26 * 60 * 60 )) ] \
        && echo ">>>>>>>>>>>>>> More than 26H update - BOOSTRAP 0 ACTION -" \
        && ACTINGNODE=${STRAPS[0]}

    echo "* ACTINGNODE=${ACTINGNODE}"

    if [[ "${ACTINGNODE}" != "${IPFSNODEID}" ]]; then
        echo ">> ACTINGNODE NOT ME - CONTINUE -"
        ipfs key rm "${TODATE}${G1PUB}" "${YESYERDATE}${G1PUB}" "${G1PUB}"
        echo "------8<-------------8<------------------8<-----------------8<-----------------8<"
        continue
    fi
### NEXT REFRESHER SHUFFLE
    rm ${UREFRESH}
    for STRAP in ${STRAPS[@]}; do
        echo ${STRAP} >> ${UREFRESH} ## RESET SECTOR.refresher file with actual STRAPS
    done
    # SHUFFLE UMAP.refresher
    cat ${UREFRESH} | sort | uniq | shuf  > ${UREFRESH}.shuf
    mv ${UREFRESH}.shuf ${UREFRESH}
    echo "SETTING NEXT REFRESHER : $(cat ${UREFRESH} | head -n 1)"

    ############ 0 ZEN (1 G1) INIT ?!
    #~ CURRENT=$(readlink ~/.zen/game/players/.current | rev | cut -d '/' -f 1 | rev)
    #~ [[ ${COINS} == "" || ${COINS} == "null" ]] \
        #~ && [[ ${ZEN} -lt 100 && ${CURRENT} != "" ]] \
        #~ && ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/tmp/${MOATS}/${MOATS}.key "${UPLANETNAME}" "${UPLANETNAME}" \
        #~ && ${MY_PATH}/../tools/PAY4SURE.sh "${HOME}/.zen/tmp/${MOATS}/${MOATS}.key" "${G1LEVEL1}" "${G1PUB}" "UPLANET${UPLANETG1PUB:0:8}:INIT:${SECTOR}" \
        #~ && echo "UPLANET${UPLANETG1PUB:0:8}:INIT:${SECTOR}" && echo " ~~~ (♥‿‿♥) ~~ ${SECTOR} ~~ (♥‿‿♥) ~~~ " \
        #~ && rm ~/.zen/tmp/${MOATS}/${MOATS}.key

##############################################################
    ## FEED SECTOR TW WITH UMAPS RSS
    mkdir -p ~/.zen/tmp/${MOATS}/${SECTOR}/TW
    INDEX="${HOME}/.zen/tmp/${MOATS}/${SECTOR}/TW/index.html"

    ## NEW TW TEMPLATE
    [[ ! -s ${INDEX} ]] \
        && sed "s~_SECTOR_~${SECTOR}~g" ${MY_PATH}/../templates/twsector.html > ${INDEX} \
        && echo "REFRESHING SECTOR FROM empty TEMPLATE *****" \
        && [[ ${IPFSNODEID} != ${STRAPS[0]} ]] && echo "1ST BOOSTRAP JOB" && continue

    ## SET SECTOR
    sed -i "s~_SECTOR_~${SECTOR}~g" ${INDEX}

    ## REFRESH ALL TWs in that SECTOR
    rm -Rf ~/.zen/tmp/${MOATS}/${SECTOR}/TWz
    mkdir -p ~/.zen/tmp/${MOATS}/${SECTOR}/TWz

    cp -rf ~/.zen/tmp/swarm/12D*/UPLANET/__/_*_*/_${SLAT}_${SLON}/_*_*/TW/* \
        ~/.zen/tmp/${MOATS}/${SECTOR}/TWz
    cp -rf ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_*_*/_${SLAT}_${SLON}/_*_*/TW/* \
        ~/.zen/tmp/${MOATS}/${SECTOR}/TWz 2>/dev/null

    ## GET ALL RSS json's AND Feed SECTOR TW with it
    RSSNODE=($(ls ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_*_*/_${SLAT}_${SLON}/_*_*/RSS/*.rss.json 2>/dev/null))
    NL=${#RSSNODE[@]}

    RSSWARM=($(ls ~/.zen/tmp/swarm/12D*/UPLANET/__/_*_*/_${SLAT}_${SLON}/_*_*/RSS/*.rss.json 2>/dev/null))
    NS=${#RSSWARM[@]}

    combinedrss=("${RSSNODE[@]}" "${RSSWARM[@]}")
    RSSALL=($(echo "${combinedrss[@]}" | tr ' ' '\n' | sort -u))

    mkdir -p ~/.zen/tmp/${MOATS}/${SECTOR}/RSS
    rm -f ~/.zen/tmp/${MOATS}/${SECTOR}/RSS/_all.json

    #################### RSS2UPlanetSECTORTW #########################
    ############################ TRANSFER SIGNED TIDDLER IN SECTOR TW
    for RSS in ${RSSALL[@]}; do
        echo "Treating ${RSS}"
        ############################################################
        ## Extract New Tiddlers and maintain fusion in Sector TW.
        ############################################################
        ${MY_PATH}/RSS2UPlanetSECTORTW.sh "${RSS}" "${SECTOR}" "${MOATS}" "${INDEX}"
        ############################################################
        cp ${RSS} ~/.zen/tmp/${MOATS}/${SECTOR}/RSS/
        ############################################################
    done
    TOTL=$((${NL}+${NS}))
    ##############################################################
    ## create sector RSS manifest.json
    ${MY_PATH}/../tools/json_dir.all.sh ~/.zen/tmp/${MOATS}/${SECTOR}/RSS

    # Update COIN & ZEN value
    echo ${COINS} > ~/.zen/tmp/${MOATS}/${SECTOR}/COINS
    echo ${ZEN} > ~/.zen/tmp/${MOATS}/${SECTOR}/ZEN

    echo "Number of RSS : "${TOTL}
    echo ${TOTL} > ~/.zen/tmp/${MOATS}/${SECTOR}/N

###########################################################################################
## MAKE SECTOR PLANET WITH ASTONAUTENS LINKS
###########################################################################################
###########################################################################################
    ## PREPARE Ŋ1 WORLD MAP ##################################################################
    echo "var examples = {};
    examples['locations'] = function() {
    var locations = {
    " > ~/.zen/tmp/world.js
    floop=1

    SWARMTW=($(ls ~/.zen/tmp/swarm/*/UPLANET/__/_*_*/_${SLAT}_${SLON}/_*_*/TW/*/index.html 2>/dev/null))
    NODETW=($(ls ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_*_*/_${SLAT}_${SLON}/_*_*/TW/*/index.html 2>/dev/null))
    TWFILES=("${SWARMTW[@]}" "${NODETW[@]}")

    for TWRED in ${TWFILES[@]}; do
        ZMAIL=$(echo ${TWRED} | rev | cut -d '/' -f 2 | rev)
        TWADD=$(cat ${TWRED}  | grep -o "/ipns/[^\"]*" | sed "s/'$//")
        [[ -z ${TWADD} ]] && TWADD=$(cat ${TWRED}  | grep -o "/ipfs/[^\"]*" | sed "s/'$//")

        ## ADD ASTRONAUTNS ON SECTOR WORLD MAP
        echo "${floop}: {
          alpha: Math.random() * 2 * Math.PI,
          delta: Math.random() * 2 * Math.PI,
          name: '"${ZMAIL}"',
          link: '"${TWADD}"'
        }
        ," >> ~/.zen/tmp/world.js

        ((floop++))
    done

    # REMOVE la dernière virgule
    sed -i '$ d' ~/.zen/tmp/world.js
    ##################################
    ## FINISH LOCATIONS
    echo "
    };
       \$('#sphere').earth3d({
        locationsElement: \$('#locations'),
        dragElement: \$('#locations'),
        locations: locations
      });
    };
    " >> ~/.zen/tmp/world.js

    IAMAP=$(ipfs add -qw ~/.zen/tmp/world.js | tail -n 1)
    echo "JSON WISH WORLD READY /ipfs/${IAMAP}/world.js"

    ###########################################################################################
    ## ADD SECTOR ZENPUB.png & INFO.png
    convert -font 'Liberation-Sans' \
            -pointsize 80 -fill purple -draw 'text 50,120 "'"${ZEN} Zen"'"' \
            -pointsize 30 -fill purple -draw 'text 40, 180 "'"${SECTOR}:${YESTERDATE}"'"' \
            $MY_PATH/../images/G1WorldMap.png "${HOME}/.zen/tmp/${MOATS}/${SECTOR}.png"
    # CREATE G1PUB AMZQR
    amzqr ${G1PUB} -l H -p "$MY_PATH/../images/zenticket.png" -c -n ZENPUB.png -d ~/.zen/tmp/${MOATS}/${SECTOR}/
    convert ~/.zen/tmp/${MOATS}/${SECTOR}/ZENPUB.png -resize 250 ~/.zen/tmp/${MOATS}/ZENPUB.png
    # ADD IT
    composite -compose Over -gravity NorthEast -geometry +0+0 ~/.zen/tmp/${MOATS}/ZENPUB.png ~/.zen/tmp/${MOATS}/${SECTOR}.png ~/.zen/tmp/${MOATS}/${SECTOR}/INFO.png

    ## zday marking
    rm ~/.zen/tmp/${MOATS}/${SECTOR}/z* 2>/dev/null
    echo "<meta http-equiv=\"refresh\" content=\"0; url='/ipfs/${ZCHAIN}'\" />${TODATE} ${SECTOR}" > ~/.zen/tmp/${MOATS}/${SECTOR}/z$(date +%A-%d_%m_%Y).html

    ###########################################################################################
    ### APPLY ON APP MODEL TODATE REGIONNS LINKING
    RLAT=$(echo ${SLAT} | cut -d '.' -f 1)
    RLON=$(echo ${SLON} | cut -d '.' -f 1)
    REGION="_${RLAT}_${RLON}"
    TODATEREGIONNS=$(${MY_PATH}/../tools/keygen -t ipfs "${TODATE}${UPLANETNAME}${REGION}" "${TODATE}${UPLANETNAME}${REGION}")
    REGIONG1PUB=$(${MY_PATH}/../tools/keygen -t duniter "${TODATE}${UPLANETNAME}${REGION}" "${TODATE}${UPLANETNAME}${REGION}")

    PHONEBOOTH="${G1PUB::30}"
    cat ${MY_PATH}/../templates/UPlanetSector/index.html \
            | sed -e "s~_ZONE_~SECTOR ${SECTOR}~g" \
              -e "s~_UPZONE_~REGION ${REGION}~g" \
              -e "s~QmYdWBx32dP14XcbXF7hhtDq7Uu6jFmDaRnuL5t7ARPYkW/index_fichiers/world.js~${IAMAP}/world.js~g" \
              -e "s~_ZONENS_~${TODATENS}~g" \
              -e "s~_ZCHAIN_~${ZCHAIN}~g" \
              -e "s~_UPZONENS_~${TODATEREGIONNS}~g" \
              -e "s~_SECTORG1PUB_~${G1PUB}~g" \
              -e "s~_IPFSNINJA_~${VDONINJA}~g" \
              -e "s~_CESIUMIPFS_~${CESIUMIPFS}~g" \
              -e "s~_HACKGIPFS_~${HACKGIPFS}~g" \
              -e "s~_PHONEBOOTH_~${PHONEBOOTH}~g" \
              -e "s~_LAT_~${SLAT}~g" \
              -e "s~_LON_~${SLON}~g" \
              -e "s~_EARTHCID_~/ipns/copylaradio.com~g" \
              -e "s~_ZCHAIN_~${ZCHAIN}~g" \
              -e "s~_DATE_~$(date +%A-%d_%m_%Y)~g" \
              -e "s~_UPLANETLINK_~/ipns/copylaradio.com/map_render.html\?southWestLat=${RLAT}\&southWestLon=${RLON}\&deg=1~g" \
              -e "s~http://127.0.0.1:8080~~g" \
    > ~/.zen/tmp/${MOATS}/${SECTOR}/_index.html

    ##################################
    cp -f ~/.zen/tmp/${MOATS}/${SECTOR}/_index.html ~/.zen/tmp/${MOATS}/${SECTOR}/index.html
    rm ~/.zen/tmp/${MOATS}/${SECTOR}/index.html ## MAKE SECTOR VISIBLE ##
###################################################### CHAINING BACKUP
    IPFSPOP=$(ipfs add -rwq ~/.zen/tmp/${MOATS}/${SECTOR}/* | tail -n 1)

################
    ## DOES CHAIN CHANGED or INIT ?
    [[ ${ZCHAIN} != ${IPFSPOP} || ${ZCHAIN} == "" ]] \
        && echo "${MOATS}:${IPFSNODEID}:${IPFSPOP}" > ~/.zen/tmp/${MOATS}/${SECTOR}/CHAIN/_chain \
        && echo "${MOATS}" > ~/.zen/tmp/${MOATS}/${SECTOR}/CHAIN/_moats \
        && IPFSPOP=$(ipfs add -rwq ~/.zen/tmp/${MOATS}/${SECTOR}/* | tail -n 1) && echo "ROOT was ${ZCHAIN}"
######################################################
    ## ZEN CHAINING
    # Send 1 ZEN to UPlanet REGIONG1PUB Wallet containing REGION TW HASH
    INTERCOM="UPLANET${UPLANETG1PUB:0:8}:${SECTOR}:${TODATE}:/ipfs/${IPFSPOP}"
    echo "> INTERCOM ${INTERCOM} (${ZEN} ZEN)"
    #~ if [[ ${ZEN} -gt 11 ]]; then
        #~ echo "---ZZZ-- SECTOR 2 REGION ZEN CHAINING ---ZZZ------ZZZ----"
        #~ ${MY_PATH}/../tools/PAY4SURE.sh ~/.zen/tmp/${MOATS}/${SECTOR}.dunikey "0.1" "${REGIONG1PUB}" "${INTERCOM}"
    #~ fi
    ##############################################################
    ## PUBLISHING ${SECTOR}
    ###############################
    echo "% PUBLISHING ${SECTOR} ${myIPFS}/ipns/${TODATENS}"
    start=`date +%s`
    ipfs --timeout 240s name publish -k ${TODATE}${G1PUB} /ipfs/${IPFSPOP}
    ipfs key rm ${YESTERDATE}${G1PUB} ${G1PUB} > /dev/null 2>&1

################# REGISTER UPlanet SECTOR to G1PODs
    ${MY_PATH}/../tools/timeout.sh -t 20 \
    ${MY_PATH}/../tools/jaklis/jaklis.py -k ~/.zen/tmp/${MOATS}/${SECTOR}.dunikey -n ${myDATA} \
            set -n "UPlanet SECTOR ${SECTOR}" -v " " -a " " -d "UPlanet ${myUPLANET}" \
            -pos ${SLAT} ${SLON} -s ${myLIBRA}/ipfs/${IPFSPOP} \
            -A ${MY_PATH}/../images/zenticket.png
    ${MY_PATH}/../tools/timeout.sh -t 20 \
    ${MY_PATH}/../tools/jaklis/jaklis.py -k ~/.zen/tmp/${MOATS}/${SECTOR}.dunikey -n ${myCESIUM} \
            set -n "UPlanet SECTOR ${SECTOR}" -v " " -a " " -d "UPlanet ${myUPLANET}" \
            -pos ${SLAT} ${SLON} -s ${myLIBRA}/ipfs/${IPFSPOP} \
            -A ${MY_PATH}/../images/zenticket.png

######################################################
    rm ~/.zen/tmp/${MOATS}/${SECTOR}.dunikey
    [[ ${ZCHAIN} != "" ]] && ipfs pin rm ${ZCHAIN}

###################################################
## EXTRACT SECTOR LAST WEEK TIDDLERS TO IPFSNODEID CACHE
    echo "(☉_☉ ) ${REGION}.week.rss.json  (☉_☉ )"

    rm -Rf ~/.zen/tmp/${IPFSNODEID}/SECTORS/ ## TODO REMOVE
    mkdir -p ~/.zen/tmp/${IPFSNODEID}/UPLANET/SECTORS/_${RLAT}_${RLON}/_${SLAT}_${SLON}
    ## CREATING 7 DAYS JSON RSS STREAM
    tiddlywiki --load ${INDEX} \
        --output ~/.zen/tmp/${IPFSNODEID}/UPLANET/SECTORS/_${RLAT}_${RLON}/_${SLAT}_${SLON} \
        --render '.' "${SECTOR}.week.rss.json" 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[days:created[-7]!is[system]!tag[G1Voeu]]'

    ###################################
    ## NODE CACHE SECTOR TODATENS
    echo "<meta http-equiv=\"refresh\" content=\"0; url='/ipns/${TODATENS}'\" />_${SLAT}_${SLON}" \
        > ~/.zen/tmp/${IPFSNODEID}/UPLANET/SECTORS/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_index.html

    ## TODO FILTER INFORMATION WITH MULTIPLE SIGNATURES (DONE in REGION.refresh.sh)
    ## TODO EXPORT AS RSS ## https://talk.tiddlywiki.org/t/has-anyone-generated-an-rss-feed-from-tiddlywiki/966/28
    end=`date +%s`
    echo "_____SECTOR${SECTOR} TREATMENT time was "`expr $end - $start` seconds.

done

exit 0
