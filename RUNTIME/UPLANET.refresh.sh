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
## SEEK FOR UPLANET KEYS
# GET & UPDATE IPNS
############################################
echo "## RUNNING UPLANET.refresh"
[[ ${IPFSNODEID} == "" ]] && echo "IPFSNODEID is empty - EXIT -" && exit 1

MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
mkdir ~/.zen/tmp/${MOATS}

#################################################################
## IPFSNODEID ASTRONAUTES SIGNALING ## 12345 port
############################
    ## RUNING FOR ALL UMAP FOUND IN STATION MAP CACHE : "_LAT_LON"

    ## SEARCH UMAP (created by PLAYER.refresh.sh)
    MEMAPS=($(ls -t ~/.zen/tmp/${IPFSNODEID}/UPLANET/ 2>/dev/null))
    echo "FOUND : ${MEMAPS[@]}" # "_LAT_LON" directories

    SWARMMAPS=($(ls -Gd ~/.zen/tmp/swarm/*/UPLANET/* | rev | cut -d '/' -f 1 | rev | sort | uniq 2>/dev/null) )
    echo "FOUND : ${SWARMMAPS[@]}" # "_LAT_LON" directories

    combined=("${MEMAPS[@]}" "${SWARMMAPS[@]}")
    unique_combined=($(echo "${combined[@]}" | tr ' ' '\n' | sort -u))

    for UMAP in ${unique_combined[@]}; do

        start=`date +%s`
        echo "____________REFRESHING ${UMAP}__________"
        LAT=$(echo ${UMAP} | cut -d '_' -f 2)
        LON=$(echo ${UMAP} | cut -d '_' -f 3)

        [[ ${LAT} == "" || ${LON} == "" ]] && echo ">> ERROR BAD ${LAT} ${LON}" && continue
        [[ ${LAT} == "null" || ${LON} == "null" ]] && echo ">> ERROR BAD ${LAT} ${LON}" && continue

        ##############################################################
        G1PUB=$(${MY_PATH}/../tools/keygen -t duniter "${LAT}" "${LON}")
        [[ ! ${G1PUB} ]] && echo "ERROR generating WALLET" && exit 1
        COINS=$($MY_PATH/../tools/COINScheck.sh ${G1PUB} | tail -n 1)
        echo "UMAP (${COINS} G1) WALLET : ${G1PUB}"

        ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/${UMAP}.priv "${LAT}" "${LON}"
        ipfs key rm ${G1PUB} > /dev/null 2>&1 ## AVOID ERROR ON IMPORT
        UMAPNS=$(ipfs key import ${G1PUB} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/${UMAP}.priv)
        echo "${myIPFS}/ipns/${UMAPNS}"
        ##############################################################

        # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
        # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
        ## IPFS GET ONLINE UMAPNS
        mkdir ~/.zen/tmp/${MOATS}/${UMAP}
        ipfs --timeout 42s get -o ~/.zen/tmp/${MOATS}/${UMAP}/ /ipns/${UMAPNS}/
        # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
        # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

        ## FORMAT CONTROL WARNING
        [[ ! -d ~/.zen/tmp/${MOATS}/${UMAP}/${G1PUB} || ! -d ~/.zen/tmp/${MOATS}/${UMAP}/${LAT}_${LON} ]] \
            && echo ">>> INFO - INTIALIZE UMAP FORMAT - NEW UMAP KEY -" \
            && mkdir -p ~/.zen/tmp/${MOATS}/${UMAP}/${LAT}_${LON} \
            && mkdir -p ~/.zen/tmp/${MOATS}/${UMAP}/${G1PUB}

        mkdir -p ~/.zen/tmp/${MOATS}/${UMAP}/RSS
        mkdir -p ~/.zen/tmp/${MOATS}/${UMAP}/TW

    echo "~/.zen/tmp/${MOATS}/${UMAP}/${G1PUB}/"

    ## PROTOCOL MIGRATION (TODO REMOVE)
    rm ${HOME}/.zen/tmp/${MOATS}/${UMAP}/${LAT}_${LON}/UMAP.refresh 2>/dev/null
    # 8< ----

 # ++++++++++++++++++++ - - - - ADAPT TO NODE TREATMENT TIME
                ZMOATS=$(cat ~/.zen/tmp/${MOATS}/${UMAP}/${G1PUB}/_moats 2>/dev/null)
                # ZMOATS SHOULD BE MORE THAT 20 HOURS.
                MOATS_SECONDS=$(${MY_PATH}/../tools/MOATS2seconds.sh ${MOATS})
                ZMOATS_SECONDS=$(${MY_PATH}/../tools/MOATS2seconds.sh ${ZMOATS})
                DIFF_SECONDS=$((MOATS_SECONDS - ZMOATS_SECONDS))
                    echo "UMAP DATA is ${DIFF_SECONDS} seconds "
                # IF LESS.
                if [ ${DIFF_SECONDS} -lt 72000 ]; then
                    echo "GETTING YESTERDAY UMAP.refresher"
                    ZCHAIN=$(cat ~/.zen/tmp/${MOATS}/${UMAP}/${G1PUB}/_chain | rev | cut -d ':' -f 1 | rev 2>/dev/null)
                    ## GET UMAP.refresher from PREVIOUS _chain ...
                    ipfs cat /ipfs/${ZCHAIN}/${LAT}_${LON}/UMAP.refresher > ~/.zen/tmp/${MOATS}/${UMAP}/${LAT}_${LON}/UMAP.refresher
                fi

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        ########################################################
        ## NODE  SELECTION in UMAP.refresher
        UREFRESH="${HOME}/.zen/tmp/${MOATS}/${UMAP}/${LAT}_${LON}/UMAP.refresher"
        ALLNODES=($(cat ${UREFRESH} 2>/dev/null)) # ${ALLNODES[@]}
        STRAPS=($(cat ~/.zen/Astroport.ONE/A_boostrap_nodes.txt | grep -Ev "#" | rev | cut -d '/' -f 1 | rev | grep -v '^[[:space:]]*$')) ## ${STRAPS[@]}

        if [[ ${ALLNODES[@]} == "" ]]; then
            for STRAP in ${STRAPS[@]}; do
                    echo ${STRAP} >> ${UREFRESH} ## FILL UMAP.refresher file with all STRAPS
            done
            ALLNODES=($(cat ${UREFRESH} 2>/dev/null)) # ${ALLNODES[@]}
        fi

        ACTINGNODE=${ALLNODES[1]} ## FIST NODE IN UMAP.refresher

        ## IN CASE OLD BOOSTRAP IS STILL IN CHARGE - CHOOSE 1ST STRAP -
        [[ ! $(echo ${STRAPS[@]} | grep  ${ACTINGNODE}) ]] && ACTINGNODE=${STRAPS[1]}

        echo "* ACTINGNODE=${ACTINGNODE}"

        [[ "${ACTINGNODE}" != "${IPFSNODEID}" ]] \
            && echo ">> ACTINGNODE=${ACTINGNODE} is not ME - CONTINUE -" \
            && continue
            ########################################
            # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ PASSING THERE MAKE IPFSNODEID UMAP REFRESHER

        ## NEXT REFRESHER
        # TODO: INTRODUCE NODE BALANCE AND CHOOSE THE MOST CONFIDENT ONE
        for STRAP in ${STRAPS[@]}; do
                echo ${STRAP} >> ${UREFRESH} ## FILL UMAP.refresher file with all STRAPS
        done
        # SHUFFLE UMAP.refresher
        cat ${UREFRESH} | sort | uniq | shuf  > ${UREFRESH}.shuf
        mv ${UREFRESH}.shuf ${UREFRESH}
        ## NEXT REFRESHER
        echo ">> NEXT REFRESHER WILL BE $(cat ${UREFRESH} | head -n 1)"
        ######################################################## # NODE  SELECTION in UMAP.refresher


 ## COLLECT RSS FROM ALL PLAYERS WITH SAME UMAP IN SWARM MEMORY
        cp ~/.zen/tmp/${IPFSNODEID}/UPLANET/_${LAT}_${LON}/RSS/*.rss.json ~/.zen/tmp/${MOATS}/${UMAP}/RSS/ 2>/dev/null
        RSSFILES=($(ls ~/.zen/tmp/swarm/*/UPLANET/_${LAT}_${LON}/RSS/*.rss.json 2>/dev/null))
        for RSSFILE in ${RSSFILES[@]}; do
            cp ${RSSFILE} ~/.zen/tmp/${MOATS}/${UMAP}/RSS/
        done

## COLLECT TW LINKS FOR SWARM
        cp -r ~/.zen/tmp/${IPFSNODEID}/UPLANET/_${LAT}_${LON}/TW/* ~/.zen/tmp/${MOATS}/${UMAP}/TW/ 2>/dev/null
        TWFILES=($(ls ~/.zen/tmp/swarm/*/UPLANET/_${LAT}_${LON}/TW/*/index.html 2>/dev/null))
        for TWRED in ${TWFILES[@]}; do
            ZMAIL=$(echo ${TWRED} | rev | cut -d '/' -f 2 | rev)
            mkdir -p ~/.zen/tmp/${MOATS}/${UMAP}/TW/${ZMAIL}
            cp ${TWRED} ~/.zen/tmp/${MOATS}/${UMAP}/TW/${ZMAIL}/
        done


        ## OSM2IPFS
### UMAP = 0.01° Planet Slice
        UMAPGEN="/ipfs/QmReVMqhMNcKWijAUVmj3EDmHQNfztVUT413m641eV237z/Umap.html?southWestLat=${LAT}&southWestLon=${LON}&deg=0.01&ipns=${UMAPNS}"
        USATGEN="/ipfs/QmReVMqhMNcKWijAUVmj3EDmHQNfztVUT413m641eV237z/Usat.html?southWestLat=${LAT}&southWestLon=${LON}&deg=0.01&ipns=${UMAPNS}"
        echo "<meta http-equiv=\"refresh\" content=\"0; url='${UMAPGEN}'\" />" > ~/.zen/tmp/${MOATS}/${UMAP}/Umap.html
        echo "<meta http-equiv=\"refresh\" content=\"0; url='${USATGEN}'\" />" > ~/.zen/tmp/${MOATS}/${UMAP}/Usat.html

## ¤$£€
        ## # GET SCREENSHOT UMAP SECTOR & REGION JPG
        ## PROBLEM ON LIBRA ... MORE TEST NEEDED ... TODO
        [[ ! -s ~/.zen/tmp/${MOATS}/${UMAP}/Umap.jpg ]] \
            && python ${MY_PATH}/../tools/page_screenshot.py "${myIPFS}${UMAPGEN}" ~/.zen/tmp/${MOATS}/${UMAP}/Umap.jpg 900 900 2>/dev/null \
            && [[ ! -s ~/.zen/tmp/${MOATS}/${UMAP}/Umap.jpg ]] && killall chrome

        [[ ! -s ~/.zen/tmp/${MOATS}/${UMAP}/Usat.jpg ]] \
            && python ${MY_PATH}/../tools/page_screenshot.py "${myIPFS}${USATGEN}" ~/.zen/tmp/${MOATS}/${UMAP}/Usat.jpg 900 900 2>/dev/null \
            && [[ ! -s ~/.zen/tmp/${MOATS}/${UMAP}/Usat.jpg ]] && killall chrome

        ##############################################################
    if [[ ! -s ~/.zen/tmp/${MOATS}/${UMAP}/geolinks.json ]]; then

        ${MY_PATH}/../tools/Umap_geolinks.sh "${LAT}" "${LON}" "${UMAP}" "${MOATS}"

    fi

####################################
        ## MAKE GET POI's

### JSON UMAP SCRAPPING
####################################
        ## RECORD P4N SPOT DATA
        curl -s "https://www.park4night.com/api/places/around?lat=${LAT}&lng=${LON}&radius=200&filter=%7B%7D&lang=fr" -o ~/.zen/tmp/${MOATS}/${UMAP}/fetch.json
        [[ -s ~/.zen/tmp/${MOATS}/${UMAP}/fetch.json ]] \
        && mv ~/.zen/tmp/${MOATS}/${UMAP}/fetch.json ~/.zen/tmp/${MOATS}/${UMAP}/p4n.json

        ## GET 100KM GCHANGE ADS ( https://data.gchange.fr )
        ${MY_PATH}/../tools/gchange_get_50km_around_LAT_LON_ads.sh ${LAT} ${LON} > ~/.zen/tmp/${MOATS}/${UMAP}/gchange50.json

        ## CREATE GCHANGE ACCOUNT ??!! DO ANYTHING RELATED TO UMAP


    ### SET navigator.html ## MAKE EVOLVE template/umap.html
        cp ${MY_PATH}/../templates/umap.html ~/.zen/tmp/${MOATS}/${UMAP}/navigator_Umap.html
        cat ~/.zen/tmp/${MOATS}/${UMAP}/navigator_Umap.html | sed "s~Umap~Usat~g" > ~/.zen/tmp/${MOATS}/${UMAP}/navigator_Usat.html

########################################################
## ACTIVATE IN CASE OF PROTOCOL BRAKE
## TODO : BACKUP STATE IN // PRIVATE KEY
## TODO : SNIFF IPFS DHT MODIFICATIONS ## FAIL2BAN ## DEFCON
########################################################
SLAT="${LAT::-1}"
SLON="${LON::-1}"
        ##############################################################
        ############################ PUBLISHING UMAP
        ##############################################################
        UMAPROOT=$(ipfs add -rwHq ~/.zen/tmp/${MOATS}/${UMAP}/* | tail -n 1)

        ZCHAIN=$(cat ~/.zen/tmp/${MOATS}/${UMAP}/${G1PUB}/_chain | rev | cut -d ':' -f 1 | rev 2>/dev/null)
        ZMOATS=$(cat ~/.zen/tmp/${MOATS}/${UMAP}/${G1PUB}/_moats 2>/dev/null)
        [[ ${ZCHAIN} && ${ZMOATS} ]] \
            && cp ~/.zen/tmp/${MOATS}/${UMAP}/${G1PUB}/_chain ~/.zen/tmp/${MOATS}/${UMAP}/${G1PUB}/_chain.${ZMOATS} \
            && echo "UPDATING MOATS"

        ## DOES CHAIN CHANGED or INIT ?
        [[ ${ZCHAIN} != ${UMAPROOT} || ${ZCHAIN} == "" ]] \
            && echo "${MOATS}:${IPFSNODEID}:${UMAPROOT}" > ~/.zen/tmp/${MOATS}/${UMAP}/${G1PUB}/_chain \
            && echo "${MOATS}" > ~/.zen/tmp/${MOATS}/${UMAP}/${G1PUB}/_moats \
            && UMAPROOT=$(ipfs add -rwHq  ~/.zen/tmp/${MOATS}/${UMAP}/* | tail -n 1) && echo "ROOT was ${ZCHAIN}"

        echo "PUBLISHING NEW UMAPROOT : ${myIPFS}/ipfs/${UMAPROOT}"

            ipfs name publish --key=${G1PUB} /ipfs/${UMAPROOT}
            end=`date +%s`
            ipfs key rm ${G1PUB} ## REMOVE IPNS KEY

            echo "(UMAP) ${UMAP} PUBLISH time was "`expr $end - $start` seconds.

    done


### SECTOR = 0.1° Planet Slice
        ${MY_PATH}/SECTOR.refresh.sh "${LAT}" "${LON}" "${MOATS}" "${UMAP}" "${ACTINGNODE}"

 ### REGION = 1° Planet Slice
       ${MY_PATH}/REGION.refresh.sh "${LAT}" "${LON}" "${MOATS}" "${UMAP}" "${ACTINGNODE}"

