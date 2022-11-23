#!/bin/bash
########################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.3
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
# COPY ~/Astroport/mp3/artist/song files to IPFS
######## #### ### ## #
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"
YOU=$(ipfs swarm peers >/dev/null 2>&1 && echo "$USER" || ps auxf --sort=+utime | grep -w ipfs | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1);
IPFSNODEID=$(ipfs id -f='<id>\n')
G1PUB=$(cat ~/.zen/secret.dunikey | grep 'pub:' | cut -d ' ' -f 2)
# GET XZUID
[[ -f ~/.zen/ipfs/.$IPFSNODEID/G1SSB/_g1.gchange_title ]] && XZUID=$(cat ~/.zen/ipfs/.$IPFSNODEID/G1SSB/_g1.gchange_title) || XZUID=$(cat /etc/hostname)
########################################################################
path="$1"
# Add trailing / if needed
length=${#path} 
last_char=${path:length-1:1}
[[ $last_char != "/" ]] && path="$path/"; :

file="$2"

echo "~/.zen/astrXbian/zen/new_mp3_in_astroport.sh PATH/ \"$path\" FILE \"$file\""
[[ ! -f "${path}${file}" ]] && echo "Fichier introuvable ... EXIT" && exit 1

echo '#### NEED REWRITING #####' && exit 0
read

YTEMP="/tmp/$(date -u +%s%N | cut -b1-13)"
mkdir -p ${YTEMP}

YID=$(echo "${file}" | cut -d "_" -f 1)
YNAME=$(echo "${file}" | cut -d "_" -f 2-)
TITLE="${YNAME%.*}"
FILE_EXT="${file##*.}"
[[ "$FILE_EXT" != "mp3" ]] && echo "Extension inconnue. Seul le format mp3 est accepté ... EXIT" && exit 1

[[ ! $(echo "$path" | cut -d '/' -f 4 | grep 'astroport') ]] && echo "Les fichiers sont à placer dans ~/Astroport/mp3/ MERCI" && exit 1
CAT=$(echo "$path" | cut -d '/' -f 5 ) # mp3
ARTIST=$(echo "$path" | cut -d '/' -f 6 ) # artist || YID
ALBUM=$(echo "$path" | cut -d '/' -f 7 ) # album || _o-o_ || EMPTY
[[ "$ALBUM" == "" ]] && echo "ARTIST = YID = $ARTIST"

CAT=$(echo "$CAT" | awk '{ print tolower($0) }')

########################################################################
########################################################################
# MOVE SECTION in new_mp3_in_astroport.sh
DURATION=$(mp3info -p "%S" "${path}${file}")
float=$(echo "$DURATION/1.618" | bc -l) && GOLDENTIME=${float%.*}

## EXTRACT 5 seconds from GOLDENTIME
ffmpeg -loglevel quiet -ss $GOLDENTIME -t 5 -i "${path}${file}" /tmp/5s_${YID}.mp3

## TRY TO RECOGNIZE WITH mazash
## CHECK if 8600 port is active
## ipfs p2p forward /x/oasis-mazash /ip4/127.0.0.1/tcp/8600 /p2p/12D3KooWBYme2BsNUrtx4mEdNX6Yioa9AV7opWzQp6nrPs6ZKabN
SAMPLEID=$(ipfs add -q /tmp/5s_${YID}.mp3)
RECOG=$(curl -sX POST "http://localhost:8600/api/v1/mazash/recognize" -H  "accept: application/json" -H  "Content-Type: application/json" -d "{\"cid\":\"${SAMPLEID}\",\"extension\":\".mp3\"}")
CONFIANCE=$(echo $RECOG | jq .results[].input_confidence | tail -n 1)
MAZASHID=$(echo $RECOG | jq .results[].file_sha1 | tail -n 1)
IPNSID=$(echo $RECOG | jq .results[].song_name | tail -n 1)

echo "$CONFIANCE MATCHING $MAZASHID ($IPNSID)"

## NEEDED TO CREATE IPNS KEY
INDEXPREFIX="MP3_"
REFERENCE="${YID}"

########################################################################
########################################################################
########################################################################

echo "-----------------------------------------------------------------"

IPFSREPFILEID=$(ipfs add -wq "${path}${file}" | tail -n 1)
[[ $IPFSREPFILEID == "" ]] && echo "ipfs add ERROR" && exit 1
echo "-----------------------------------------------------------------"
echo "IPFS: $file : ipfs ls /ipfs/$IPFSREPFILEID"
echo "-----------------------------------------------------------------"

URLENCODE_FILE_NAME=$(echo ${file} | jq -Rr @uri)

########################################################################
## CREATE NEW ipns KEY : ${INDEXPREFIX}${REFERENCE}
########################################################################
########################################################################
[[ ! -d  ~/.zen/ipfs/.${IPFSNODEID}/KEY/${INDEXPREFIX}${REFERENCE}/${G1PUB} ]] && mkdir -p ~/.zen/ipfs/.${IPFSNODEID}/KEY/${INDEXPREFIX}${REFERENCE}/${G1PUB} && KEY=$(ipfs key gen "${INDEXPREFIX}${REFERENCE}") && KEYFILE=$(ls -t ~/.ipfs/keystore/ | head -n 1)
## INIT ipns 
if [[ $KEY ]]; then
	# memorize IPNS key filename for easiest exchange
	echo "$KEYFILE" > ~/.zen/ipfs/.${IPFSNODEID}/KEY/${INDEXPREFIX}${REFERENCE}/${G1PUB}/.ipns.key.keystore_filename
	# Publishing IPNS key
	echo "$KEY" > ~/.zen/ipfs/.${IPFSNODEID}/KEY/${INDEXPREFIX}${REFERENCE}/${G1PUB}/.ipns.link
	# .zen could contain ZEN for economic value
	touch ~/.zen/ipfs/.${IPFSNODEID}/KEY/${INDEXPREFIX}${REFERENCE}/${G1PUB}/.zen

	################ ENCRYPT keystore/$KEYFILE
	$MY_PATH/tools/natools.py encrypt -p $G1PUB -i ~/.ipfs/keystore/$KEYFILE -o ~/.zen/ipfs/.${IPFSNODEID}/KEY/${INDEXPREFIX}${REFERENCE}/${G1PUB}/.ipns.key.natools.encrypt
else
	KEY=$(cat ~/.zen/ipfs/.${IPFSNODEID}/KEY/${INDEXPREFIX}${REFERENCE}/${G1PUB}/.ipns.link)
	KEYFILE=$(cat ~/.zen/ipfs/.${IPFSNODEID}/KEY/${INDEXPREFIX}${REFERENCE}/${G1PUB}/.ipns.key.keystore_filename)
fi
	
# CLEAR ipfs link (then encrypted to manage exchange regulation)
echo "/ipfs/$IPFSREPFILEID/${file}" > ~/.zen/ipfs/.${IPFSNODEID}/KEY/${INDEXPREFIX}${REFERENCE}/${G1PUB}/.ipfs.filelink
################ ENCRYPT .ipfs.filelink
$MY_PATH/tools/natools.py encrypt -p $G1PUB -i ~/.zen/ipfs/.${IPFSNODEID}/KEY/${INDEXPREFIX}${REFERENCE}/${G1PUB}/.ipfs.filelink -o ~/.zen/ipfs/.${IPFSNODEID}/KEY/${INDEXPREFIX}${REFERENCE}/${G1PUB}/.ipfs.filelink.natools.encrypt
rm ~/.zen/ipfs/.${IPFSNODEID}/KEY/${INDEXPREFIX}${REFERENCE}/${G1PUB}/.ipfs.filelink

echo "${file}" > ~/.zen/ipfs/.${IPFSNODEID}/KEY/${INDEXPREFIX}${REFERENCE}/${G1PUB}/.ipfs.filename
echo "${TITLE}" > ~/.zen/ipfs/.${IPFSNODEID}/KEY/${INDEXPREFIX}${REFERENCE}/${G1PUB}/.title
echo "$(date -u +%s%N | cut -b1-13)" > ~/.zen/ipfs/.${IPFSNODEID}/KEY/${INDEXPREFIX}${REFERENCE}/${G1PUB}/.timestamp

# IPNS index.html Redirect to ipfs streaming link (could be contract or anything else !!)
echo "<meta http-equiv=\"Refresh\" content=\"0;URL=http://127.0.0.1:8080/ipfs/$IPFSREPFILEID/$URLENCODE_FILE_NAME\">" > ~/.zen/ipfs/.${IPFSNODEID}/KEY/${INDEXPREFIX}${REFERENCE}/${G1PUB}/index.html

IPNSLINK=$(ipfs key list -l | grep ${INDEXPREFIX}${REFERENCE} | cut -d ' ' -f 1)
echo "<meta http-equiv=\"Refresh\" content=\"10;URL=https://aries.copylaradio.com/ipns/$IPNSLINK/${G1PUB}/\">
<h1><a href='https://astroport.com'>ASTROPORT</a>/MP3</h1>
Pour écouter ${TITLE}, connectons nos stations et devenons amis...<br><br>
Installez <a href='https://copylaradio.com'>astrXbian</a>" > ~/.zen/ipfs/.${IPFSNODEID}/KEY/${INDEXPREFIX}${REFERENCE}/index.html

NEWIPFS=$(ipfs add -rHq ~/.zen/ipfs/.${IPFSNODEID}/KEY/${INDEXPREFIX}${REFERENCE}/ | tail -n 1 )
IPNS=$(ipfs name publish --quieter --key="${INDEXPREFIX}${REFERENCE}" $NEWIPFS)
########################################################################

## CHECK CONFIANCE and decide to fingerprint
if (( $(echo "$CONFIANCE < 0.9" | bc -l) )); then
	# fingerprint track & USE IPNS KEY for "song_name"
	NEWCOG=$(curl -X POST "http://localhost:8600/api/v1/mazash/fingerprint" -H  "accept: application/json" -H  "Content-Type: application/json" -d "{\"cid\":\"${IPFSREPFILEID}\",\"extension\":\".mp3\",\"song\":\"${IPNS}\"}")
	echo "$NEWCOG" | jq
fi

# MEMORIZE NEW PIN
mkdir -p ~/.zen/PIN/${IPFSREPFILEID}/${IPNS}/
touch "~/.zen/PIN/${IPFSREPFILEID}/${IPNS}/${TITLE}"
echo "${file}" > ~/.zen/PIN/${IPFSREPFILEID}/${IPNS}/.ipfs.filename
echo "${TITLE}" > ~/.zen/PIN/${IPFSREPFILEID}/${IPNS}/.title

########################################################################
# REFRESH IPNS SELF PUBLISH
########################################################################
~/.zen/astrXbian/zen/ipns_self_publish.sh
########################################################################

rm -Rf ${YTEMP}
echo "NEW ($file) ADDED."
echo "IPNS LINK : http://127.0.0.1:8080/ipns/$KEY/$G1PUB/"

exit 0
