#shellcheck shell=sh disable=SC2034

Base32Normalize() {
    awk '{printf $0}' | basenc --base32 | Normalize
}

Normalize() {
    awk '{print tolower($1)}' | sed 's/\(_\|+\)/./g; s/=//g;'
}

Revert() {
    awk -F. '{for (i=NF; i>1; i--) printf("%s.",$i); print $1;}'
}

isLan() {
    local isLan=$(ip route | awk '$1 == "default" {print $3}' | grep -E "/(^127\.)|(^192\.168\.)|(^10\.)|(^172\.1[6-9]\.)|(^172\.2[0-9]\.)|(^172\.3[0-1]\.)|(^::1$)|(^[fF][cCdD])/" \
               || route -n |awk '$1 == "0.0.0.0" {print $2}' | grep -E "/(^127\.)|(^192\.168\.)|(^10\.)|(^172\.1[6-9]\.)|(^172\.2[0-9]\.)|(^172\.3[0-1]\.)|(^::1$)|(^[fF][cCdD])/" \
               || true)

    #~ local myZip=$(zIp)
    #~ [ -n "$myZip" ] && echo "$myZip" && exit 0

    # [ -n "$isLan" ] && echo "$isLan" || true
} 2>/dev/null

isPlayerLegal() {
    local isPlayerLegal=$(cat "$(myPlayerPath)"/.legal 2>/dev/null || true)
    [ -n "$isPlayerLegal" ] && echo "$isPlayerLegal" || true
}

myAstroFeedKey() {
    local myAstroFeedKey=$(ipfs --api "$(myIpfsApi)" key list -l | awk '$2 == "'"$(myPlayerFeed)"'" {print $1}')
    [ -n "$myAstroFeedKey" ] && echo "$myAstroFeedKey"
}

myAstroFeedKeyFile() {
    local myAstroFeedKeyFile="$(myIpfsKeyStore)/key_$(myPlayerFeed | Base32Normalize)"
    [ -f "$myAstroFeedKeyFile" ] && echo "$myAstroFeedKeyFile"
}

myAstroKey() {
    local myAstroKey=$(ipfs --api "$(myIpfsApi)" key list -l | awk '$2 == "'"$(myPlayer)"'" {print $1}')
    [ -n "$myAstroKey" ] && echo "$myAstroKey"
}

myAstroKeyFile() {
    local myAstroKeyFile="$(myIpfsKeyStore)/key_$(myPlayer | Base32Normalize)"
    [ -f "$myAstroKeyFile" ] && echo "$myAstroKeyFile"
}

myAstroPath() {
    local myAstroPath=$(cd ~/.zen/Astroport.ONE/ && pwd -P)
    [ -n "$myAstroPath" ] && echo "$myAstroPath"
}

#~ myAstroPlayersPage() {
    #~ local myAstroPlayersPage=$(cat ~/.zen/tmp/myAstroPlayersPage)
    #~ if [[ ! "$myAstroPlayersPage" ]]; then
        #~ counter=1
        #~ for tw in ls ~/.zen/game/players/*/ipfs/moa/index.html; do
            #~ tiddlywiki --load $tw --output ~/.zen/tmp --render '.' "${counter}ZenCard.json" 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'ZenCard'

            #~ ((counter++))
        #~ done
    #~ echo "$myAstroPlayersPage"
#~ }

myDate() {
    local myDate=$(date -u +"%Y%m%d%H%M%S%4N")
    [ -n "$myDate" ] && echo "$myDate"
}

myDomainName() {
    local myDomainName=$(domainname 2>/dev/null) && [ "$myDomainName" = "(none)" ] && myDomainName=$(hostname -d 2>/dev/null) && [ -z "$myDomainName" ] && myDomainName="localhost"
    [ -n "$myDomainName" ] && echo "$myDomainName"
}

myHttp() {
    [ -n "$(myHttpHeader)" ] \
     && local myHttp="$(myHttpHeader)

"    || local myHttp=""
    [ -n "$(myHttpContent)" ] && myHttp="${myHttp}$(myHttpContent)"
    [ -n "$myHttp" ] && echo "$myHttp"
}

myHttpContent() {
    [ -n "$(myIpfsHash)" ] \
     && local myHttpContent="<html><head><title>302 Found</title></head><body><h1>Found</h1>
<p>The document is <a href=\"ipfs/$(myIpfsHash)\">here</a> in IPFS.</p></body></html>" \
     && echo "$myHttpContent"
}

myHttpHeader() {
    [ -n "$(myIpfsHash)" ] \
     && local myHttpHeader="HTTP/1.0 302 Found
Content-Type: text/html; charset=UTF-8
Content-Length: $(myHttpContent |wc -c)
Date: $(date -R)
Location: ipfs/$(myIpfsHash)
Server: and" \
     && [ -n "$(myIpfsKey)" ] && myHttpHeader="${myHttpHeader}
set-cookie: AND=$(myIpfsKey); expires=$(date -R -d "+1 month"); path=/; domain=.$(myDomainName); Secure; SameSite=lax"
    [ -n "$myHttpHeader" ] && echo "$myHttpHeader"
}

myHome() {
    local myHome=$(cd ~ && pwd -P)
    [ -n "$myHome" ] && echo "$myHome"
}

myHostName() {
    local myHostName=$(hostname |sed 's/\.'"$(myDomainName)"'$//')
    [ -n "$(myDomainName)" ] && myHostName="${myHostName}.$(myDomainName)"
    [ -n "$myHostName" ] && echo "$myHostName"
}

myHName() {
    local myHName=$(hostname -s)
    [ -n "$myHName" ] && echo "$myHName"
}

zIp() {
    zipit=$(cat ~/.zen/♥Box 2>/dev/null | head -n 1 )
    [ -n "$zipit" ] && echo "$zipit" || false
}

UPlanetSharedSecret() {
    UPlanetSharedSecret=$(cat ~/.zen/UPlanetSharedSecret 2>/dev/null | head -n 1 )
    [ -n "$UPlanetSharedSecret" ] && echo "$UPlanetSharedSecret" || false
}

myIp() {
    local myIp=$(hostname -I | awk '{print $1}' | head -n 1)
    local myZip=$(zIp)
    [ -n "$myZip" ] && echo "$myZip" && exit 0
    [ -n "$myIp" ] && echo "$myIp" || echo "127.0.0.1"
}

myIpfs() {
    [ -n "$(myIpfsHash)" ] \
     && local myIpfs="${myIPFSGW}/ipfs/$(myIpfsHash)" \
     && echo "$myIpfs"
}

myIpfsApi() {
    ipfs --timeout 10s --api "$(cat "$(myHome)"/.ipfs/api)" swarm peers >/dev/null 2>&1 \
     && local myIpfsApi=$(cat "$(myHome)"/.ipfs/api)
    [ -n "$myIpfsApi" ] && echo "$myIpfsApi"
}

myIpfsApiGw() {
    [ -n "$isLAN" ] \
     && local myIpfsApiGw="http://ipfs.localhost:5001" \
     || local myIpfsApiGw="https://ipfs.$(myHostName)/api"
    [ -n "$myIpfsApiGw" ] && echo "$myIpfsApiGw"
}

myIpfsBootstrapNode() {
    [ -n "$(myIpfsBootstrapNodes)" ] \
     && local myIpfsBootstrapNode=$(myIpfsBootstrapNodes | shuf | head -1)
    [ -n "$myIpfsBootstrapNode" ] && echo "$myIpfsBootstrapNode"
}

myIpfsBootstrapNodes() {
    [ -f "$(myAstroPath)/A_boostrap_nodes.txt" ] \
     && local myIpfsBootstrapNodes=$(awk -F/ '$6 != "" {print}' "$(myAstroPath)/A_boostrap_nodes.txt")
    [ -n "$myIpfsBootstrapNodes" ] && echo "$myIpfsBootstrapNodes"
}

myIpfsGw() {
    [ -f "$(myAstroPath)/A_boostrap_nodes.txt" ] \
     && local myIpfsGw=$(head -n2 "$(myAstroPath)/A_boostrap_nodes.txt" | tail -n 1 | cut -d ' ' -f 2)
    [ -n "$myIpfsGw" ] && echo "$myIpfsGw"
}

myIpfsHash() {
    [ -f "$(myPath)"/localhost/latest ] \
     && local myIpfsHash=$(cat "$(myPath)"/localhost/latest) \
     || local myIpfsHash=$(myHtml |ipfs add -q)
    [ ! -f "$(myPath)"/localhost/latest ] \
     && echo "$myIpfsHash" > "$(myPath)"/localhost/latest
    [ -n "$myIpfsHash" ] && echo "$myIpfsHash"
}

myIpfsKey() {
    local myIpfsKey=$(ipfs --api "$(myIpfsApi)" key list -l | awk '$2 == "self" {print $1}')
    [ -n "$myIpfsKey" ] && echo "$myIpfsKey"
}

myIpfsKeyStore() {
    local myIpfsKeyStore=$(cd "$(myHome)"/.ipfs/keystore && pwd -P)
    [ -n "$myIpfsKeyStore" ] && echo "$myIpfsKeyStore"
}

myIpfsPeerId() {
    local myIpfsPeerId=$(jq -r .Identity.PeerID "$(myHome)"/.ipfs/config)
    [ -n "$myIpfsPeerId" ] && echo "$myIpfsPeerId"
}

myIpns() {
    [ -n "$(myIpfsKey)" ] \
     && local myIpns="${myIPFS}/ipns/$(myIpfsKey)" \
     && echo "$myIpns"
}

myPath() {
    local myPath=$(cd ~/.zen/game/players/ && pwd -P)
    [ -n "$myPath" ] && echo "$myPath"
}

myPlayer() {
    local myPlayer=$(cat "$(myPath)"/.current/.player 2>/dev/null)
    [ -n "$myPlayer" ] && echo "$myPlayer"
}

myPlayerApi() {
    ipfs --api "$(cat "$(myPlayerPath)"/.ipfs/api )" swarm peers >/dev/null 2>&1 \
     && local myPlayerApi=$(cat "$(myPlayerPath)"/.ipfs/api)
    [ -n "$myPlayerApi" ] && echo "$myPlayerApi"
}

myPlayerApiGw() {
    [ -n "$(myReyalp)" ] \
     && { [ -n "$isLAN" ] \
       && local myPlayerApiGw="http://ipfs.$(myHostName):5001" \
       || local myPlayerApiGw="https://ipfs.$(myReyalp).$(myHostName)/api" \
     ;}
    [ -n "$myPlayerApiGw" ] && echo "$myPlayerApiGw"
}

myPlayerDomain() {
    echo "$(myPlayer)" | grep "@" >/dev/null \
     && local myPlayerDomain=$(echo "$(myPlayer)" | awk -F "@" '{print $2}' | Normalize)
    [ -n "$myPlayerDomain" ] && echo "$myPlayerDomain"
}

myPlayerFeed() {
    [ -n "$(myPlayer)" ] \
     && local myPlayerFeed="$(myPlayer)_feed"
    [ -n "$myPlayerFeed" ] && echo "$myPlayerFeed"
}

myPlayerFeedKey() {
    local myPlayerFeedKey=$(ipfs --api "$(myPlayerApi)" key list -l | awk '$2 == "'"$(myPlayerFeed)"'" {print $1}')
    [ -n "$myPlayerFeedKey" ] && echo "$myPlayerFeedKey"
}

myPlayerFeedKeyFile() {
    local myPlayerFeedKeyFile="$(myIpfsKeyStore)/key_$(myPlayerFeed | Base32Normalize)"
    [ -f "$myPlayerFeedKeyFile" ] && echo "$myPlayerFeedKeyFile"
}

myPlayerG1Pub() {
    local myPlayerG1Pub=$(cat "$(myPlayerPath)"/.g1pub 2>/dev/null)
    [ -n "$myPlayerG1Pub" ] && echo "$myPlayerG1Pub"
}

myPlayerHome() {
    echo "$(myPlayer)" | grep "@" >/dev/null \
     && local myPlayerHome=$(cd "$(dirname "$(myHome)")/$(myPlayer)" && pwd -P)
    [ -n "$myPlayerHome" ] && echo "$myPlayerHome"
}

myPlayerHost() {
    [ -n "$(myReyalp)" ] \
     && { [ -n "$isLAN" ] \
       && local myPlayerHost="$(myHostName)" \
       || local myPlayerHost="$(myReyalp).$(myHostName)" \
     ;}
    [ -n "$myPlayerHost" ] && echo "$myPlayerHost"
}

myPlayerKey() {
    local myPlayerKey=$(ipfs --api "$(myPlayerApi)" key list -l | awk '$2 == "'"$(myPlayer)"'" {print $1}')
    [ -n "$myPlayerKey" ] && echo "$myPlayerKey"
}

myPlayerKeyFile() {
    local myPlayerKeyFile="$(myPlayerKeyStore)/key_$(myPlayer | Base32Normalize)"
    [ -f "$myPlayerKeyFile" ] && echo "$myPlayerKeyFile"
}

myPlayerKeyStore() {
    local myPlayerKeyStore=$(cd "$(myPlayerPath)"/.ipfs/keystore && pwd -P)
    [ -n "$myPlayerKeyStore" ] && echo "$myPlayerKeyStore"
}

myPlayerNs() {
    local myPlayerNs=$(cat "$(myPlayerPath)"/.playerns 2>/dev/null)
    [ -n "$myPlayerNs" ] && echo "$myPlayerNs"
}

myPlayerPath() {
    [ -n "$(myPlayer)" ] \
     && local myPlayerPath=$(cd "$(myPath)"/"$(myPlayer)" && pwd -P)
    [ -n "$myPlayerPath" ] && echo "$myPlayerPath"
}

myPlayerPseudo() {
    local myPlayerPseudo=$(cat "$(myPlayerPath)"/.pseudo 2>/dev/null)
    [ -n "$myPlayerPseudo" ] && echo "$myPseudo"
}

myPlayerUser() {
    echo "$(myPlayer)" | grep "@" >/dev/null \
     && local myPlayerUser=$(echo "$(myPlayer)" | awk -F "@" '{print $1}' | Normalize)
    [ -n "$myPlayerUser" ] && echo "$myPlayerUser"
}

myPlayerUserDomain() {
    [ -n "$(myPlayerDomain)" ] \
     && local myPlayerUserDomain="$(myPlayerUser).$(myPlayerDomain)" \
     && echo "$myPlayerUserDomain"
}

myReyalp() {
    [ -n "$(myPlayerDomain)" ] \
     && local myReyalp="$(myPlayerUser).$(myPlayerDomain)" \
     && echo "$myReyalp" \
     || echo "$(myPlayer)"
}

myReyalpHome() {
    [ -n "$(myReyalpResuPath)" ] \
     && local myReyalpHome=$(cd "$(case ${RESU_HOME:-mail} in \
       dns) echo /dns/$(myReyalpResuPath) ;; \
       *) echo /home/$(myReyalpMail) ;; \
     esac)" && pwd -P)
    [ -n "$myReyalpHome" ] && echo "$myReyalpHome"
}

myReyalpMail() {
    [ -n "$(myPlayerDomain)" ] \
     && local myReyalpMail=$(echo "$(myPlayer)" | Normalize)
    [ -n "$myReyalpMail" ] && echo "$myReyalpMail"
}

myReyalpNiamod() {
    [ -n "$(myPlayerDomain)" ] \
     && local myReyalpNiamod=$(echo "$(myPlayerDomain)" | Revert)
    [ -n "$myReyalpNiamod" ] && echo "$myReyalpNiamod"
}

myReyalpResu() {
    [ -n "$(myPlayerUser)" ] \
     && local myReyalpResu=$(echo "$(myPlayerUser)" | Revert)
    [ -n "$myReyalpResu" ] && echo "$myReyalpResu"
}

myReyalpResuNiamod() {
    [ -n "$(myReyalpNiamod)" ] \
     && local myReyalpResuNiamod="$(myReyalpNiamod).$(myReyalpResu)" \
     && echo "$myReyalpResuNiamod"
}

myReyalpResuPath() {
    [ -n "$(myReyalpResuNiamod)" ] \
     && local myReyalpResuPath=$(echo "$(myReyalpResuNiamod)" | sed 's/\./\//g';)
    [ -n "$myReyalpResuPath" ] && echo "$myReyalpResuPath"
}

myHtml() {
    local myHtml=$($RUN sed \
        -e "s~http://127.0.0.1:8080~${myIPFS}~g" \
        -e "s~\"http://127.0.0.1:1234\"~\"${myASTROPORT}\"~g" \
        -e "s~http://127.0.0.1:33101~http://${myHOST}:33101~g" \
        -e "s~https://ipfs.copylaradio.com~${myIPFSGW}~g" \
        -e "s~http://g1billet.localhost:33101~${myG1BILLET}~g" \
        -e "s~_IPFSNODEID_~${IPFSNODEID}~g" \
        -e "s~g1billet.localhost~${myIP}~g" \
        -e "s~_HOSTNAME_~$(hostname)~g" \
        -e "s~background.000.~background.$(printf '%03d' "$(seq 0 17 |shuf -n 1)").~g" \
      ~/.zen/Astroport.ONE/templates/register.html)
    [ -z "$isLAN" ] \
     || myHtml=$($RUN echo "$myHtml" | sed \
      -e "s~<input type='"'hidden'"' name='"'salt'"' value='"'0'"'>~<input name='"'salt'"' value='"''"'>~g" \
      -e "s~<input type='"'hidden'"' name='"'pepper'"' value='"'0'"'>~<input name='"'pepper'"' value='"''"'>~g")
    [ -n "$myHtml" ] && echo "$myHtml"
}

mySalt() {
    local mySalt=$($RUN sed \
        -e "s~http://127.0.0.1:8080~${myIPFS}~g" \
        -e "s~\"http://127.0.0.1:1234\"~\"${myASTROPORT}\"~g" \
        -e "s~http://127.0.1.1:1234~${myASTROPORT}~g" \
        -e "s~http://127.0.0.1:33101~http://${myHOST}:33101~g" \
        -e "s~https://ipfs.copylaradio.com~${myIPFSGW}~g" \
        -e "s~http://g1billet.localhost:33101~${myG1BILLET}~g" \
        -e "s~_IPFSNODEID_~${IPFSNODEID}~g" \
        -e "s~g1billet.localhost~${myIP}~g" \
        -e "s~_HOSTNAME_~$(hostname)~g" \
        -e "s~background.000.~background.$(printf '%03d' "$(seq 0 17 |shuf -n 1)").~g" \
      ~/.zen/Astroport.ONE/templates/saltpepper.http)
    [ -z "$isLAN" ] \
     || mySalt=$($RUN echo "$mySalt" | sed \
      -e "s~<input type='"'hidden'"' name='"'salt'"' value='"'0'"'>~<input name='"'salt'"' value='"''"'>~g" \
      -e "s~<input type='"'hidden'"' name='"'pepper'"' value='"'0'"'>~<input name='"'pepper'"' value='"''"'>~g")
    [ -n "$mySalt" ] && echo "$mySalt"
}


myTs() {
    local myTs=$(date +%s)
    [ -n "$myTs" ] && echo "$myTs"
}

myTube() {
    [ -f "$(myAstroPath)/A_boostrap_nodes.txt" ] \
     && local myTube=$(head -n2 "$(myAstroPath)/A_boostrap_nodes.txt" | tail -n 1 | cut -d ' ' -f 3)
    [ -n "$myTube" ] && echo "$myTube"
}

myAstroTube() {
    [ -f "$(myAstroPath)/A_boostrap_nodes.txt" ] \
     && local myAstroTube=$(head -n2 "$(myAstroPath)/A_boostrap_nodes.txt" | tail -n 1 | cut -d ' ' -f 3 | sed "s~ipfs~astroport~g")
    [ -n "$myAstroTube" ] && echo "$myAstroTube"
}

function makecoord() {
    local input="$1"

    if [[ ${input} =~ ^-?[0-9]+\.[0-9]$ ]]; then
        input="${input}0"
    elif [[ ${input} =~ ^-?[0-9]+$ ]]; then
        input="${input}.00"
    fi
    echo "${input}"
}

# Fonction pour récupérer la météo depuis l'API OpenWeatherMap
recuperer_meteo() {
    echo "En train de récupérer les données météo..."
    # Récupérer la météo à l'aide de l'API OpenWeatherMap
    ville="Paris" # Vous pouvez modifier la ville ici
    api_key="310103dee4a9d1b716ee27d79f162c7e" # Remplacez YOUR_API_KEY par votre clé API OpenWeatherMap
    url="http://api.openweathermap.org/data/2.5/weather?q=$ville&appid=$api_key&units=metric"
    meteo=$(curl -s $url)
    # Extraire les informations pertinentes de la réponse JSON
    temperature=$(echo $meteo | jq -r '.main.temp')
    description=$(echo $meteo | jq -r '.weather[0].description')
    echo "La météo à $ville : $description, Température: $temperature °C"
}

# my_IPCity # Fonction pour récupérer la géolocalisation à partir de l'adresse IP
my_IPCity() {
    local ip=$1

    if [ -z "$ip" ]; then
        ip=$(curl 'https://api.ipify.org?format=json' --silent | jq -r '.ip')
    fi

    local url="http://ip-api.com/json/$ip"
    local geolocalisation=$(curl -s "$url")

    local ville=$(echo "$geolocalisation" | jq -r '.city')
    local pays=$(echo "$geolocalisation" | jq -r '.country')

    echo "$ville,$pays"
}

IPFSNODEID="$(myIpfsPeerId)"
[[ ! $MOATS ]] && MOATS="$(myDate)"
isLAN="$(isLan)"
myIP="$(myIp)" # "127.0.0.1"

## PATCH
myIP=$(hostname -I | awk '{print $1}' | head -n 1)
isLAN=$(echo $myIP | grep -E "/(^127\.)|(^192\.168\.)|(^10\.)|(^172\.1[6-9]\.)|(^172\.2[0-9]\.)|(^172\.3[0-1]\.)|(^::1$)|(^[fF][cCdD])/")

myDOMAIN="copylaradio.com"

myASTROPORTW="http://$(hostname).local:1234" #astroport.localhost
myASTROPORT="http://127.0.0.1:1234" # BE ACCESSIBLE THROUGH LAN
myAPI="http://127.0.0.1:5001"
myDATA="https://data.gchange.fr"
myGCHANGE="https://www.gchange.fr"
myCESIUM="https://g1.data.e-is.pro"
myG1BILLET="http://127.0.0.1:33101"
myHOST="$(myHostName)"

myIPFSW="http://$(hostname).local:8080" ## ipfs.localhost (IP works better in LAN deported desktop), but not in docker.
myIPFS="http://127.0.0.1:8080" ## ipfs.localhost (IP works better in LAN deported desktop), but not in docker.
myIPFSGW="$(myIpfsGw)"
myTUBE="$(myTube)"
myASTROTUBE="https://$(myAstroTube)"

## WAN STATION
[ -z "$isLAN" ] \
 && myASTROPORT="https://astroport.$(myDomainName)" \
 && myAPI="https://ipfs.$(myHostName)" \
 && myIPFS="https://ipfs.$(myDomainName)" \
 && myHOST="astroport.$(myHostName)" \
 && myG1BILLET="https://libra.${myDOMAIN}" \
 && myIPFSW="https://ipfs.${myDOMAIN}" \
 || true

## zIP :: PUT YOUR Internet Box IP IN ~/.zen/♥Box  ( Forward PORTS 8080 4001 5001 33101 33102 1234 12345 45780 to 45790 )
[ -n "$(zIp)" ] \
 && myASTROPORT="http://$(zIp):1234" \
 && myAPI="http://$(zIp):5001" \
 && myIPFS="http://$(zIp):8080" \
 && myHOST="$(zIp)" \
 && myG1BILLET="http://$(zIp):33101" \
 && myIP="$(zIp)" \
 && myIPFSGW="$(zIp):8080" \
 || true


###
if [[ $XDG_SESSION_TYPE == 'x11' || $XDG_SESSION_TYPE == 'wayland' ]]; then
# GET SCREEN DIMENSIONS
    screen=$(xdpyinfo | grep dimensions | sed -r 's/^[^0-9]*([0-9]+x[0-9]+).*$/\1/')
    width=$(echo $screen | cut -d 'x' -f 1)
    height=$(echo $screen | cut -d 'x' -f 2)
    large=$((width-300))
    haut=$((height-200))
###
fi

## https://git.p2p.legal/qo-op/OSM2IPFS
EARTHCID="/ipfs/QmQizK777pFChbR12aKf3GExRUQyoPTHeWQxYpqfUGj7ff"
FLIPPERCID="${EARTHCID}/coinflip" ### EASTER EGG

###########################
## VISIO ROOM APP
## https://github.com/steveseguin/vdo.ninja
VDONINJA="/ipfs/QmdGGAukDepUiH63YgnMsvb4BySNPqM2bLz81bx4rjqCJD"
###########################
## CESIUM APP
## https://cesium.app
CESIUMIPFS="/ipfs/QmXex8PTnQehx4dELrDYuZ2t5ag85crYCBxm3fcTjVWo2k"
HACKGIPFS="/ipfs/Qmemnmd9V4WQEQF1wjKomeBJSuvAoqFBS7Hoq4sBDxvV2F"

##########################
myUPLANET="${myIPFS}${EARTHCID}" ## UPLANET ENTRANCE
myLIBRA="https://ipfs.asycn.io" ## READ ONLY IPFS GATEWAY
##########################
## UPLANETNAME can be set ~/.zen/UPlanetSharedSecret
[ -n "$(UPlanetSharedSecret)" ] \
    && UPLANETNAME="$(UPlanetSharedSecret)" \
    || UPLANETNAME=""

## DETECT SWARM.KEY
## ACTIVATE SECONDARY PRIVATE IPFS SWARM

## DEV support@qo-op.com Unamed UPlanet World Keeper.
[[ ${UPLANETNAME} == "" ]] && WORLDG1PUB="2L8vaYixCf97DMT8SistvQFeBj7vb6RQL7tvwyiv1XVH"
## when UPlanetSharedSecret is set.
## All TW wallet are created with 1 G1 "primal transaction"
## making UPlanet blockchains secured.
########################################
TODATE=$(date -d "today 13:00" '+%Y-%m-%d')
YESTERDATE=$(date -d "yesterday 13:00" '+%Y-%m-%d')
DEMAINDATE=$(date -d "tomorrow 13:00" '+%Y-%m-%d')
