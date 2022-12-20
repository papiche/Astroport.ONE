#!/bin/bash
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

ASTRONAUTENS="$1"
MOATS="$2"

[[ ! $ASTRONAUTENS || ! $MOATS ]] && echo "${ME} : ASTRONAUTENS & MOATS needed" && exit 1

start=$(date +%s)
IPFSNODEID=$(ipfs id -f='<id>\n') || ( echo "${ME} : IPFSNODEID MISSING" && exit 1 )
TUBE=$(head -n 2 ~/.zen/Astroport.ONE/A_boostrap_nodes.txt | tail -n 1 | cut -d ' ' -f 3)

            ## GETTING LAST TW via IPFS
            echo "${ME} : IPFS : ipfs --timeout 60s cat  /ipns/${ASTRONAUTENS}"\
            && ipfs --timeout 60s cat  /ipns/${ASTRONAUTENS} > ~/.zen/tmp/coucou/${MOATS}.astroindex.html

             ## GETTING LAST TW via HTTP
            [[ ! -s ~/.zen/tmp/coucou/${MOATS}.astroindex.html ]] \
            && echo "${ME} : WWW : $TUBE/ipns/${ASTRONAUTENS}" \
            && curl -m 60 -so ~/.zen/tmp/coucou/${MOATS}.astroindex.html "$TUBE/ipns/${ASTRONAUTENS}" \
            || curl -m 1 -so ~/.zen/tmp/${MOATS}.html "$TUBE/ipns/${ASTRONAUTENS}" ## Ask caching

        ### GOT TW !!
        if [[ -s ~/.zen/tmp/coucou/${MOATS}.astroindex.html ]]; then
            echo "${ME} : GOT TW !!"

            tiddlywiki --load ~/.zen/tmp/coucou/${MOATS}.astroindex.html  --output ~/.zen/tmp --render '.' ${MOATS}'MadeInZion.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'MadeInZion'
            [[ ! -s ~/.zen/tmp/${MOATS}MadeInZion.json ]] && echo "${ME} : BAD TW (☓‿‿☓) Execution time was "`expr $(date +%s) - $start` seconds. && exit 1

            PLAYER=$(cat ~/.zen/tmp/${MOATS}MadeInZion.json | jq -r .[].player)

            ## EMAIL STYLE
            if [[ "${PLAYER}" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$ ]]; then
                echo "${ME} : VALID PLAYER (✜‿‿✜) $PLAYER "

                tiddlywiki --load ~/.zen/tmp/coucou/${MOATS}.astroindex.html  --output ~/.zen/tmp --render '.' ${MOATS}'Astroport.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'Astroport'
                [[ ! -s ~/.zen/tmp/${MOATS}Astroport.json ]] && echo "${ME} : BAD TW (☓‿‿☓) Execution time was "`expr $(date +%s) - $start` seconds. && exit 1

                ## EXPORT PLAYER VALUE TO CALLING SCRIPT
                export PLAYER=$PLAYER

            else
                echo "${ME} : BAD PLAYER"
                echo "${ME} : KO ${PLAYER} : (#__#) '" && exit 1
            fi

            ## IN CACHE
            echo "${ME} : CACHING ~/.zen/tmp/$IPFSNODEID/$PLAYER/"
            mkdir -p ~/.zen/tmp/$IPFSNODEID/$PLAYER/
            cp -f ~/.zen/tmp/coucou/${MOATS}.astroindex.html ~/.zen/tmp/$IPFSNODEID/$PLAYER/index.html

        ### NO TW !!
        else

            echo "${ME} : (-__-) NOTHING (-__-)"

        fi

dur=`expr $(date +%s) - $start`
[[ $XDG_SESSION_TYPE == 'x11' ]] && espeak "$dur seconds for $(cat ~/.zen/tmp/${MOATS}Astroport.json | jq -r .[].pseudo) TW caching"

echo "${ME} : (0‿‿0) Execution time was $dur seconds."
exit 0
