#shellcheck shell=sh disable=SC2034
function urldecode() { : "${*//+/ }"; echo -e "${_//%/\\x}"; }

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
    local myAstroPath=$(cd $HOME/.zen/Astroport.ONE/ && pwd -P)
    [ -n "$myAstroPath" ] && echo "$myAstroPath"
}

myDate() {
    local myDate=$(date -u +"%Y%m%d%H%M%S%4N")
    [ -n "$myDate" ] && echo "$myDate"
}

myDomainName() {
    local myDomainName=$(domainname 2>/dev/null) && [ "$myDomainName" = "(none)" ] && myDomainName=$(hostname -d 2>/dev/null) && [ -z "$myDomainName" ] && myDomainName="localhost"
    [ -n "$myDomainName" ] && echo "$myDomainName"
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
    zipit=$(cat $HOME/.zen/♥Box 2>/dev/null | head -n 1 )
    [ -n "$zipit" ] && echo "$zipit" || false
}

UPlanetSharedSecret() {
    UPlanetSharedSecret=$(cat $HOME/.ipfs/swarm.key 2>/dev/null | tail -n 1 )
    [ -n "$UPlanetSharedSecret" ] && echo "$UPlanetSharedSecret" || false
}

myIp() {
    local myIp=$(hostname -I | awk '{print $1}' | head -n 1)
    local myZip=$(zIp)
    [ -n "$myZip" ] && echo "$myZip" || {
    [ -n "$myIp" ] && echo "$myIp" || echo "127.0.0.1"
    }
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
    [ -f "$(myAstroPath)/../game/MY_boostrap_nodes.txt" ] \
     && local myIpfsBootstrapNodes=$(awk -F/ '$6 != "" {print}' "$(myAstroPath)/../game/MY_boostrap_nodes.txt")
    [ -n "$myIpfsBootstrapNodes" ] && echo "$myIpfsBootstrapNodes"
}

myIpfsGw() {
    [ -f "$(myAstroPath)/A_boostrap_nodes.txt" ] \
     && local myIpfsGw=$(head -n2 "$(myAstroPath)/A_boostrap_nodes.txt" | tail -n 1 | xargs | cut -d ' ' -f 2)
    [ -f "$(myAstroPath)/../game/MY_boostrap_nodes.txt" ] \
     && local myIpfsGw=$(head -n2 "$(myAstroPath)/../game/MY_boostrap_nodes.txt" | tail -n 1 | xargs | cut -d ' ' -f 2)
    [ -n "$myIpfsGw" ] && echo "$myIpfsGw"
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
    local config="$(myHome)/.ipfs/config"
    [ ! -f "$config" ] && return 0
    local myIpfsPeerId=$(jq -r .Identity.PeerID "$config" 2>/dev/null)
    [ -n "$myIpfsPeerId" ] && [ "$myIpfsPeerId" != "null" ] && echo "$myIpfsPeerId"
}

myIpns() {
    [ -n "$(myIpfsKey)" ] \
     && local myIpns="${myIPFS}/ipns/$(myIpfsKey)" \
     && echo "$myIpns"
}

myPath() {
    local myPath=$(cd $HOME/.zen/game/players/ && pwd -P)
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

myTs() {
    local myTs=$(date +%s)
    [ -n "$myTs" ] && echo "$myTs"
}

myTube() {
    [ -f "$(myAstroPath)/A_boostrap_nodes.txt" ] \
     && local myTube=$(head -n2 "$(myAstroPath)/A_boostrap_nodes.txt" | tail -n 1 | xargs | cut -d ' ' -f 3)
    [ -f "$(myAstroPath)/../game/MY_boostrap_nodes.txt" ] \
     && local myTube=$(head -n2 "$(myAstroPath)/../game/MY_boostrap_nodes.txt" | tail -n 1 | xargs | cut -d ' ' -f 3)
    [ -n "$myTube" ] && echo "$myTube"
}

myAstroTube() {
    [ -f "$(myAstroPath)/A_boostrap_nodes.txt" ] \
     && local myAstroTube=$(head -n2 "$(myAstroPath)/A_boostrap_nodes.txt" | tail -n 1 | xargs | cut -d ' ' -f 3 | sed "s~ipfs~astroport~g")
    [ -f "$(myAstroPath)/../game/MY_boostrap_nodes.txt" ] \
     && local myAstroTube=$(head -n2 "$(myAstroPath)/../game/MY_boostrap_nodes.txt" | tail -n 1 | xargs | cut -d ' ' -f 3 | sed "s~ipfs~astroport~g")
    [ -n "$myAstroTube" ] && echo "$myAstroTube"
}

function makecoord() {
    local input="$1"

    # Vérifie si l'entrée est une coordonnée valide (nombre avec ou sans décimales)
    if [[ ! "$input" =~ ^-?[0-9]*\.?[0-9]*$ ]]; then
        echo ""
        return
    fi

    # Formate à 2 décimales (comme original)
    input=$(echo "${input}" | sed 's/\([0-9]*\.[0-9]\{2\}\).*/\1/')
    
    # First: add leading zero for values like .5 or -.5
    if [[ ${input} =~ ^\.[0-9]+$ ]]; then
        input="0${input}"
    elif [[ ${input} =~ ^-\.[0-9]+$ ]]; then
        # Handle negative with leading dot: -.20 → -0.20
        input="-0${input:1}"
    fi
    
    # Then: ensure 2 decimal places
    if [[ ${input} =~ ^-?[0-9]+\.[0-9]$ ]]; then
        input="${input}0"
    elif [[ ${input} =~ ^-?[0-9]+\.$ ]]; then
        input="${input}00"
    elif [[ ${input} =~ ^-?[0-9]+$ ]]; then
        input="${input}.00"
    fi

    # Si le résultat est vide ou invalide (ex: entrée ".")
    if [[ ! "$input" =~ ^-?[0-9]+\.[0-9]{2}$ ]]; then
        echo ""
    else
        echo "${input}"
    fi
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
    local geolocalisation=$(curl -m 5 -s "$url")

    local ville=$(echo "$geolocalisation" | jq -r '.city')
    local pays=$(echo "$geolocalisation" | jq -r '.country')

    echo "$ville,$pays"
}

my_LatLon() {
    local ip=$1

    if [ -z "$ip" ]; then
        ip=$(curl 'https://api.ipify.org?format=json' --silent | jq -r '.ip')
    fi

    local url="http://ip-api.com/json/$ip"
    local geolocalisation=$(curl -s "$url")

    local countrycode=$(echo "$geolocalisation" | jq -r '.countryCode')
    local lat=$(echo "$geolocalisation" | jq -r '.lat')
    local lon=$(echo "$geolocalisation" | jq -r '.lon')

    # Format lat and lon with 2 decimals using awk
    local lat_formatted=$(echo "$lat" | awk '{printf "%.2f", $0}')
    local lon_formatted=$(echo "$lon" | awk '{printf "%.2f", $0}')

    echo "$countrycode $lat_formatted $lon_formatted"
}

IPFSNODEID="$(myIpfsPeerId)"

isLAN="$(isLan)"
myIP="$(myIp)" # "127.0.0.1"

## SEE https://pad.p2p.legal/s/keygen
NODEG1PUB=$(cat $HOME/.zen/game/secret.NODE.dunikey 2>/dev/null | grep "pub:" | cut -d ' ' -f 2)

## my_ip_cache
IP_CACHE="$HOME/.zen/tmp/my_ip_cache"
if [[ -f "$IP_CACHE" ]]; then
    read myIP isLAN < "$IP_CACHE"
else
    myIP=$(hostname -I | awk '{print $1}' | head -n 1)
    isLAN=$(echo $myIP | grep -E "(^127\.)|(^192\.168\.)|(^10\.)|(^172\.1[6-9]\.)|(^172\.2[0-9]\.)|(^172\.3[0-1]\.)|(^::1$)|(^[fF][cCdD])")
    mkdir -p "$HOME/.zen/tmp"
    echo "$myIP $isLAN" > "$IP_CACHE"
fi

myDOMAIN="$(myDomainName)"
myHOSTNAME="$(myHName)"
myASTROPORT="http://127.0.0.1:12345" # BE ACCESSIBLE THROUGH LAN - UPDATED TO 12345
myAPI="http://127.0.0.1:5001" ## IPFS API
myDATA="https://data.gchange.fr" ## GCHANGE +
myGCHANGE="https://www.gchange.fr"
myCESIUM="https://g1.data.e-is.pro" ## CESIUM +
myG1BILLET="http://127.0.0.1:33101"
myHOST="$(myHostName)"

myIPFS="http://ipfs.copylaradio.com" ## Used to create IPFS URL
myIPFSGW="$(myIpfsGw)"
myTUBE="$(myTube)"
myASTROTUBE="https://$(myAstroTube)"

## WAN STATION
[ -z "$isLAN" ] \
 && myASTROPORT="https://astroport.$(myDomainName)" \
 && myAPI="https://ipfs.$(myHostName)/5001" \
 && myIPFS="https://ipfs.$(myDomainName)" \
 && myHOST="astroport.$(myHostName)" \
 && myG1BILLET="https://libra.${myDOMAIN}" \
 && myIPFSW="https://ipfs.${myDOMAIN}" \
 || true

## zIP :: PUT YOUR Internet Box IP IN $HOME/.zen/♥Box  -> Forward PORTS 8080 4001 (5001) 12345 54321 (33101 33102)
[ -n "$(zIp)" ] \
 && myASTROPORT="http://$(zIp):12345" \
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
    # Initialize variables to avoid "unbound variable" error with set -u
    large="${large:-}"
    haut="${haut:-}"
    if [[ -z "$large" && -z "$haut" ]]; then
        # Check cache first
        cache_file="$HOME/.zen/tmp/screen_dimensions"
        if [[ -f "$cache_file" ]]; then
            large=$(cat "$cache_file" | cut -d '|' -f1)
            haut=$(cat "$cache_file" | cut -d '|' -f2)
        else
            # Get dimensions and cache them
            screen=$(xdpyinfo | grep dimensions | sed -r 's/^[^0-9]*([0-9]+x[0-9]+).*$/\1/')
            width=$(echo $screen | cut -d 'x' -f 1)
            height=$(echo $screen | cut -d 'x' -f 2)
            large=$((width-300))
            haut=$((height-200))
            mkdir -p "$HOME/.zen/tmp"
            echo "${large}|${haut}" > "$cache_file"
        fi
    fi
###
fi

## https://git.p2p.legal/qo-op/OSM2IPFS
FLIPPERCID="/ipns/copylaradio.com/coinflip" ### EASTER EGG

###############################################
## VISIO ROOM APP - DNS LINK
## https://github.com/steveseguin/vdo.ninja
VDONINJA="https://vdo.copylaradio.com"
###########################
## CESIUM APP
## https://cesium.app
CESIUMIPFS="/ipfs/QmXex8PTnQehx4dELrDYuZ2t5ag85crYCBxm3fcTjVWo2k" # v1.7.10
CESIUMIPFS="/ipfs/QmUJbCUcZKEsyRJie6NKiyKdseYtNNAGp1vEiSZqg5VL7i" # v1.7.13 - changed init scan
CESIUMIPFS="https://cesium.copylaradio.com"  ## DNSLink /ipns/cesium.copylaradio.com

## GCHANGE HACK (bof)
HACKGIPFS="/ipfs/Qmemnmd9V4WQEQF1wjKomeBJSuvAoqFBS7Hoq4sBDxvV2F"

[[ -s $HOME/.zen/Astroport.ONE/.env ]] && source $HOME/.zen/Astroport.ONE/.env
if [ -s "$HOME/.astro/bin/activate" ]; then
    source $HOME/.astro/bin/activate
fi
## DETECT WIREGUARD VPN (Special Cases & Fallback Optimization)
myWG_IP=$(ip -4 addr show wg0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)

if [ -n "$myWG_IP" ]; then
    export WG_IP="$myWG_IP"
    export WG_HUB="10.99.99.1"
    # Conserver le HUB WireGuard comme cible de secours explicite,
    # sans écraser la cible normale définie dans .env.
    export SWARM_REMOTE_HOST_VPN="${SWARM_REMOTE_HOST_VPN:-$WG_HUB}"
    export SWARM_REMOTE_PORT_IPV4_VPN="${SWARM_REMOTE_PORT_IPV4_VPN:-22}"
    export SWARM_REMOTE_PORT_IPV6_VPN="${SWARM_REMOTE_PORT_IPV6_VPN:-22}"
fi

_swarm_tcp_probe() {
    local host="$1"
    local port="$2"
    local target="$host"

    [[ -z "$host" || -z "$port" ]] && return 1
    if [[ "$host" == *:* && "$host" != \[*\] ]]; then
        target="[$host]"
    fi

    timeout 2 bash -c ": >/dev/tcp/$target/$port" >/dev/null 2>&1
}

check_wireguard_tunnel() {
    ip link show wg0 >/dev/null 2>&1 || return 1
    ip -4 addr show wg0 >/dev/null 2>&1 || return 1
    return 0
}

resolve_vpn_remote_target() {
    local vpn_host="${SWARM_REMOTE_HOST_VPN:-${WG_HUB:-10.99.99.1}}"
    local vpn_port_ipv4="${SWARM_REMOTE_PORT_IPV4_VPN:-22}"
    local vpn_port_ipv6="${SWARM_REMOTE_PORT_IPV6_VPN:-22}"

    if ! check_wireguard_tunnel; then
        return 1
    fi

    if _swarm_tcp_probe "$vpn_host" "$vpn_port_ipv4" || _swarm_tcp_probe "$vpn_host" "$vpn_port_ipv6"; then
        export SWARM_REMOTE_HOST_VPN="$vpn_host"
        export SWARM_REMOTE_PORT_IPV4_VPN="$vpn_port_ipv4"
        export SWARM_REMOTE_PORT_IPV6_VPN="$vpn_port_ipv6"
        export SWARM_REMOTE_TARGET_VPN="${vpn_host}|${vpn_port_ipv4}|${vpn_port_ipv6}"
        return 0
    fi

    return 1
}

resolve_swarm_remote_target() {
    local default_host="${1:-scorpio.copylaradio.com}"
    local default_port_ipv4="${2:-2122}"
    local default_port_ipv6="${3:-22}"
    local use_vpn_fallback="${SWARM_REMOTE_USE_VPN:-false}"
    local legacy_vpn_host="${WG_HUB:-10.99.99.1}"

    local -a candidates=()
    local candidate host port_ipv4 port_ipv6

    if [[ -n "${SWARM_REMOTE_HOST:-}" && "${SWARM_REMOTE_HOST}" != "$legacy_vpn_host" ]]; then
        candidates+=("${SWARM_REMOTE_HOST}|${SWARM_REMOTE_PORT_IPV4:-$default_port_ipv4}|${SWARM_REMOTE_PORT_IPV6:-$default_port_ipv6}")
    fi

    candidates+=("${default_host}|${default_port_ipv4}|${default_port_ipv6}")

    case "$use_vpn_fallback" in
        1|true|TRUE|yes|YES|on|ON)
            [[ -n "${SWARM_REMOTE_HOST_VPN:-}" ]] && \
                candidates+=("${SWARM_REMOTE_HOST_VPN}|${SWARM_REMOTE_PORT_IPV4_VPN:-22}|${SWARM_REMOTE_PORT_IPV6_VPN:-22}")
            ;;
    esac

    for candidate in "${candidates[@]}"; do
        IFS='|' read -r host port_ipv4 port_ipv6 <<<"$candidate"
        [[ -z "$host" ]] && continue

        if _swarm_tcp_probe "$host" "$port_ipv4" || _swarm_tcp_probe "$host" "$port_ipv6"; then
            export SWARM_REMOTE_HOST="$host"
            export SWARM_REMOTE_PORT_IPV4="$port_ipv4"
            export SWARM_REMOTE_PORT_IPV6="$port_ipv6"
            export SWARM_REMOTE_TARGET="${host}|${port_ipv4}|${port_ipv6}"
            return 0
        fi
    done

    export SWARM_REMOTE_HOST="$default_host"
    export SWARM_REMOTE_PORT_IPV4="$default_port_ipv4"
    export SWARM_REMOTE_PORT_IPV6="$default_port_ipv6"
    export SWARM_REMOTE_TARGET="${SWARM_REMOTE_HOST}|${SWARM_REMOTE_PORT_IPV4}|${SWARM_REMOTE_PORT_IPV6}"
    return 1
}

swarm_remote_target_report() {
    if [[ -n "${SWARM_REMOTE_TARGET:-}" ]]; then
        IFS='|' read -r host port_ipv4 port_ipv6 <<<"$SWARM_REMOTE_TARGET"
        echo "host=$host ipv4=$port_ipv4 ipv6=$port_ipv6"
    else
        echo "host=${SWARM_REMOTE_HOST:-unset} ipv4=${SWARM_REMOTE_PORT_IPV4:-unset} ipv6=${SWARM_REMOTE_PORT_IPV6:-unset}"
    fi
}

# Déterminer la meilleure cible de connexion sans forcer le tunnel VPN.
SWARM_CACHE_FILE="$HOME/.zen/tmp/swarm_target_cache.env"

if [[ -f "$SWARM_CACHE_FILE" ]]; then
    source "$SWARM_CACHE_FILE"
else
    resolve_swarm_remote_target
    # On sauvegarde le résultat pour les futurs appels
    echo "export SWARM_REMOTE_HOST=\"$SWARM_REMOTE_HOST\"" > "$SWARM_CACHE_FILE"
    echo "export SWARM_REMOTE_PORT_IPV4=\"$SWARM_REMOTE_PORT_IPV4\"" >> "$SWARM_CACHE_FILE"
    echo "export SWARM_REMOTE_PORT_IPV6=\"$SWARM_REMOTE_PORT_IPV6\"" >> "$SWARM_CACHE_FILE"
    echo "export SWARM_REMOTE_TARGET=\"$SWARM_REMOTE_TARGET\"" >> "$SWARM_CACHE_FILE"
fi

[[ $myDOMAIN == "localhost" && -s ~/.zen/♥Box ]] \
    && myDOMAIN=$(echo $myIPFS | rev | cut -d '.' -f -2 | rev)
[[ $myDOMAIN == "localhost" ]] && myDOMAIN="copylaradio.com"

## NOSTR RELAY ADDRESS
myRELAY=$(echo $myIPFS | sed 's|https://ipfs|wss://relay|') ## wss://
[[ $myRELAY == $myIPFS ]] \
    && myRELAY=$(echo $myIPFS | sed 's~http://~ws://~' | sed 's~8080~7777~' ) ## ws://

## UPassport API node
uSPOT=$(echo $myIPFS | sed 's|https://ipfs|https://u|') ## https://u. OR :54321
[[ $uSPOT == $myIPFS ]] \
    && uSPOT=$(echo $myIPFS | sed 's~8080~54321~' )

##########################
myUPLANET="${myIPFS}/ipns/copylaradio.com" ## UPLANET ENTRANCE
myLIBRA="https://ipfs.copylaradio.com" ## PUBLIC IPFS GATEWAY
myCORACLE="${myCORACLE:-${myIPFS}/ipns/coracle.copylaradio.com}" ## CORACLE NOSTR CLIENT

## UPLANETNAME IS $HOME/.ipfs/swarm.key OR 0000000000000000000000000000000000000000000000000000000000000000[ -n "$(UPlanetSharedSecret)" ] \
    && UPLANETNAME="$(UPlanetSharedSecret)" \
    || UPLANETNAME="0000000000000000000000000000000000000000000000000000000000000000"

CAPTAINZENCARDG1PUB=$(cat $HOME/.zen/game/players/.current/.g1pub 2>/dev/null) ## PLAYER ONE ZEN CARD G1PUB
# Lire CAPTAINEMAIL depuis .current/.player — conserver la valeur exportée comme fallback
_captainemail_from_current=$(cat $HOME/.zen/game/players/.current/.player 2>/dev/null)
[[ -n "$_captainemail_from_current" ]] \
    && CAPTAINEMAIL="$_captainemail_from_current" \
    || CAPTAINEMAIL="${CAPTAINEMAIL:-}"
unset _captainemail_from_current
CAPTAINHEX=$(cat $HOME/.zen/game/nostr/${CAPTAINEMAIL}/HEX 2>/dev/null) ## PLAYER ONE HEX
CAPTAING1PUB=$(cat $HOME/.zen/game/nostr/${CAPTAINEMAIL}/G1PUBNOSTR 2>/dev/null) ## PLAYER ONE MULTIPASS G1PUBNOSTR

# =========================================================================
# GESTION DYNAMIQUE DU CHANGEMENT DE SWARM.KEY ET CACHES (HAUTES PERFORMANCES)
# =========================================================================
UPLANET_STATE_FILE="$HOME/.zen/game/.current_uplanet"
LAST_UPLANET=$(cat "$UPLANET_STATE_FILE" 2>/dev/null)

if [[ "$UPLANETNAME" != "$LAST_UPLANET" ]]; then
    # La swarm.key a changé ! On sauvegarde les vieilles clés (dunikey, nostr, ss58)
    if [[ -n "$LAST_UPLANET" ]]; then
        BACKUP_DIR="$HOME/.zen/game/backup_${LAST_UPLANET}"
        mkdir -p "$BACKUP_DIR"
        mv "$HOME/.zen/game/uplanet."* "$BACKUP_DIR/" 2>/dev/null || true
    fi
    echo "$UPLANETNAME" > "$UPLANET_STATE_FILE"
fi

# Fonction de création/cache des portefeuilles
# -> CRÉE LE FICHIER .dunikey SUR LE DISQUE pour que les autres scripts puissent l'utiliser
init_and_cache_wallet() {
    local file_prefix="$1"
    local seed="$2"
    local dunikey_file="$HOME/.zen/game/${file_prefix}.dunikey"
    local cache_file="$HOME/.zen/game/${file_prefix}.ss58"
    
    # 1. Génère le fichier clé s'il n'existe pas (physiquement sur le disque)
    if [[ ! -s "$dunikey_file" ]]; then
        "$HOME/.zen/Astroport.ONE/tools/keygen" -t duniter -o "$dunikey_file" "$seed" "$seed" >/dev/null 2>&1
        chmod 600 "$dunikey_file" 2>/dev/null
    fi
    
    # 2. Utilise le cache persistant SS58 s'il existe pour éviter de lancer Python
    if [[ -f "$cache_file" ]]; then
        cat "$cache_file"
    else
        local pub=$(grep "pub" "$dunikey_file" | cut -d " " -f 2)
        local ss58=$("$HOME/.zen/Astroport.ONE/tools/g1pub_to_ss58.py" "$pub")
        echo "$ss58" > "$cache_file"
        echo "$ss58"
    fi
}

## Application immédiate sur tous les portefeuilles de l'écosystème UPLANET :
## Cela garantit que tous les .dunikey existent physiquement sur le disque pour PAYforSURE.sh etc.
UPLANETNAME_G1=$(init_and_cache_wallet "uplanet.G1" "${UPLANETNAME}.G1")
UPLANETG1PUB=$(init_and_cache_wallet "uplanet" "${UPLANETNAME}")
UPLANETNAME_SOCIETY=$(init_and_cache_wallet "uplanet.SOCIETY" "${UPLANETNAME}.SOCIETY")
UPLANETNAME_INTRUSION=$(init_and_cache_wallet "uplanet.INTRUSION" "${UPLANETNAME}.INTRUSION")
UPLANETNAME_CAPITAL=$(init_and_cache_wallet "uplanet.CAPITAL" "${UPLANETNAME}.CAPITAL")
UPLANETNAME_AMORTISSEMENT=$(init_and_cache_wallet "uplanet.AMORTISSEMENT" "${UPLANETNAME}.AMORTISSEMENT")
UPLANETNAME_IMPOT=$(init_and_cache_wallet "uplanet.IMPOT" "${UPLANETNAME}.IMPOT")
UPLANETNAME_TREASURY=$(init_and_cache_wallet "uplanet.CASH" "${UPLANETNAME}.TREASURY")
UPLANETNAME_ASSETS=$(init_and_cache_wallet "uplanet.ASSETS" "${UPLANETNAME}.ASSETS")
UPLANETNAME_RND=$(init_and_cache_wallet "uplanet.RnD" "${UPLANETNAME}.RND")

# Portefeuille CAPTAIN
if [[ -n "${CAPTAINEMAIL}" ]]; then
    UPLANETNAME_CAPTAIN=$(init_and_cache_wallet "uplanet.captain" "${UPLANETNAME}.${CAPTAINEMAIL}")
fi

## IDENTITÉ NOSTR uplanet.G1 (Générée sur disque pour les autres scripts)
if [[ ! -s "$HOME/.zen/game/uplanet.G1.nostr" ]]; then
    npub=$("$HOME/.zen/Astroport.ONE/tools/keygen" -t nostr "${UPLANETNAME}.G1" "${UPLANETNAME}.G1" 2>/dev/null)
    nsec=$("$HOME/.zen/Astroport.ONE/tools/keygen" -t nostr "${UPLANETNAME}.G1" "${UPLANETNAME}.G1" -s 2>/dev/null)
    hex=$("$HOME/.zen/Astroport.ONE/tools/nostr2hex.py" "$npub" 2>/dev/null)
    echo "NSEC=$nsec; NPUB=$npub; HEX=$hex" > "$HOME/.zen/game/uplanet.G1.nostr"
    chmod 600 "$HOME/.zen/game/uplanet.G1.nostr"
fi

# =========================================================================
# UPLANETNAME_NODE (Lui ne dépend pas de la swarm.key, donc cache séparé)
# =========================================================================
cache_node="$HOME/.zen/game/node_ss58.cache"
if [[ -f "$HOME/.zen/game/secret.NODE.dunikey" ]]; then
    if [[ -f "$cache_node" ]]; then
        UPLANETNAME_NODE=$(cat "$cache_node")
    else
        UPLANETNAME_NODE=$(cat "$HOME/.zen/game/secret.NODE.dunikey" | grep "pub" | cut -d " " -f 2)
        UPLANETNAME_NODE=$("$HOME/.zen/Astroport.ONE/tools/g1pub_to_ss58.py" "${UPLANETNAME_NODE}")
        echo "$UPLANETNAME_NODE" > "$cache_node"
    fi
elif [[ -n "$IPFSNODEID" ]]; then
    if [[ -f "$cache_node" ]]; then
        UPLANETNAME_NODE=$(cat "$cache_node")
    else
        UPLANETNAME_NODE=$("$HOME/.zen/Astroport.ONE/tools/ipfs_to_g1.py" "$IPFSNODEID")
        UPLANETNAME_NODE=$("$HOME/.zen/Astroport.ONE/tools/g1pub_to_ss58.py" "${UPLANETNAME_NODE}")
        echo "$UPLANETNAME_NODE" > "$cache_node"
    fi
else
    echo "⚠️  NODE wallet not found and IPFSNODEID not available"
fi

# =========================================================================

[[ -s ${HOME}/.zen/game/MY_boostrap_nodes.txt ]] \
    && STRAPFILE="${HOME}/.zen/game/MY_boostrap_nodes.txt" \
    || STRAPFILE="${HOME}/.zen/Astroport.ONE/A_boostrap_nodes.txt"

TODATE=$(date -d "today 13:00" '+%Y-%m-%d')
YESTERDATE=$(date -d "yesterday 13:00" '+%Y-%m-%d')
DEMAINDATE=$(date -d "tomorrow 13:00" '+%Y-%m-%d')