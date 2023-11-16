#!/bin/bash
########################################################################
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
# INSERT NEW TIDDLERS FROM RSS JSON INTO UPLANET TW
# DETECTING CONFLICT WITH ON SAME TITLE
# ASKING TO EXISTING SIGNATURES TO UPDATE THEIR TW OR FORK TITLE
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

RSS=$1
SECTOR=$2
MOATS=$3
INDEX=$4

[[ ! -s ${RSS} ]] && echo "BAD RSS INPUT" && exit 1
[[ ! -d ~/.zen/tmp/${MOATS}/${SECTOR}/ ]] && echo "BAD UPLANET CONTEXT" && exit 1
[[ ! -s ${INDEX} ]] && echo "BAD TW INDEX" && exit 1

echo "SECTOR TW INSERTING" ${RSS}

cat "${RSS}" | jq -r '.[] | .title' > ~/.zen/tmp/${MOATS}/titles.list

while read title; do

    [[ ${title} == "GettingStarted" || ${title} == "GPS" || ${title} == "AstroID" || ${title} == "Astroport" || ${title} == "MadeInZion" || ${title} == "ZenCard" || ${title::5} == "Draft" ]] \
        && echo "FILTERED TITLE ${title}" && continue

    ## CHECK FOR TIDDLER WITH SAME TITTLE IN SECTOR TW
    rm -f ~/.zen/tmp/${MOATS}/TMP.json
    tiddlywiki --load ${INDEX}  --output ~/.zen/tmp/${MOATS} --render '.' 'TMP.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' "${title}"
    ISHERE=$(cat ~/.zen/tmp/${MOATS}/TMP.json | jq -r ".[].title")

    if [[ "${ISHERE}" != "${title}" ]]; then

        ## NEW TIDDLER
        echo "Importing Title: $title"
        cat "${RSS}" | jq -rc ".[] | select(.title == \"$title\")" > ~/.zen/tmp/${MOATS}/NEW.json

        tiddlywiki  --load ${INDEX} \
            --import ~/.zen/tmp/${MOATS}/NEW.json "application/json" \
            --output ~/.zen/tmp/${MOATS} --render "$:/core/save/all" "${SECTOR}.html" "text/plain"

        [[ -s ~/.zen/tmp/${MOATS}/${SECTOR}.html ]] \
            && rm ${INDEX} \
            && mv ~/.zen/tmp/${MOATS}/${SECTOR}.html ${INDEX} \
            && echo "SECTOR TW UPDATED"

    else

        ## SAME TIDDLER
        echo "TIDDLER WITH TITLE $title ALREADY EXISTS..."
        # IS IT FROM SAME PLAYER

        cat ~/.zen/tmp/${MOATS}/TMP.json | jq -rc ".[] | select(.title == \"$title\")" > ~/.zen/tmp/${MOATS}/INSIDE.json
        cat "${RSS}" | jq -rc ".[] | select(.title == \"$title\")" > ~/.zen/tmp/${MOATS}/NEW.json

        [[ ! $(diff ~/.zen/tmp/${MOATS}/NEW.json ~/.zen/tmp/${MOATS}/INSIDE.json) ]] && echo "... Tiddlers are similar ..." && continue

        ## CHECK FOR EMAIL SIGNATURES DIFFERENCE
        NTAGS=$(cat ~/.zen/tmp/${MOATS}/NEW.json | jq -r .tags)
        NEMAILS=($(echo "$NTAGS" | grep -E -o "\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,6}\b"))
        N=${#NEMAILS[@]}
        echo "New Tiddler signatures : ${NEMAILS[*]}"

        ITAGS=$(cat ~/.zen/tmp/${MOATS}/INSIDE.json | jq -r .tags)
        IEMAILS=($(echo "$ITAGS" | grep -E -o "\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,6}\b"))
        I=${#IEMAILS[@]}
        echo "Inside Tiddler signatures : ${IEMAILS[*]}"

        ## NB: COULD NEED SORTING (TODO)

        if [[ "${NEMAILS[*]}" != "${IEMAILS[*]}" ]]; then

            ## DIFFERENCE IN EMAIL SIGNATURES
            COMMON=()
            NUNIQUE=()
            IUNIQUE=()

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
            echo "Email addresses unique in ACTUAL Tiddler : ${IUNIQUE[*]}"

            combined=("${IEMAILS[@]}" "${NEMAILS[@]}")
            unique_combined=($(echo "${combined[@]}" | tr ' ' '\n' | sort -u))

            NEWTID=$(ipfs add -q ~/.zen/tmp/${MOATS}/NEW.json | tail -n 1)
            INSIDETID=$(ipfs add -q ~/.zen/tmp/${MOATS}/INSIDE.json | tail -n 1)

            for email in "${unique_combined[@]}"; do

echo "Hello\n\n
A tiddler with same title is existing in ${unique_combined[*]} TW(s) \n\n
$title\n\n
Please choose update your TW grabbing it from\n
* ACTUAL : ${myIPFS}/ipfs/${INSIDETID}\n
* NEW : ${myIPFS}/ipfs/${NEWTID}\n\n
or fork modifying titles

You can discuss about it in room ${MOATS}\n
https://vdo.copylaradio.com
" > ~/.zen/tmp/${MOATS}/g1message

                ${MY_PATH}/mailjet.sh "$email" ~/.zen/tmp/${MOATS}/g1message

                ${MY_PATH}/mailjet.sh "support@q1sms.fr" ~/.zen/tmp/${MOATS}/g1message ## DEBUG LOG ANALYSE # TODO REMOVE #

            done

        ##  TITLE FORK TO BE SOLVED. NEED "SAME EMAILS SIGNATURES"
        continue

        fi

        ## DIFFERENT
        NMODIFIED=$(cat ~/.zen/tmp/${MOATS}/NEW.json | jq -r .modified)
        IMODIFIED=$(cat ~/.zen/tmp/${MOATS}/INSIDE.json | jq -r .modified)

        if [ ${NMODIFIED} -gt ${IMODIFIED} ]; then

            echo "Newer Tiddler version... Updating TW"

            tiddlywiki  --load ${INDEX} \
                --import ~/.zen/tmp/${MOATS}/NEW.json "application/json" \
                --output ~/.zen/tmp/${MOATS} --render "$:/core/save/all" "${SECTOR}.html" "text/plain"

            [[ -s ~/.zen/tmp/${MOATS}/${SECTOR}.html ]] \
                && rm ${INDEX} \
                && mv ~/.zen/tmp/${MOATS}/${SECTOR}.html ${INDEX}

        fi

    fi

done < ~/.zen/tmp/${MOATS}/titles.list
