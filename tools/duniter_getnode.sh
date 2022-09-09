#!/bin/bash
################################################################################
# Authors: @jytou (https://git.duniter.org/jytou)
#         Modified by Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# Checks the current block number of $DIR/duniter_nodes.txt (is run in parallel)
# and output random (from last synchronized) node

checkonenode()
{
	# Timeout in seconds for https nodes
	httpsTimeout=1
	# Timeout in seconds for http nodes
	httpTimeout=1

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
	# Put the result into the file
	echo "$cur $n">$outfile
	# Notify that we're done here
	touch $outfile.done
}

# Temp dir where results are stored
rm -Rf /tmp/zen/gnodewatch
DIR=/tmp/zen/gnodewatch
export DIR
mkdir -p $DIR/chains
# TODO: REMOVE 777 PATCH, ACTIVATE ramdisk
# sudo mkdir /mnt/ramdisk
# sudo mount -t tmpfs -o size=50m tmpfs /mnt/ramdisk
chmod -R 777 /tmp/zen/

# KEEP /tmp/zen/current.duniter for 5 mn
find /tmp/zen/ -mmin +5 -type f -name "current.duniter" -exec rm -f '{}' \;
[[ -f /tmp/zen/current.duniter ]] && cat /tmp/zen/current.duniter && exit 0

##### $DIR/duniter_nodes.txt REFRESH after 20 minutes #####
find $DIR/ -mmin +20 -type f -name "duniter_*" -exec rm -f '{}' \;
if [[ ! -f  $DIR/duniter_nodes.txt ]]; then
	# Get New BMAS known Nodes list from shuffle one $DIR/good.nodes.txt
	[[ -f $DIR/good.nodes.txt ]] && DUNITER=$(shuf -n 1 $DIR/good.nodes.txt) || DUNITER="duniter-g1.p2p.legal:443"	
	curl -s https://$DUNITER/network/peers | jq '.peers[] | .endpoints' | grep BMAS | awk '{print $2,$3}' | sed s/\"//g | sed s/\,//g | sed s/\ /:/g | sort -u > $DIR/duniter_nodes.txt
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
	checkonenode $node "$watched" $DIR/$index.out &
	((index++))
done

# Wait a little for the first files to be created
sleep 1s
# Wait for all the threads to report they are done
while [ `ls $DIR/*done|wc -l` -lt $index ]
do
	sleep 1s
done

# Grab all results
curs=`cat $DIR/*out|sort`
# Extract all forks, excluding all errors
chains="`echo "$curs"|grep -v ERROR|awk '{print $1}'|sort -r|uniq`"

# Count the number of chains and output most recent consensus to "good.nodes.txt"
nb=0
for chain in $chains
do
	echo "$curs" | egrep "^$chain " | awk '{print $2}' >> $DIR/chains/$nb;
	((nb++))
done

longchain=$(ls -S $DIR/chains/ | head -n 1)
# WRITE OUT shuffle Duniter Node Sync with longest chain
cp $DIR/chains/$longchain $DIR/good.nodes.txt

## TEST if server is really running Duniter
Dtest=""; IDtest=""; lastresult=""; loop=0
while [[ $Dtest != "duniter" ]]; do
    while [[ $lastresult == $result &&  $loop -lt 7 ]]; do result=$(shuf -n 1 $DIR/good.nodes.txt); ((loop++)); done
    lastresult=$result
    Dtest=$(curl -s https://$lastresult | jq -r .duniter.software)
    ## CHECK if server is not too slow
    [[ $Dtest == "duniter" ]] && IDtest=$(silkaj -p $lastresult id Fred)
    [[ $IDtest == "" ]] && Dtest=""
    [[ $loop -eq 8 ]] && result="duniter-g1.p2p.legal:443" && break
    ((loop++))
done


echo "$result" > /tmp/zen/current.duniter

echo $result
