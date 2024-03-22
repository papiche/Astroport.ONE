################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
################################################################################
## API: AMZQR
## An API to create QRCode with logo
# ?amzqr=URLENCODEDSTRING&logo=IMAGE
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/../tools/my.sh"

start=`date +%s`

echo "PORT=$1
THAT=$2
AND=$3
THIS=$4
APPNAME=$5
WHAT=$6
OBJ=$7
VAL=$8
MOATS=$9
COOKIE=$10"
PORT="$1" THAT="$2" AND="$3" THIS="$4"  APPNAME="$5" WHAT="$6" OBJ="$7" VAL="$8" MOATS="$9" COOKIE="$10"

[[ "$PORT" == "" ]] && echo "$MY_PATH/AMZQR.sh '0' 'la chaine a mettre en QRCODE' 'et' 'TV'" && exit 1

HTTPCORS="HTTP/1.1 200 OK
Access-Control-Allow-Origin: ${myASTROPORT}
Access-Control-Allow-Credentials: true
Access-Control-Allow-Methods: GET
Server: Astroport.ONE
Content-Type: text/html; charset=UTF-8

"

function urldecode() { : "${*//+/ }"; echo -e "${_//%/\\x}"; }


[[ ${MOATS} == "" ]] && MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
mkdir -p ~/.zen/tmp/${MOATS}/

##################################################
USTRING=$(urldecode "${THAT}")
IMAGE="${THIS}"

[[ ! -s ${MY_PATH}/../images/${IMAGE}.png || ${USTRING} == "" ]] \
    && echo "UNKNOW IMAGE ${IMAGE}" \
    &&  ( [[ $PORT != "0" ]] && echo "$HTTPCORS ERROR - BAD PARAMS" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) \
    &&  echo "(☓‿‿☓) Execution time was "`expr $(date +%s) - $start` seconds. &&  exit 1

echo amzqr "${USTRING}" -l H -c -p ${MY_PATH}/../images/${IMAGE}.png -n ${MOATS}.png -d ~/.zen/tmp/${MOATS}/

## RUN AMZQR
amzqr "${USTRING}" -l H -c -p ${MY_PATH}/../images/${IMAGE}.png -n ${MOATS}.png -d ~/.zen/tmp/${MOATS}/
IPFSMG=$(ipfs add -q ~/.zen/tmp/${MOATS}/${MOATS}.png | tail -n 1)
echo "${myIPFS}/ipfs/${IPFSMG}"

echo "$HTTPCORS <meta http-equiv=\"refresh\" content=\"0; url='${myIPFS}/ipfs/${IPFSMG}'\" />" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &

if [[ $PORT == "0" ]]; then
    [[ $XDG_SESSION_TYPE == 'x11' || $XDG_SESSION_TYPE == 'wayland' ]] && xdg-open ${myIPFS}/ipfs/${IPFSMG}

    LP=$(ls /dev/usb/lp* 2>/dev/null | head -n1)
    [[ ! $LP ]] && echo "NO PRINTER FOUND - Brother QL700 validated" && exit 1

    echo "IMPRESSION QRCODE"
    brother_ql_create --model QL-700 --label-size 62 ~/.zen/tmp/${MOATS}/${MOATS}.png > ~/.zen/tmp/${MOATS}/toprint.bin 2>/dev/null
    sudo brother_ql_print ~/.zen/tmp/${MOATS}/toprint.bin $LP

fi

rm -Rf ~/.zen/tmp/${MOATS}/
end=`date +%s`
echo "(AMZQR) Operation time was "`expr $end - $start` seconds.
exit 0
