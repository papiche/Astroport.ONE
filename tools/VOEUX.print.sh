#!/bin/bash
########################################################################
# Version: 0.3
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "$MY_PATH/my.sh"

PLAYER=$1
VoeuName=$2
MOATS=$3
G1PUB=$4

UPASS=$(date '+%Y%m') # YYYYMM

[[ ${PLAYER} == "" ]] && PLAYER=$(cat ~/.zen/game/players/.current/.player 2>/dev/null)
[[ ${PLAYER} == "" ]] && echo "PLAYER manquant" && exit 1

[[ ${G1PUB} == "" ]] && G1PUB=$(cat ~/.zen/game/players/${PLAYER}/.g1pub 2>/dev/null)
[[ ${G1PUB} == "" ]] && echo "G1PUB manquant" && exit 1

############################################################ G1Voeu.sh use
############################################################ PRINT G1Milgram (once a month)
    if [[ ${G1PUB} != "" && ${VoeuName} != "" && -d ~/.zen/tmp/${MOATS} ]]; then

    #################################################################
    ## MAKING SPECIAL amrzqr => G1Milgram TICKET = G1Missive
    ## LE QRCODE CORRESPOND A LA CLEF DERIVE "${PLAYER} ${G1PUB} :: G1${VoeuName}" avec PASS=YYYYMM
    SECRET1="${PLAYER} ${G1PUB}"
    SECRET2="G1${VoeuName}"

    ${MY_PATH}/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/${VoeuName}.ipfskey "${SECRET1}" "${SECRET2}"

    USALT=$(echo "${SECRET1}" | jq -Rr @uri)
    UPEPPER=$(echo "${SECRET2}" | jq -Rr @uri)
    DISCO="/?salt=${USALT}&pepper=${UPEPPER}"
    echo "${DISCO}"  > ~/.zen/tmp/${MOATS}/topgp
    rm -f ~/.zen/tmp/${MOATS}/gpg.asc
    cat ~/.zen/tmp/${MOATS}/topgp | gpg --symmetric --armor --batch --passphrase "$UPASS" -o ~/.zen/tmp/${MOATS}/gpg.asc

    cp ${MY_PATH}/../images/g1magicien.png ~/.zen/tmp/${MOATS}/result.png

    ## MAKE amzqr WITH @@@@@ PGP G1PASS FORMAT (%40)
    amzqr "$(cat ~/.zen/tmp/${MOATS}/gpg.asc  | tr '-' '@' | tr '\n' '-'  | tr '+' '_' | jq -Rr @uri )" \
                -d "$HOME/.zen/tmp/${MOATS}" \
                -l H \
               -p ~/.zen/tmp/${MOATS}/result.png -c

    convert -gravity northwest -pointsize 25 -fill black -draw "text 5,5 \"${PLAYER} - ${UPASS} -\"" ~/.zen/tmp/${MOATS}/result_qrcode.png ~/.zen/tmp/${MOATS}/layer1.png
    convert -gravity southeast -pointsize 25 -fill black -draw "text 5,5 \"${VoeuName}\"" ~/.zen/tmp/${MOATS}/layer1.png ~/.zen/tmp/${MOATS}/START.png

    IMAGIC=$(ipfs add -Hq ~/.zen/tmp/${MOATS}/START.png | tail -n 1)
    echo ${IMAGIC}

    ## SENDING EMAIL #############
    echo "(•‿‿•) SCAN https://astroport.com/scan" > ~/.zen/tmp/${MOATS}/intro.txt
    mpack -a -s "(•‿‿•) : Missive ${VoeuName} - ${UPASS} - La♥Box" -d ~/.zen/tmp/${MOATS}/intro.txt ~/.zen/tmp/${MOATS}/START.png ${PLAYER} &

    exit 0

    fi
############################################################
############################################################

## COMMAND LINE MODE
echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
[[ ! ${MOATS} ]] && MOATS=$(date -u +"%Y%m%d%H%M%S%4N") && mkdir -p ~/.zen/tmp/${MOATS}
###############################
## EXTRACT G1Voeu from PLAYER TW
echo "Exporting ${PLAYER} TW [tag[G1Voeu]]"
rm -f ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu/${PLAYER}.g1voeu.json
tiddlywiki --load ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html --output ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu --render '.' "${PLAYER}.g1voeu.json" 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[tag[G1Voeu]]'

[[ ! -s ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu/${PLAYER}.g1voeu.json ]] && echo "AUCUN G1VOEU - EXIT -" && exit 1

cat ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu/${PLAYER}.g1voeu.json | jq -r '.[].wish' > ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu/${PLAYER}.g1wishes.txt
echo "VOEUX : ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu/${PLAYER}.g1wishes.txt "$(cat ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu/${PLAYER}.g1wishes.txt | wc -l)

echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"

vlist=""
for v in $(cat ~/.zen/game/players/${PLAYER}/voeux/*/*/.title); do
    g1pub=$(grep -r $v ~/.zen/game/players/${PLAYER}/voeux/ 2>/dev/null | head -n 1 | rev | cut -d '/' -f 2 | rev )
    #~ echo "$v : $g1pub"
    #~ echo '------------------------------------------------------------------'
    vlist=($v:$g1pub ${vlist[@]})
done

#~ echo "${vlist[@]}"

PS3='Choisissez le voeux ___ '

select zwish in "${vlist[@]}"; do
    case ${zwish} in
    "QUITTER")
        exit 0
    ;;

    *) echo "IMPRESSION ${voeu}"

        VoeuName=$(echo ${zwish} | cut -d ':' -f1) ## Get VoeuName
        voeu=$(echo ${zwish} | cut -d ':' -f2) ## Get G1PUB part

        VOEUXNS=$(ipfs key list -l | grep -w ${voeu} | cut -d ' ' -f1)

        choices=("TW" "Ğ1" "Ğ1Milgram")
        PS3='Imprimer le QR (TW DApp) ou de son portefeuille (Ğ1) ?'
        select typ in "${choices[@]}"; do

            case $typ in
            "TW")
                echo "Changer de Gateway $myIPFS ?"
                read GW && [[ ! $GW ]] && GW="$myIPFS"
                qrencode -s 12 -o "$HOME/.zen/game/world/${VoeuName}/${voeu}/QR.WISHLINK.png" "$GW/ipns/$VOEUXNS"
                convert $HOME/.zen/game/world/${VoeuName}/${voeu}/QR.WISHLINK.png -resize 600 ~/.zen/tmp/${MOATS}/START.png
                echo " QR code ${VoeuName}  : $GW/ipns/$VOEUXNS"
                break
            ;;

            "Ğ1")
                qrencode -s 12 -o "$HOME/.zen/game/world/${VoeuName}/${voeu}/G1PUB.png" "${voeu}"
                convert $HOME/.zen/game/world/${VoeuName}/${voeu}/G1PUB.png -resize 600 ~/.zen/tmp/${MOATS}/START.png
                break
            ;;

            "Ğ1Milgram")

                GW="(•‿‿•) SCAN https://astroport.com/scan"
                # CREATE G1Milgram
                IMAGIC=$(${MY_PATH}/VOEUX.print.sh "${PLAYER}" "${VoeuName}" "${MOATS}" | tail -n 1)

                ## EXTRACT TEXT FROM TIDDLER
                tiddlywiki --load ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html --output ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu \
                                    --render '.' "${PLAYER}.${VoeuName}.json" 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' "${VoeuName}"

                # cat ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu/${PLAYER}.${VoeuName}.json | jq -r '.[].text' | html2text > ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu/index.txt
                ## COULD USE TEXT FROM TIDDLER (TODO)
                echo "SVP. Passez le message un ami de confiance." > ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu/index.txt
                MILGRAM=$(ipfs add -q ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu/index.txt)

                xdg-open http://ipfs.localhost:8080/ipfs/${IMAGIC}

                # ${VoeuName} key
                IK=$(ipfs key list -l | grep -w "${PLAYER}_${VoeuName}" | cut -d ' ' -f 1 )
                [[ $IK ]] && ipfs key rm ${PLAYER}_${VoeuName}
                ipfs key import ${PLAYER}_${VoeuName} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/${VoeuName}.ipfskey
                IK=$(ipfs key list -l | grep -w "${PLAYER}_${VoeuName}" | cut -d ' ' -f 1 )

                xdg-open http://ipfs.localhost:8080/ipfs/${MILGRAM}

                (
                    ipfs name publish -k ${PLAYER}_${VoeuName} /ipfs/${MILGRAM}
                    echo "${VoeuName} ${UPASS} G1Milgram emitted ${PLAYER}"
                    xdg-open http://ipfs.localhost:8080/ipns/${IK}
                ) &

                break
            ;;

            "")
                echo "Mauvais choix."
            ;;

            esac
        done

        convert -gravity northeast -pointsize 30 -fill black -draw "text 50,2 \"${VoeuName} ($typ)\"" ~/.zen/tmp/${MOATS}/START.png ~/.zen/tmp/${MOATS}/g1voeu1.png
        convert -gravity southeast -pointsize 30 -fill black -draw "text 100,2 \"${GW}\"" ~/.zen/tmp/${MOATS}/g1voeu1.png ~/.zen/tmp/${MOATS}/g1voeu.png

        #~ echo "~/.zen/tmp/${MOATS}/g1voeu.png READY ?"
        [[ $XDG_SESSION_TYPE == 'x11' ]] && xdg-open ~/.zen/tmp/${MOATS}/g1voeu.png

        LP=$(ls /dev/usb/lp* 2>/dev/null | head -n1)
        [[ ! $LP ]] && echo "NO PRINTER FOUND - Brother QL700 validated" && continue

        echo "IMPRESSION LIEN TW VOEU"
        brother_ql_create --model QL-700 --label-size 62 ~/.zen/tmp/${MOATS}/g1voeu.png > ~/.zen/tmp/${MOATS}/toprint.bin 2>/dev/null
        sudo brother_ql_print ~/.zen/tmp/${MOATS}/toprint.bin $LP

        ;;
    esac
done

## DEV MODE : AUDIT CODE & ACTIVATE REMOVE FOR SECURITY (OR USE encrypted RAM DISK for ~/.zen/tmp )
# rm -Rf ~/.zen/tmp/${MOATS}
