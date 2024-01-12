#!/bin/bash
########################################################################
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
# MAKE PAYMENTS ON DUNITER BLOCKCHAIN
# VERIFY SUCCES & RENEW IF FAILED
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

. "${MY_PATH}/my.sh"

## REDIRECT OUTPUT TO "coucou/pay4sure.log"
exec 2>&1 >> ~/.zen/tmp/coucou/pay4sure.log

KEYFILE="$1"
AMOUNT="$2"
G1PUB="$3"
COMMENT="$4"
MOATS="$5" ## RECALL PENDING

echo "KEYFILE=${KEYFILE}
AMOUNT=${AMOUNT}
G1PUB=${G1PUB}
COMMENT=${COMMENT}"

[[ -z $MOATS ]] \
    && MOATS=$(date -u +"%Y%m%d%H%M%S%4N") \
    || echo "OLD PAYMENT FAILURE = NEW TRY $MOATS"

## CHECKING PAYOUT WALLET (dunikey file)
[[ -s ${KEYFILE} ]] \
    && PAYOUTPUB=$(cat ${KEYFILE} | grep "pub:" | cut -d ' ' -f 2) \
    || { echo "ERROR : MISSING SECRET KEY FILE"  && exit 1; }

COINS=$($MY_PATH/COINScheck.sh ${PAYOUTPUB} | tail -n 1)
###### TEST INPUT VALUES
[[ $AMOUNT == "ALL" ]] && AMOUNT=$COINS ## ALL MEAN EMPTY ORIGIN WALLET
[[ -z $AMOUNT ]] && echo "ERROR : ${PAYOUTPUB}=$COINS MISSING AMOUNT" && exit 1
[[ $AMOUNT =~ ^[0-9]+([.][0-9]+)?$ ]] && echo "Valid AMOUNT=${AMOUNT}" || { echo "ERROR NOT a valid AMOUNT : ${AMOUNT}" && exit 1; }

[[ $(echo "$COINS < $AMOUNT" | bc -l) -eq 1 ]] && echo "ERROR : SOURCE WALLET IS MISSING COINS !!! $AMOUNT > $COINS" && exit 1
[[ -z $G1PUB ]] && echo "ERROR : ${PAYOUTPUB}=$COINS ($AMOUNT) MISSING DESTINATION" && exit 1

echo "PAYMENT PROCESSOR ID ${MOATS}"
echo "KEYFILE: $HOME/.zen/game/pending/${PAYOUTPUB}/"
echo "${PAYOUTPUB} : (${AMOUNT}) -> ${G1PUB}"
echo "COMMENT : ${COMMENT}"

[[ -z $COMMENT ]] && COMMENT="ZEN:${MOATS}"

PENDINGDIR=$HOME/.zen/game/pending/${PAYOUTPUB}
### PREPARE PENDINGFILE INFO ZONE
mkdir -p ${PENDINGDIR}
PENDINGFILE=${PENDINGDIR}/${MOATS}_${AMOUNT}+${G1PUB}.TX

rm -f ${PENDINGFILE} 2>/dev/null ## CLEAN START

## PREPARE CALLING MYSELF AGAIN COMMAND
cp ${KEYFILE} ${PENDINGDIR}/secret.key 2>/dev/null
echo '#!/bin/bash
bash '${ME}' "'${KEYFILE}'" "'${AMOUNT}'" "'${G1PUB}'" "'${COMMENT}'" "'${MOATS}'"
' > ${PENDINGDIR}/${MOATS}_replay.sh
chmod +x ${PENDINGDIR}/${MOATS}_replay.sh

rm -f ${PENDINGDIR}/${MOATS}.result

################################################
# MAKE PAYMENT
${MY_PATH}/jaklis/jaklis.py -k ${PENDINGDIR}/secret.key pay -a ${AMOUNT} -p ${G1PUB} -c "${COMMENT}" -m 2>&1> ${PENDINGDIR}/${MOATS}.result
CHK1=$(cat ${PENDINGDIR}/${MOATS}.result | head -n 1 )
CHK2=$(cat ${PENDINGDIR}/${MOATS}.result | head -n 2 )

echo ${CHK1}
echo ${CHK2}

if [[ $? == 0 || $(echo "${CHK2}" | grep 'succès')  || $(echo "${CHK1}" | grep 'conforme' ) ]]; then
    echo "TRANSACTION SENT"
    echo "SENT" > ${PENDINGFILE} ## TODO : MONITOR POTENTIAL CHAIN REJECTION (FORK/MERGE WINDOW)

    ## CHANGE COINS CACHE
    COINSFILE="$HOME/.zen/tmp/coucou/${PAYOUTPUB}.COINS"
    DESTFILE="$HOME/.zen/tmp/coucou/${G1PUB}.COINS"

    ## DECREASE SOURCE IN "coucou" CACHE
    echo "$COINS - $AMOUNT" | bc > ${COINSFILE}

    DES=$(cat ${DESTFILE})
    [[ ${DES} != "" && ${DES} != "null" ]] \
        && echo "$DES + $AMOUNT" | bc  > ${DESTFILE} \
        || echo "${AMOUNT}" > ${DESTFILE}

    ## INFORM ABOUT PAYMENT
    ZENAMOUNT=$(echo "$AMOUNT * 10" | bc | cut -d '.' -f 1)
    ZENCUR=$(echo "$COINS * 10" | bc | cut -d '.' -f 1)
    ZENDES=$(echo "$DES * 10" | bc | cut -d '.' -f 1)

    echo "<html><h1>ẐEN OPERATION</h1>
    <h3>${PAYOUTPUB}
    <br> ${ZENCUR} - ${ZENAMOUNT} </h3>
    <h3>${G1PUB}
    <br> ${ZENDES} + ${ZENAMOUNT} </h3>
    <h2>OK</h2></html>" > ${PENDINGDIR}/${MOATS}.result

    $MY_PATH/mailjet.sh "support@qo-op.com" ${PENDINGDIR}/${MOATS}.result "${ZENAMOUNT} ZEN OPERATION"

    ## REMOVE IF YOU WANT TO MONITOR "SENT" WINDOW INCERTITUDE
    rm ${PENDINGDIR}/${MOATS}_replay.sh
    mv ${PENDINGFILE} ${PENDINGFILE}.DONE

else

    echo "TRANSACTION ERROR"

    ## INFORM SYSTEM MUST RENEW OPERATION
    rm ${PENDINGFILE}
    echo "<html><h2>BLOCKCHAIN CONNEXION ERROR</h2>
    <h1>-  MUST RETRY -</h1>
    LAUNCHING SUB SHELL</html>" >> ${PENDINGDIR}/${MOATS}.result

    ## COUNT NUMBER OF TRY
    try=$(cat ${PENDINGDIR}/${MOATS}.try 2>/dev/null) || try=0

    [ $try -gt 2 ] \
    && echo "${MOATS} TOO MANY TRY ( $try )" >> ${PENDINGDIR}/${MOATS}.result \
    && $MY_PATH/mailjet.sh "support@qo-op.com" ${PENDINGDIR}/${MOATS}.result "PAYMENT CANCELED" \
    && exit 1 \
    || $MY_PATH/mailjet.sh "support@qo-op.com" ${PENDINGDIR}/${MOATS}.result "PAYMENT REPLAY"

   (
    ((try++)) && echo $try > ${PENDINGDIR}/${MOATS}.try
    chmod +x  ${PENDINGDIR}/${MOATS}_replay.sh
    sleep 3600
    ${PENDINGDIR}/${MOATS}_replay.sh
    exit 0
   ) &


fi

exit 0
