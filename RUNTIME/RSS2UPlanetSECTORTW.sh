#!/bin/bash
########################################################################
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
# INSERT NEW TIDDLERS FROM RSS JSON INTO UPLANET TW
# DETECTING CONFLICT WITH SAME TITLE
# ASKING TO EXISTING SIGNATURES TO UPDATE THEIR TW OR FORK TITLE
# CALLED BY "SECTOR.refresh.sh"
# SEND 10 ZEN TO EACH SIGNATURE
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"
. "$MY_PATH/../tools/my.sh"

RSS=$1 ## filepath to RSS
SECTOR=$2 ## Sector identifier _0.0_0.0
MOATS=$3 ## temp cache access
INDEX=$4 ## SECTOR TW index file

echo

[[ ! -s ${RSS} ]] && echo "BAD RSS INPUT" && exit 1
[[ "$(cat ${RSS})" == "[]" ]] && echo "EMPTY RSS " && exit 0

[[ ! -d ~/.zen/tmp/${MOATS}/${SECTOR}/ ]] && echo "- ERROR - BAD UPLANET CONTEXT - look inside code - " && exit 1
[[ ! -s ${INDEX} ]] \
    && sed "s~_SECTOR_~${SECTOR}~g" ${MY_PATH}/../templates/twsector.html > ${INDEX} \
    && echo "- WARNING - REFRESHING SECTOR FROM empty TEMPLATE *****"

## EXTRACT PLAYER FROM RSS FILE NAME
PLAYER=$(echo ${RSS} | rev | cut -d '/' -f 1 | rev | sed "s~.rss.json~~g")
## GET PLAYER INFORMATION
$($MY_PATH/../tools/search_for_this_email_in_players.sh ${PLAYER} | tail -n 1)
echo "export ASTROPORT=${ASTROPORT} ASTROTW=${ASTROTW} ASTROG1=${ASTROG1} ASTROMAIL=${EMAIL} ASTROFEED=${FEEDNS}"

echo "======= ${INDEX} =======
SECTOR ${SECTOR} TW INSERTING ${PLAYER}
${RSS}
=================================================================="
cat "${RSS}" | jq 'sort_by(.created) | reverse | .[]' | jq -r '.title' > ~/.zen/tmp/${MOATS}/${SECTOR}/tiddlers.list
##
gloops=0
signatures=0

while read title; do

    [[ ${floop} -gt 1 ]] && echo "Other Tiddlers are similaR... BREAK LOOP" && break

    # FILTER "UPPERCASE" + Astroport Tid, less than 4 characters title Tiddlers (ex: GPS, ...).
    [[ ${title} == "GettingStarted" || "${title^^}" == "${title}" || "${title::3}" == '$:/' || ${title::4} == ${title} || ${title} == "AstroID" || ${title} == "Voeu1.png"  || ${title} == "Astroport" || ${title} == "MadeInZion" || ${title} == "G1Visa" || ${title} == "ZenCard" || ${title::5} == "Draft" ]] \
        && echo "FILTERED TITLE ${title}" && continue

    ## CHECK FOR TIDDLER WITH SAME TITTLE IN SECTOR TW
    rm -f ~/.zen/tmp/${MOATS}/TMP.json
    tiddlywiki --load ${INDEX}  --output ~/.zen/tmp/${MOATS} --render '.' 'TMP.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' "${title}"
    ISHERE=$(cat ~/.zen/tmp/${MOATS}/TMP.json | jq -r ".[].title")

    [[ ! "${ISHERE}" ]] && echo "No Tiddler found in ${INDEX}"

    TMPTAGS=$(cat ~/.zen/tmp/${MOATS}/TMP.json | jq -r .[].tags)
    TMPEMAILS=($(echo "$TMPTAGS" | grep -E -o "\b[a-zA-Z0-9.%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,6}\b"))
    TMPSIGN=${#TMPEMAILS[@]}
    #~ echo "INSIDE TIDDLER HAVE ${TMPSIGN} SIGNATURE(S)"

    if [[ "${ISHERE}" != "${title}" || ${TMPSIGN} == 0 ]]; then

        ## NEW TIDDLER
        echo "Importing Title: $title"
        cat "${RSS}" | jq -rc ".[] | select(.title == \"$title\")" > ~/.zen/tmp/${MOATS}/NEW.json

        #~ echo "DEBUG"
        #~ cat ~/.zen/tmp/${MOATS}/NEW.json | jq
        #~ echo "tiddlywiki  --load ${INDEX} --import ~/.zen/tmp/${MOATS}/NEW.json 'application/json' --output ~/.zen/tmp/${MOATS}/${SECTOR} --render '$:/core/save/all' '"${SECTOR}.html"' 'text/plain'"

        tiddlywiki --load ${INDEX} \
            --import ~/.zen/tmp/${MOATS}/NEW.json 'application/json' \
            --output ~/.zen/tmp/${MOATS}/${SECTOR} --render '$:/core/save/all' "${SECTOR}.html" 'text/plain'

        [[ -s ~/.zen/tmp/${MOATS}/${SECTOR}/${SECTOR}.html ]] \
            && rm ${INDEX} \
            && mv ~/.zen/tmp/${MOATS}/${SECTOR}/${SECTOR}.html ${INDEX} \
            && ((gloops++)) \
            && echo "GLOOPS (${gloops}) : ${title}" \
            && signatures=$((signatures + TMPSIGN))

        [[ ! -s ${INDEX} ]] && echo "ERROR. TW could not ingest ~/.zen/tmp/${MOATS}/NEW.json" && exit 1

    else

        ## SAME TIDDLER
        echo "TIDDLER : $title (${TMPSIGN} signature(s)) ... ALREADY EXISTS..."

        ## Remove [] and put inline to compare
        cat ~/.zen/tmp/${MOATS}/TMP.json | jq -rc .[] > ~/.zen/tmp/${MOATS}/INSIDE.json
        cat "${RSS}" | jq -rc ".[] | select(.title == \"$title\")" > ~/.zen/tmp/${MOATS}/NEW.json

        if [[ $(diff ~/.zen/tmp/${MOATS}/NEW.json ~/.zen/tmp/${MOATS}/INSIDE.json) == "" ]]; then
            echo "... Tiddlers are similar ..."
            ((floop++))
            continue
        fi
        floop=1
        ## LOG TIDDLERS
        #~ echo
        #~ echo "=========== INSIDE.json"
        #~ cat ~/.zen/tmp/${MOATS}/INSIDE.json | jq -c
        #~ echo
        #~ echo "=========== NEW.json"
        #~ cat ~/.zen/tmp/${MOATS}/NEW.json | jq -c
        #~ echo
        ## TODO EXTEND CONTROL TO text & ipfs & _canonical_url
        ## NEED SIGNATURES & TIDDLER SIMILARITY TO COME UP

        ## CHECK FOR EMAIL SIGNATURES DIFFERENCE
        NTAGS=$(cat ~/.zen/tmp/${MOATS}/NEW.json | jq -r .tags)
        NEMAILS=($(echo "$NTAGS" | grep -E -o "\b[a-zA-Z0-9.%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,6}\b"))
        NSIGN=${#NEMAILS[@]}
        echo "New Tiddler $NSIGN signatures : ${NEMAILS[*]}"

        ITAGS=$(cat ~/.zen/tmp/${MOATS}/INSIDE.json | jq -r .tags)
        IEMAILS=($(echo "$ITAGS" | grep -E -o "\b[a-zA-Z0-9.%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,6}\b"))
        ISIGN=${#IEMAILS[@]}
        echo "Inside Tiddler $ISIGN signatures : ${IEMAILS[*]}"

        ## New should have more signatures than Inside
        [[ ${NSIGN} -le ${ISIGN} ]] && echo "Most signed already in..." && continue
        ## UPLANET GRID COLLISION PARAM ###
        # [[ ${NSIGN} -le 3 ]] && update TW OR continue
        # https://www.copylaradio.com/blog/blog-1/post/decentralized-information-ecosystem-51

        if [[ "${NEMAILS[*]}" != "${IEMAILS[*]}" ]]; then

            ## SEARCH FOR DIFFERENCE IN EMAIL SIGNATURES TAGS
            COMMON=(); NUNIQUE=(); IUNIQUE=()

            # Detect common and unique elements
            for email in "${NEMAILS[@]}"; do
              if [[ " ${IEMAILS[*]} " == *" $email "* ]]; then
                COMMON+=("$email")
              else
                NUNIQUE+=("$email")
              fi
            done

            for email in "${IEMAILS[@]}"; do
              if [[ " ${NEMAILS[*]} " != *" $email "* ]]; then
                IUNIQUE+=("$email")
              fi
            done

            # Print the results
            echo "Common email addresses : ${COMMON[*]}"
            echo "Email addresses unique in NEW Tiddler : ${NUNIQUE[*]}"
            echo "Email addresses unique in INSIDE Tiddler : ${IUNIQUE[*]}"

            combined=("${IEMAILS[@]}" "${NEMAILS[@]}")
            unique_combined=($(echo "${combined[@]}" | tr ' ' '\n' | sort -u))

            NEWTID=$(ipfs add -q ~/.zen/tmp/${MOATS}/NEW.json | tail -n 1)
            INSIDETID=$(ipfs add -q ~/.zen/tmp/${MOATS}/INSIDE.json | tail -n 1)

            ###############################
            ## TODO : check STAR level and activate auto merge

            for email in "${unique_combined[@]}"; do

echo "<html>
<head>
<style>
    body {
        font-family: 'Courier New', monospace;
    }
    pre {
        white-space: pre-wrap;
    }
</style></head>
<body>
<h1>$(date)</h1>

<h2>$title</h2>
Tiddler appears in <b>${unique_combined[*]}</b> TW(s)
<br>
<ul>
<li><a href='$(myIpfsGw)/ipfs/${INSIDETID}'>Actual Tiddler</a></li>
<li><a href='$(myIpfsGw)/ipfs/${NEWTID}'>NEW Tiddler</a> being overwrite by ${NUNIQUE[*]}</li>
</ul>
<h2><a href='$(myIpfsGw)${VDONINJA}/?room=${MOATS}'>Record VISIO for this event...</a></h2>
</body></html>" > ~/.zen/tmp/${MOATS}/g1message

                ${MY_PATH}/../tools/mailjet.sh "$email" ~/.zen/tmp/${MOATS}/g1message "Upgrade Tiddler : ${title}"

            done

            ## SEND ZEN G1PalPay Signal

    #~ ##############################################################
    #~ G1AMOUNT=$(echo "$NSIGN / 10" | bc -l | xargs printf "%.2f" | sed "s~,~.~g" )
    #~ G1AMOUNT=$NSIGN ## SEND FLUID COIN
    #~ echo "***** SECTOR $SECTOR REWARD *****************"
    #~ echo "SPREAD $NSIGN G1 TO ${unique_combined[@]} SIGNATURES
    #~ to ${PLAYER} WALLET ${ASTROG1}"
    #~ echo "************************************************************"
    #~ ${MY_PATH}/../tools/PAY4SURE.sh ~/.zen/tmp/${MOATS}/sector.dunikey "${$G1AMOUNT}" "${ASTROG1}" "${unique_combined[@]}"
    #~ ################################################ GRATITUDE SENT

            ## AND OVER WRITE TIDDLER...


        else

           echo "SIGNATURES ARE THE SAME : ${NEMAILS[*]}"

        fi

        echo "______________________"
        #~ echo "CHECKING DIFFERENCES"
        #~ diff ~/.zen/tmp/${MOATS}/NEW.json ~/.zen/tmp/${MOATS}/INSIDE.json

        ## TODO CHECK MORE DIFFERENCE
        DATENEW=$(cat ~/.zen/tmp/${MOATS}/NEW.json | jq -r .modified)
        TEXTNEW=$(cat ~/.zen/tmp/${MOATS}/NEW.json | jq -r .text)
        TAGSNEW=$(cat ~/.zen/tmp/${MOATS}/NEW.json | jq -r .tags)
        DATEINSIDE=$(cat ~/.zen/tmp/${MOATS}/INSIDE.json | jq -r .modified)
        TEXTINSIDE=$(cat ~/.zen/tmp/${MOATS}/INSIDE.json | jq -r .text)
        TAGSINSIDE=$(cat ~/.zen/tmp/${MOATS}/INSIDE.json | jq -r .tags)

        TIDLEREMAILSNEW=($(echo "$TAGSNEW" | grep -E -o "\b[a-zA-Z0-9.%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,6}\b")) ## MUST BE SAME IN BOTH
        TIDLEREMAILSINSIDE=($(echo "$TAGSINSIDE" | grep -E -o "\b[a-zA-Z0-9.%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,6}\b")) ## MUST BE SAME IN BOTH
        # [[ "${TIDLEREMAILSNEW[*]}" == "${TIDLEREMAILSINSIDE[*]}" ]]

        if [ ${DATENEW} -gt ${DATEINSIDE} ]; then

            echo "Newer Tiddler version... Updating SECTOR TW"

            tiddlywiki  --load ${INDEX} \
                --import ~/.zen/tmp/${MOATS}/NEW.json "application/json" \
                --output ~/.zen/tmp/${MOATS} --render "$:/core/save/all" "${SECTOR}.html" "text/plain"

            [[ -s ~/.zen/tmp/${MOATS}/${SECTOR}.html ]] \
                && rm ${INDEX} \
                && mv ~/.zen/tmp/${MOATS}/${SECTOR}.html ${INDEX} \
                || ((gloops--))

            signatures=$((signatures + ISIGN))

        fi

    fi

    ## CLEANING
    rm ~/.zen/tmp/${MOATS}/INSIDE.json 2>/dev/null
    rm ~/.zen/tmp/${MOATS}/TMP.json 2>/dev/null
    rm ~/.zen/tmp/${MOATS}/NEW.json 2>/dev/null

done < ~/.zen/tmp/${MOATS}/${SECTOR}/tiddlers.list

####################################################
################################################ ${signatures} -gt ${gloops}
## SECTOR SENDS GRATITUDE TO PUBLISHING PLAYER
###################################################

#~ if [[ ${gloops} -gt 0 && ${signatures} -gt ${gloops} && ${ASTROG1} ]]; then
    #~ # GENERATE SECTOR PRIVATE KEY ################################
    #~ ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/tmp/${MOATS}/sector.dunikey "${UPLANETNAME}${SECTOR}" "${UPLANETNAME}${SECTOR}"
    #~ G1SECTOR=$(cat ~/.zen/tmp/${MOATS}/sector.dunikey | grep 'pub:' | cut -d ' ' -f 2)

    #~ cp -f ~/.zen/tmp/coucou/${G1SECTOR}.COINS ~/.zen/tmp/${IPFSNODEID}/${SECTOR}.COINS

    #~ ##############################################################
    #~ GRATITUDE=$($MY_PATH/../tools/getcoins_from_gratitude_box.sh)
    #~ G1AMOUNT=$(echo "$GRATITUDE / 10" | bc -l | xargs printf "%.2f" | sed "s~,~.~g" )
    #~ echo "***** SECTOR $SECTOR REWARD *****************"
    #~ echo "GRATITUDE ${GRATITUDE} ZEN = ${G1AMOUNT} G1
    #~ to ${PLAYER} WALLET ${ASTROG1} (${gloops} Tiddlers)"
    #~ echo "************************************************************"
    #~ ${MY_PATH}/../tools/PAY4SURE.sh ~/.zen/tmp/${MOATS}/sector.dunikey "${G1AMOUNT}" "${ASTROG1}" "THANKS ${gloops} GLOOPS"
    #~ ################################################ GRATITUDE SENT
#~ fi

exit 0
