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
## REGION REFRESH
# UMAP > SECTOR > REGION
## Get from 100 sectors tiddlers with more than 2 signatures
############################################
echo "############################################"
echo "############################################"
echo "############################################"
echo "# # # # RUNNING REGION.refresh"
echo "############################################"
echo "############################################"
echo "############################################"
[[ ${IPFSNODEID} == "" ]] && echo "IPFSNODEID is empty - EXIT -" && exit 1

MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
mkdir ~/.zen/tmp/${MOATS}

## UMAPS list made BY UPLANET.refresh.sh
for i in $*; do
    UMAPS=("$i" ${UMAPS[@]})
done

[[ ${#UMAPS[@]} == 0 ]] && UMAPS="_0.00_0.00"

######## INIT REGIONS ########################
for UMAP in ${UMAPS[@]}; do

    LAT=$(echo ${UMAP} | cut -d '_' -f 2)
    LON=$(echo ${UMAP} | cut -d '_' -f 3)

    [[ ${LAT} == "" || ${LON} == "" ]] && echo ">> ERROR BAD ${LAT} ${LON}" && continue
    [[ ${LAT} == "null" || ${LON} == "null" ]] && echo ">> ERROR BAD ${LAT} ${LON}" && continue

    REGLAT=$(echo ${LAT} | cut -d '.' -f 1)
    REGLON=$(echo ${LON} | cut -d '.' -f 1)

    MYREGIONS=("_${REGLAT}_${REGLON}" ${MYREGIONS[@]})

done

## GET UNIQ REGIONS LIST
REGIONS=($(echo "${MYREGIONS[@]}" | tr ' ' '\n' | sort -u))

[[ ${REGIONS[@]} == "" ]] && echo "> NO REGION FOUND" && exit 0

echo "ACTIVATED REGIONS : ${REGIONS[@]}"

for REGION in ${REGIONS[@]}; do

    echo "_____REGION ${REGION}"
    mkdir -p ~/.zen/tmp/${MOATS}/${REGION}
    REGLAT=$(echo ${REGION} | cut -d '_' -f 2)
    REGLON=$(echo ${REGION} | cut -d '_' -f 3)

    ################################## TODO : make sharing key protocol evolve
    ## FOR NOW ONLY 1ST BOOSTRAP PUBLISH REGION KEYS
    # with bigger planetary swam will be closest "IA Station", or it could be choosen according to ZEN value...
    STRAPS=($(cat ~/.zen/Astroport.ONE/A_boostrap_nodes.txt | grep -Ev "#" | rev | cut -d '/' -f 1 | rev | grep -v '^[[:space:]]*$')) ## ${STRAPS[@]}
    ACTINGNODE=${STRAPS[0]} ## FIST NODE IN STRAPS
    [[ "${ACTINGNODE}" != "${IPFSNODEID}" ]] \
            && echo ">> ACTINGNODE=${ACTINGNODE} is not ME - CONTINUE -" \
            && continue

    ##############################################################
    REGIONG1PUB=$(${MY_PATH}/../tools/keygen -t duniter "${UPLANETNAME}${REGION}" "${UPLANETNAME}${REGION}")
    [[ ! ${REGIONG1PUB} ]] && echo "ERROR generating REGION WALLET" && exit 1
            COINS=$($MY_PATH/../tools/COINScheck.sh ${REGIONG1PUB} | tail -n 1)
            echo "REGION : ${REGION} (${COINS} G1) WALLET : ${REGIONG1PUB}"

    ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/REGION.priv "${UPLANETNAME}${REGION}" "${UPLANETNAME}${REGION}"
    ipfs key rm ${REGIONG1PUB} > /dev/null 2>&1 ## AVOID ERROR ON IMPORT
    REGIONNS=$(ipfs key import ${REGIONG1PUB} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/REGION.priv)

    ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/REGION.priv "${YESTERDATE}${UPLANETNAME}${REGION}" "${YESTERDATE}${UPLANETNAME}${REGION}"
    ipfs key rm ${YESTERDATE}${REGIONG1PUB} > /dev/null 2>&1 ## AVOID ERROR ON IMPORT
    YESTERDATEREGIONNS=$(ipfs key import ${YESTERDATE}${REGIONG1PUB} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/REGION.priv)

    ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/REGION.priv "${TODATE}${UPLANETNAME}${REGION}" "${TODATE}${UPLANETNAME}${REGION}"
    ipfs key rm ${TODATE}${REGIONG1PUB} > /dev/null 2>&1 ## AVOID ERROR ON IMPORT
    TODATEREGIONNS=$(ipfs key import ${TODATE}${REGIONG1PUB} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/REGION.priv)
    ##############################################################
    ## GET from IPNS
            ipfs --timeout 240s get -o ~/.zen/tmp/${MOATS}/${REGION}/ /ipns/${YESTERDATEREGIONNS}/
            # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
            # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
            mkdir -p ~/.zen/tmp/${MOATS}/${REGION}/RSS
            rm -f ~/.zen/tmp/${MOATS}/${REGION}/RSS/_${REGLAT}_${REGLON}.week.rss.json
            rm -f ~/.zen/tmp/${MOATS}/${REGION}/JOURNAL

            ## START WITH LOCAL SECTORS RSS WEEK
            RSSNODE=($(ls ~/.zen/tmp/${IPFSNODEID}/SECTORS/_${REGLAT}*_${REGLON}*.week.rss.json 2>/dev/null))
                for RSS in ${RSSNODE[@]}; do
                    [[ $(cat ${RSS}) != "[]" ]] \
                        && cp ${RSS} ~/.zen/tmp/${MOATS}/${REGION}/RSS/ \
                        && ${MY_PATH}/../tools/RSS2WEEKnewsfile.sh ${RSS} >> ~/.zen/tmp/${MOATS}/${REGION}/JOURNAL
                done
            NL=${#RSSNODE[@]}

            ## ADD SWARM SECTORS RSS WEEK
            RSSWARM=($(ls ~/.zen/tmp/swarm/*/SECTORS/_${REGLAT}*_${REGLON}*.week.rss.json 2>/dev/null))
                for RSS in ${RSSWARM[@]}; do
                    [[ $(cat ${RSS}) != "[]" ]] \
                        && cp ${RSS} ~/.zen/tmp/${MOATS}/${REGION}/RSS/ \
                        && ${MY_PATH}/../tools/RSS2WEEKnewsfile.sh ${RSS} >> ~/.zen/tmp/${MOATS}/${REGION}/JOURNAL
                done
            NS=${#RSSWARM[@]}

            ## CREATE /.all.json FROM *.rss.json
            ${MY_PATH}/../tools/json_dir.all.sh ~/.zen/tmp/${MOATS}/${REGION}/RSS

            ## REMOVE SECTORS PARTS
            rm -f ~/.zen/tmp/${MOATS}/${REGION}/RSS/*.week.rss.json

            ## MAKE FINAL _${REGLAT}_${REGLON}.week.rss.json
            mv  ~/.zen/tmp/${MOATS}/${REGION}/RSS/.all.json \
                    ~/.zen/tmp/${MOATS}/${REGION}/RSS/_${REGLAT}_${REGLON}.week.rss.json

            ## PREPARING AiApi link
            mkdir -p ~/.zen/tmp/${IPFSNODEID}/REGIONS
            RWEEKCID=$(ipfs add -q ~/.zen/tmp/${MOATS}/${REGION}/JOURNAL)

            cp ~/.zen/tmp/${MOATS}/${REGION}/JOURNAL \
                ~/.zen/tmp/${IPFSNODEID}/REGIONS/_${REGLAT}_${REGLON}.JOURNAL.md

            ## DEMO : PREPARE Ask.IA link - PROD will be launched during RUNTIME.
            echo "<meta http-equiv=\"refresh\" content=\"0; url='https://api.copylaradio.com/tellme/?cid=/ipfs/${RWEEKCID}'\" />" \
                        > ~/.zen/tmp/${MOATS}/${REGION}/Ask.IA._${REGLAT}_${REGLON}.redir.html


            TOTL=$((${NL}+${NS}))
            # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
            echo "Numbers of REGION WEEK RSS : ${NL} + ${NS} : "${TOTL}

            rm ~/.zen/tmp/${MOATS}/${REGION}/TODO
            rm ~/.zen/tmp/${MOATS}/${REGION}/N_*

            echo ${TOTL} > ~/.zen/tmp/${MOATS}/${REGION}/N_${TOTL}

            echo "<meta http-equiv=\"refresh\" content=\"0; url='/ipfs/${RWEEKCID}'\" />" \
                        > ~/.zen/tmp/${MOATS}/${REGION}/Journal._${REGLAT}_${REGLON}.redir.html

            IPFSPOP=$(ipfs add -rwq ~/.zen/tmp/${MOATS}/${REGION}/* | tail -n 1)
            ipfs name publish -k ${TODATE}${REGIONG1PUB} /ipfs/${IPFSPOP}


    ipfs key rm ${REGIONG1PUB} ${YESTERDATE}${REGIONG1PUB} > /dev/null 2>&1

done

exit 0
