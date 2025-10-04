#!/bin/bash
################################################################################
# Authors: @jytou (https://git.duniter.org/jytou)
#         Modified by Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# Checks the current block number of $DIR/duniter_nodes.txt (is run in parallel)
# and output random (from last synchronized) node
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized

BOOSTER=(g1.brussels.ovh duniter-v1.comunes.net g1.cgeek.fr g1.duniter.fr g1.astroport.com g1.guenoel.fr duniter.econolib.re)

checkonenode()
{
    # Timeout in seconds for https nodes
    httpsTimeout=2
    # Timeout in seconds for http nodes
    httpTimeout=2

    node=$1
    watched=$2
    outfile=$3
    # Curl: -m timeout, -k ignore SSL certificate errors
    cur=`echo "$( { curl -m $httpsTimeout -k https://$node/blockchain/current; } 2>&1 )"`
    n=$node
    if [[ "$cur" != *issuersFrameVar* ]]
    then
        # It failed in https, maybe try http?
        cur=`echo "$( { curl -m $httpTimeout http://$node/blockchain/current; } 2>&1 )"`
        if [[ "$cur" == *issuersFrameVar* ]]
        then
            # Indicate that the node is http
            n="$n-(http)"
        fi
    fi
    if [[ "$cur" != *issuersFrameVar* ]]
    then
        # The node didn't respond on time
        cur="ERROR"
    else
        # The node did respond - grab the block number and hash of the block as key
        cur="`echo "$cur"|grep '^  "number": '|awk '{print $2}'|awk -F, '{print $1}'`-`echo "$cur"|grep '^  "hash": '|awk '{print $2}'|awk '{print substr($1,2,13)}'`"
    fi
    if [[ $watched =~ .*#$node#.* ]]
    then
        # The node is a watched node, add some bold
        n="\e[1m$n\e[0m"
    fi
    echo "$node : $cur"
    # Put the result into the file
    echo "$cur $n">$outfile
    # Notify that we're done here
    touch $outfile.done
}

# Temp dir where results are stored
rm -Rf ~/.zen/tmp/gnodewatch
DIR=~/.zen/tmp/gnodewatch
export DIR
mkdir -p $DIR/chains

# REMOVE CACHE
rm -f ~/.zen/tmp/current.duniter
rm -f ~/.zen/tmp/current.duniter.bmas

##### $DIR/duniter_nodes.txt REFRESH after 30 minutes #####
find $DIR/ -mmin +30 -type f -name "duniter_*" -exec rm -f '{}' \;
if [[ ! -f  $DIR/duniter_nodes.txt ]]; then
    # Get New BMAS known Nodes list from shuffle one $DIR/good.nodes.txt
    [[ -f $DIR/good.nodes.txt ]] && DUNITER=$(shuf -n 1 $DIR/good.nodes.txt) || DUNITER="${BOOSTER[$((RANDOM % ${#BOOSTER[@]}))]}:443"
    curl -s -m 10 https://$DUNITER/network/peers | jq '.peers[] | .endpoints' | grep GVA | awk '{print $3,$4}' | sed s/\"//g | sed s/\,//g | sed s/\ /:/g | sort -u > $DIR/duniter_nodes.txt
    [[ "$1" == "BMAS" ]] && curl -s -m 10 https://$DUNITER/network/peers | jq '.peers[] | .endpoints' | grep BMAS | awk '{print $2,$3}' | sed s/\"//g | sed s/\,//g | sed s/\ /:/g | sort -u > $DIR/duniter_nodes.txt
fi

# Grab the nodes we are actively watching - they will be in bold in the final output
watched=`grep -v "#" $DIR/duniter_nodes.txt|egrep "\!$"|awk '{print "#" $1 "#"}'`
# All nodes we are watching
nodes=`grep -v "#" $DIR/duniter_nodes.txt|awk '{print $1}'`
# The index to generate separate file names
index=0
# Wipe out the output directory
rm $DIR/*out $DIR/*done $DIR/chains/* $DIR/NODE.* 2>/dev/null

# Query all nodes in parallel
for node in $nodes
do
    #~ echo "checkonenode $node "$watched" $DIR/$index.out"
    checkonenode $node "$watched" $DIR/$index.out &
    #~ cat $DIR/$index.out
    ((index++))
done

# Wait a little for the first files to be created
sleep 3s
# Wait for all the threads to report they are done with timeout
timeout_counter=0
max_timeout=60  # Maximum 60 seconds (30 * 2s intervals)
while [ `ls $DIR/*done 2>/dev/null | wc -l` -lt $index ]
do
    sleep 2s
    timeout_counter=$((timeout_counter + 1))
    if [ $timeout_counter -gt $max_timeout ]; then
        echo "WARNING: Timeout waiting for node responses, proceeding with available results" >&2
        break
    fi
done

# Grab all results - check if files exist first
if ls $DIR/*out 1> /dev/null 2>&1; then
    curs=`cat $DIR/*out|sort`
    # Extract all forks, excluding all errors
    chains="`echo "$curs"|grep -v ERROR|awk '{print $1}'|sort -r|uniq`"
else
    curs=""
    chains=""
fi

# Count the number of chains and output most recent consensus to "good.nodes.txt"
nb=0
if [[ -n "$chains" ]]; then
    for chain in $chains
    do
        echo "$curs" | egrep "^$chain " | awk '{print $2}' >> $DIR/chains/$nb;
        ((nb++))
    done

    longchain=$(ls -S $DIR/chains/ | head -n 1)
    echo "CHAIN:$chains"
    # WRITE OUT shuffle Duniter Node Sync with longest chain
    if [[ -f "$DIR/chains/$longchain" ]]; then
        cat $DIR/chains/$longchain | shuf > $DIR/good.nodes.txt
    else
        # Fallback to booster nodes if no chains found
        printf "%s\n" "${BOOSTER[@]}" | sed 's/$/:443/' > $DIR/good.nodes.txt
    fi
else
    echo "CHAIN: No valid chains found"
    # Fallback to booster nodes if no chains found
    printf "%s\n" "${BOOSTER[@]}" | sed 's/$/:443/' > $DIR/good.nodes.txt
fi

## TEST if server is really running Duniter
Dtest=""; IDtest=""; lastresult=""; loop=0

# Check if good.nodes.txt exists and has content
if [[ ! -f "$DIR/good.nodes.txt" ]] || [[ ! -s "$DIR/good.nodes.txt" ]]; then
    echo "No valid nodes found, using fallback"
    [[ "$1" == "BMAS" ]] && result="g1.duniter.org" || result="https://duniter-v1.comunes.net/gva"
else
    while read lastresult;
    do

        ## CHECK if server is not too slow
        echo "curl -s -m 2 https://$lastresult | jq -r .duniter.software"
        Dtest=$(curl -s -m 2 https://$lastresult | jq -r .duniter.software)
        echo "$Dtest"

        if [[ "$Dtest" == "duniter" ]]; then
            if [[ "$1" == "BMAS" ]]; then
                echo "silkaj --json --endpoint $lastresult wot lookup DsEx1pS33vzYZg4MroyBV9hCw98j1gtHEhwiZ5tK7ech"
                IDtest=$(silkaj --json --endpoint $lastresult wot lookup DsEx1pS33vzYZg4MroyBV9hCw98j1gtHEhwiZ5tK7ech 2>/dev/null | jq -r '.results[0].identities[0].uid // empty')
                echo "IDtest result: $IDtest"
                [[ -n "$IDtest" && "$IDtest" != "null" ]] && result="$lastresult" && break

                [[ $loop -eq 8 ]] \
                    && result="g1.duniter.org" && break
            else
                gvaserver=$(echo $lastresult | sed "s~:443~/gva~g" )
                echo "jaklis -n https://$gvaserver idBalance -p 2L8vaYixCf97DMT8SistvQFeBj7vb6RQL7tvwyiv1XVH"
                IDtest=$(jaklis -n https://$gvaserver idBalance -p 2L8vaYixCf97DMT8SistvQFeBj7vb6RQL7tvwyiv1XVH 2>/dev/null | jq -r .balance)
                echo $IDtest
                [[ $IDtest != "" && $IDtest != "null" ]] && result="https://$gvaserver" && break

                [[ $loop -eq 8 ]] \
                    && result="https://duniter-v1.comunes.net/gva" && break
            fi
        fi

        ((loop++))

    done < $DIR/good.nodes.txt
fi

[[ -n "$result" && -n "$1" ]] \
    && sed -i '/^NODE=/d' ${MY_PATH}/../tools/jaklis/.env \
    && echo "NODE=$result" >> ${MY_PATH}/../tools/jaklis/.env

# Save result in appropriate cache file
if [[ -n "$result" ]]; then
    if [[ "$1" == "BMAS" ]]; then
        echo "$result" > ~/.zen/tmp/current.duniter.bmas
        echo "Saved BMAS server to cache: $result"
    else
        echo "$result" > ~/.zen/tmp/current.duniter
        echo "Saved GVA server to cache: $result"
    fi
fi

echo $result
