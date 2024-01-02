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
echo "> RUNNING SECTOR.refresh"
[[ ${IPFSNODEID} == "" ]] && echo "IPFSNODEID is empty - EXIT -" && exit 1

MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
mkdir ~/.zen/tmp/${MOATS}

## CALLED BY UPLANET.refresh.sh
for i in $*; do
    UMAPS=("$i" ${UMAPS[@]})
done

######## INIT SECTORS ########################
for UMAP in ${UMAPS[@]}; do

    LAT=$(echo ${UMAP} | cut -d '_' -f 2)
    LON=$(echo ${UMAP} | cut -d '_' -f 3)

    [[ ${LAT} == "" || ${LON} == "" ]] && echo ">> ERROR BAD ${LAT} ${LON}" && continue
    [[ ${LAT} == "null" || ${LON} == "null" ]] && echo ">> ERROR BAD ${LAT} ${LON}" && continue

    SECLAT="${LAT::-1}"
    SECLON="${LON::-1}"

    MYSECTORS=("_${SECLAT}_${SECLON}" ${MYSECTORS[@]})

done

SECTORS=($(echo "${MYSECTORS[@]}" | tr ' ' '\n' | sort -u))

[[ ${SECTORS[@]} == "" ]] && echo "> NO SECTOR FOUND" && exit 0
#########################################################""
echo "ACTIVATED SECTORS : ${SECTORS[@]}"

for SECTOR in ${SECTORS[@]}; do

    echo "_____SECTOR ${SECTOR}"
    mkdir -p ~/.zen/tmp/${MOATS}/${SECTOR}/CHAIN/
    SLAT=$(echo ${SECTOR} | cut -d '_' -f 2)
    SLON=$(echo ${SECTOR} | cut -d '_' -f 3)

    ##############################################################
    SECTORG1PUB=$(${MY_PATH}/../tools/keygen -t duniter "${UPLANETNAME}${SECTOR}" "${UPLANETNAME}${SECTOR}")
    [[ ! ${SECTORG1PUB} ]] && echo "ERROR generating SECTOR WALLET" && exit 1
    COINS=$($MY_PATH/../tools/COINScheck.sh ${SECTORG1PUB} | tail -n 1)
    echo "SECTOR : ${SECTOR} (${COINS} G1) WALLET : ${SECTORG1PUB}"
    ZEN=$(echo "($COINS - 1) * 10" | bc | cut -d '.' -f 1)

    ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/${SECTOR}.priv "${UPLANETNAME}${SECTOR}" "${UPLANETNAME}${SECTOR}"
    ipfs key rm ${SECTORG1PUB} > /dev/null 2>&1 ## AVOID ERROR ON IMPORT
    SECTORNS=$(ipfs key import ${SECTORG1PUB} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/${SECTOR}.priv)
    rm ~/.zen/tmp/${MOATS}/${SECTOR}.priv

    echo "${myIPFS}/ipns/${SECTORNS}/"
    # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
            start=`date +%s`
    # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    #~ ## IPFS GET ONLINE SECTORNS
    ipfs --timeout 180s get -o ~/.zen/tmp/${MOATS}/${SECTOR}/ /ipns/${SECTORNS}/
    # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
            end=`date +%s`
            echo "_____SECTOR${SECTOR} GET time was "`expr $end - $start` seconds.
    # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    ## CONTROL CHAIN TIME
    ZCHAIN=$(cat ~/.zen/tmp/${MOATS}/${SECTOR}/CHAIN/_chain | rev | cut -d ':' -f 1 | rev 2>/dev/null)
    ZMOATS=$(cat ~/.zen/tmp/${MOATS}/${SECTOR}/CHAIN/_moats 2>/dev/null)
    [[ ${ZCHAIN} && ${ZMOATS} ]] \
        && cp ~/.zen/tmp/${MOATS}/${SECTOR}/CHAIN/_chain ~/.zen/tmp/${MOATS}/${SECTOR}/CHAIN/_chain.${ZMOATS} \
        && echo "UPDATING MOATS"

    MOATS_SECONDS=$(${MY_PATH}/../tools/MOATS2seconds.sh ${MOATS})
    ZMOATS_SECONDS=$(${MY_PATH}/../tools/MOATS2seconds.sh ${ZMOATS})
    DIFF_SECONDS=$((MOATS_SECONDS - ZMOATS_SECONDS))
    hours=$((DIFF_SECONDS / 3600))
    minutes=$(( (DIFF_SECONDS % 3600) / 60 ))
    seconds=$((DIFF_SECONDS % 60))
    echo "SECTOR DATA is ${hours} hours ${minutes} minutes ${seconds} seconds OLD"
    if [ ${DIFF_SECONDS} -lt $(( 5 * 60 * 60 )) ]; then
                    echo "GETTING YESTERDAY SECTOR.refresher"
                    YESTERDAY=$(ipfs cat /ipfs/${ZCHAIN}/CHAIN/SECTOR.refresher | head -n 1)
                    ## GET UMAP.refresher from PREVIOUS _chain ...
                    echo "TODAY : $(cat ~/.zen/tmp/${MOATS}/${SECTOR}/CHAIN/SECTOR.refresher | head -n 1)"
                    echo "YESTERDAY : ${YESTERDAY}"
                    continue
    fi
    # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    ## CONTROL ACTINGNODE SWAPPING
    UREFRESH="${HOME}/.zen/tmp/${MOATS}/${SECTOR}/CHAIN/SECTOR.refresher"
    ALLNODES=($(cat ${UREFRESH}  | grep -v '^[[:space:]]*$' 2>/dev/null)) # ${ALLNODES[@]} without empty line
    STRAPS=($(cat ~/.zen/Astroport.ONE/A_boostrap_nodes.txt | grep -Ev "#" | rev | cut -d '/' -f 1 | rev | grep -v '^[[:space:]]*$')) ## ${STRAPS[@]}

    if [[ ${ALLNODES[@]} == "" ]]; then
        for STRAP in ${STRAPS[@]}; do
                echo ${STRAP} >> ${UREFRESH} ## FILL SECTOR.refresher file with all STRAPS
        done
        ALLNODES=($(cat ${UREFRESH} 2>/dev/null)) # ${ALLNODES[@]}
    fi

    ACTINGNODE=${ALLNODES[0]} ## FIST NODE IN SECTOR.refresher

    ## IN CASE OLD BOOSTRAP IS STILL IN CHARGE - CHOOSE 1ST STRAP -
    [[ ! $(echo ${STRAPS[@]} | grep  ${ACTINGNODE}) ]] && ACTINGNODE=${STRAPS[0]}

    ## IF NOT UPDATED FOR TOO LONG
    [ ${DIFF_SECONDS} -gt $(( 24 * 60 * 60 )) ] \
        && echo "More than 24H update" \
        && ACTINGNODE=${STRAPS[0]}

    [[ "${ACTINGNODE}" != "${IPFSNODEID}" ]] \
            && echo ">> ACTINGNODE=${ACTINGNODE} is not ME - CONTINUE -" \
            && continue

### NEXT REFRESHER SHUFFLE
    rm ${UREFRESH}
    for STRAP in ${STRAPS[@]}; do
            echo ${STRAP} >> ${UREFRESH} ## RESET SECTOR.refresher file with actual STRAPS
    done
    # SHUFFLE UMAP.refresher
    cat ${UREFRESH} | sort | uniq | shuf  > ${UREFRESH}.shuf
    mv ${UREFRESH}.shuf ${UREFRESH}
    echo "SETTING NEXT REFRESHER : $(cat ${UREFRESH} | head -n 1)"

##############################################################
    ## FEED SECTOR TW WITH UMAPS RSS
    mkdir -p ~/.zen/tmp/${MOATS}/${SECTOR}/TW
    INDEX="${HOME}/.zen/tmp/${MOATS}/${SECTOR}/TW/index.html"

    ## NEW TW TEMPLATE
    [[ ! -s ${INDEX} ]] \
        && sed "s~_SECTOR_~${SECTOR}~g" ${MY_PATH}/../templates/empty.html > ${INDEX}

    ## SET SECTOR
    sed -i "s~_SECTOR_~${SECTOR}~g" ${INDEX}

    ## GET ALL RSS json's AND Feed SECTOR TW with it
    RSSNODE=($(ls ~/.zen/tmp/${IPFSNODEID}/UPLANET/_${SLAT}*_${SLON}*/RSS/*.rss.json 2>/dev/null))
    NL=${#RSSNODE[@]}

    RSSWARM=($(ls ~/.zen/tmp/swarm/12D*/UPLANET/_${SLAT}*_${SLON}*/RSS/*.rss.json 2>/dev/null))
    NS=${#RSSWARM[@]}

    combinedrss=("${RSSNODE[@]}" "${RSSWARM[@]}")
    RSSALL=($(echo "${combinedrss[@]}" | tr ' ' '\n' | sort -u))

    ################################## TRANSFER SIGNED TIDDLER IN SECTOR TW
    for RSS in ${RSSALL[@]}; do
        ${MY_PATH}/../tools/RSS2UPlanetTW.sh "${RSS}" "${SECTOR}" "${MOATS}" "${INDEX}"
    done
    TOTL=$((${NL}+${NS}))
##############################################################

    echo "Number of RSS : "${TOTL}
    rm ~/.zen/tmp/${MOATS}/${SECTOR}/N_RSS*
    echo ${TOTL} > ~/.zen/tmp/${MOATS}/${SECTOR}/N_RSS_${TOTL}

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

        SWARMTW=($(ls ~/.zen/tmp/swarm/*/UPLANET/_${SLAT}*_${SLON}*/TW/*/index.html 2>/dev/null))
        NODETW=($(ls ~/.zen/tmp/${IPFSNODEID}/UPLANET/_${SLAT}*_${SLON}*/TW/*/index.html 2>/dev/null))
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
        ### APPLY ON APP MODEL
        REGLAT=$(echo ${LAT} | cut -d '.' -f 1)
        REGLON=$(echo ${LON} | cut -d '.' -f 1)
        REGION="_${REGLAT}_${REGLON}"
        REGIONNS=$(${MY_PATH}/../tools/keygen -t ipfs "${UPLANETNAME}${REGION}" "${UPLANETNAME}${REGION}")

        cat ${MY_PATH}/../templates/UPlanetSector/index.html \
                | sed -e "s~_ZONE_~SECTOR ${SECTOR}~g" \
                  -e "s~_UPZONE_~REGION ${REGION}~g" \
                  -e "s~QmYdWBx32dP14XcbXF7hhtDq7Uu6jFmDaRnuL5t7ARPYkW/index_fichiers/world.js~${IAMAP}/world.js~g" \
                  -e "s~_ZONENS_~${SECTORNS}~g" \
                  -e "s~_UPZONENS_~${REGIONNS}~g" \
                  -e "s~_SECTORG1PUB_~${SECTORG1PUB}~g" \
                  -e "s~_UPLANETLINK_~${EARTHCID}/map_render.html?southWestLat=${LAT}&southWestLon=${LON}&deg=0.1~g" \
                  -e "s~http://127.0.0.1:8080~~g" \
        > ~/.zen/tmp/${MOATS}/${SECTOR}/_index.html

        ##################################
        cp -f ~/.zen/tmp/${MOATS}/${SECTOR}/_index.html ~/.zen/tmp/${MOATS}/${SECTOR}/index.html

###########################################################################################
## ADD SECTOR ZENPUB.png & INFO.png
if [[ ! -s ~/.zen/tmp/${MOATS}/${SECTOR}/INFO.png ]]; then
    convert -font 'Liberation-Sans' \
            -pointsize 80 -fill purple -draw 'text 50,120 "'"${ZEN} Zen"'"' \
            -pointsize 30 -fill purple -draw 'text 40, 180 "'"${SECTOR}"'"' \
            $MY_PATH/../images/G1WorldMap.png "${HOME}/.zen/tmp/${MOATS}/${SECTOR}.png"
    # CREATE SECTORG1PUB AMZQR
    amzqr ${SECTORG1PUB} -l H -p "$MY_PATH/../images/zenticket.png" -c -n ZENPUB.png -d ~/.zen/tmp/${MOATS}/${SECTOR}/
    convert ~/.zen/tmp/${MOATS}/${SECTOR}/ZENPUB.png -resize 250 ~/.zen/tmp/${MOATS}/ZENPUB.png
    # ADD IT
    composite -compose Over -gravity NorthEast -geometry +0+0 ~/.zen/tmp/${MOATS}/ZENPUB.png ~/.zen/tmp/${MOATS}/${SECTOR}.png ~/.zen/tmp/${MOATS}/${SECTOR}/INFO.png
fi

## zday marking
rm ~/.zen/tmp/${MOATS}/${SECTOR}/z* 2>/dev/null
ZCHAIN=$(cat ~/.zen/tmp/${MOATS}/${SECTOR}/CHAIN/_chain | rev | cut -d ':' -f 1 | rev 2>/dev/null)
echo "<meta http-equiv=\"refresh\" content=\"0; url='/ipfs/${ZCHAIN}' />" > ~/.zen/tmp/${MOATS}/${SECTOR}/z$(date +%A-%d_%m_%Y).html


###################################################### CHAINING BACKUP
    IPFSPOP=$(ipfs add -rwq ~/.zen/tmp/${MOATS}/${SECTOR}/* | tail -n 1)

    ## DOES CHAIN CHANGED or INIT ?
    [[ ${ZCHAIN} != ${IPFSPOP} || ${ZCHAIN} == "" ]] \
        && echo "${MOATS}:${IPFSNODEID}:${IPFSPOP}" > ~/.zen/tmp/${MOATS}/${SECTOR}/CHAIN/_chain \
        && echo "${MOATS}" > ~/.zen/tmp/${MOATS}/${SECTOR}/CHAIN/_moats \
        && IPFSPOP=$(ipfs add -rwq ~/.zen/tmp/${MOATS}/${SECTOR}/* | tail -n 1) && echo "ROOT was ${ZCHAIN}"
######################################################

        echo "% START PUBLISHING ${SECTOR} ${myIPFS}/ipns/${SECTORNS}"
        start=`date +%s`
        ipfs name publish -k ${SECTORG1PUB} /ipfs/${IPFSPOP}
        ipfs key rm ${SECTORG1PUB} > /dev/null 2>&1
        end=`date +%s`
        echo "_____SECTOR${SECTOR} PUBLISH time was "`expr $end - $start` seconds.

######################################################

done



exit 0
