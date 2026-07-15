#shellcheck shell=sh disable=SC2034
export LC_ALL=C.utf8
urldecode() {
    # Version pure shell sans echo -e
    local data="${*//+/ }"
    printf '%b\n' "${data//%/\\x}"
}

Base32Normalize() {
    awk '{printf $0}' | basenc --base32 | Normalize
}

Normalize() {
    local val="${1}"
    [[ -z "$val" ]] && IFS= read -r val
    val="${val,,}"
    val="${val//_/.}"; val="${val//+/.}"
    echo "${val//=/}"
}


Revert() {
    awk -F. '{for (i=NF; i>1; i--) printf("%s.",$i); print $1;}'
}

isLan() {
    [ -n "$isLAN" ] && return 0 || return 1
}

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
    [ -z "$__CACHE_ASTROPATH" ] && __CACHE_ASTROPATH="$HOME/.zen/Astroport.ONE"
    echo "$__CACHE_ASTROPATH"
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
    echo "$HOME"
}

myHostName() {
    if [ -z "$__CACHE_HOSTNAME" ]; then
        local h=$(hostname)
        local d=$(myDomainName)
        [[ "$h" != *"$d"* ]] && __CACHE_HOSTNAME="${h}.${d}" || __CACHE_HOSTNAME="$h"
    fi
    echo "$__CACHE_HOSTNAME"
}

myHName() {
    local myHName=$(hostname -s)
    [ -n "$myHName" ] && echo "$myHName"
}

zIp() {
    zipit=$(head -n 1 "$HOME/.zen/♥Box" 2>/dev/null)
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
    if [ -z "$__CACHE_IPFS_API" ]; then
        local api_file="$HOME/.ipfs/api"
        if [ -f "$api_file" ]; then
            local api_val=$(cat "$api_file")
            # On teste la connexion une seule fois pour toute la session (timeout court)
            if ipfs --timeout 2s --api "$api_val" id >/dev/null 2>&1; then
                __CACHE_IPFS_API="$api_val"
            fi
        fi
    fi
    echo "$__CACHE_IPFS_API"
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
    if [ -z "$__CACHE_BOOTSTRAP_NODES" ]; then
        local file1="$(myAstroPath)/A_boostrap_nodes.txt"
        local file2="$(myAstroPath)/../game/MY_boostrap_nodes.txt"
        local nodes=""
        
        for f in "$file1" "$file2"; do
            if [ -f "$f" ]; then
                while read -r line; do
                    # Si la ligne contient au moins 6 slashs (format multiaddr)
                    [[ "$line" == */*/*/*/*/* ]] && nodes="$nodes$line "
                done < "$f"
            fi
        done
        __CACHE_BOOTSTRAP_NODES="$nodes"
    fi
    echo "$__CACHE_BOOTSTRAP_NODES"
}

myIpfsGw() { echo "$myIPFSGW"; }

myIpfsKey() {
    if [ -z "$__CACHE_IPFS_SELF_KEY" ]; then
        # On ne lance ipfs que si nécessaire
        __CACHE_IPFS_SELF_KEY=$(ipfs --api "$(myIpfsApi)" key list -l | awk '$2 == "self" {print $1}')
    fi
    echo "$__CACHE_IPFS_SELF_KEY"
}

myIpfsKeyStore() {
    [ -z "$__CACHE_KEYSTORE" ] && __CACHE_KEYSTORE="$HOME/.ipfs/keystore"
    echo "$__CACHE_KEYSTORE"
}

myIpfsPeerId() {
    if [ -z "$__CACHE_PEERID" ]; then
        local config="$HOME/.ipfs/config"
        [ -f "$config" ] && __CACHE_PEERID=$(jq -r .Identity.PeerID "$config" 2>/dev/null)
    fi
    echo "$__CACHE_PEERID"
}

myIpns() {
    [ -n "$(myIpfsKey)" ] \
     && local myIpns="${myIPFS}/ipns/$(myIpfsKey)" \
     && echo "$myIpns"
}

myPlayer() {
    if [ -z "$__CACHE_PLAYER" ]; then
        __CACHE_PLAYER=$(cat "$(myPath)/.current/.player" 2>/dev/null)
    fi
    echo "$__CACHE_PLAYER"
}

myPath() {
    [ -z "$__CACHE_MYPATH" ] && __CACHE_MYPATH=$(cd $HOME/.zen/game/players/ && pwd -P)
    echo "$__CACHE_MYPATH"
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
    if [ -z "$__CACHE_MYPLAYERPATH" ]; then
        local p=$(myPlayer)
        [ -n "$p" ] && __CACHE_MYPLAYERPATH=$(cd "$(myPath)/$p" 2>/dev/null && pwd -P)
    fi
    echo "$__CACHE_MYPLAYERPATH"
}

myPlayerPseudo() {
    local myPlayerPseudo=$(cat "$(myPlayerPath)"/.pseudo 2>/dev/null)
    [ -n "$myPlayerPseudo" ] && echo "$myPseudo"
}

_setup_player_identity() {
    [ -n "$__PLAYER_ID_SET" ] && return
    local p=$(myPlayer)
    [ -z "$p" ] && return

    myPlayerUser="${p%%@*}"
    myPlayerDomain="${p#*@}"
    [ "$myPlayerDomain" = "$p" ] && myPlayerDomain="" # Pas de @ trouvé
    
    myPlayerUser="${myPlayerUser,,}"
    myPlayerDomain="${myPlayerDomain,,}"
    
    myReyalp="${myPlayerUser}.${myPlayerDomain}"
    [ -z "$myPlayerDomain" ] && myReyalp="$myPlayerUser"
    
    __PLAYER_ID_SET=1
}

myPlayerUser() { _setup_player_identity; echo "$myPlayerUser"; }
myPlayerDomain() { _setup_player_identity; echo "$myPlayerDomain"; }
myReyalp() { _setup_player_identity; echo "$myReyalp"; }

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
    _setup_player_identity
    [ -z "$__CACHE_REYALP_RESU_NIAMOD" ] && __CACHE_REYALP_RESU_NIAMOD="${myPlayerDomain}.${myPlayerUser}"
    echo "$__CACHE_REYALP_RESU_NIAMOD"
}

myReyalpResuPath() {
    local niamod=$(myReyalpResuNiamod)
    echo "${niamod//.//}"
}

myTs() {
    echo "${EPOCHSECONDS:-$(date +%s)}"
}

myTube() { echo "$myTUBE"; }

myAstroTube() { echo "$myASTROTUBE"; }

function makecoord() {
    local input="$1"

    # Vérifie si l'entrée est une coordonnée valide (nombre avec ou sans décimales)
    [[ -z "$input" ]] && echo "" && return
    if [[ ! "$input" =~ ^-?[0-9]+\.?[0-9]*$ ]]; then
        echo ""
        return
    fi

    # Formate à 2 décimales (single quotes : $0 est interprété par awk, pas par bash)
    input=$(echo "${input}" | awk '{printf "%.2f", $0}')
    
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
        return
    fi

    # Rejeter 0.00 : sentinel GPS désactivé (évite d'ancrer des données à Point Nemo)
    [[ "$input" == "0.00" ]] && echo "" && return

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
    local geolocalisation=$(curl -m 5 -s "$url")

    local ville=$(echo "$geolocalisation" | jq -r '.city')
    local pays=$(echo "$geolocalisation" | jq -r '.country')

    echo "$ville,$pays"
}

my_LatLon() {
    local cache_geo="$HOME/.zen/tmp/geo_latlon.cache"
    # Si le cache a moins de 24h (86400 sec), on l'utilise
    if [[ -f "$cache_geo" ]] && [[ $(( $(date +%s) - $(stat -c %Y "$cache_geo") )) -lt 86400 ]]; then
        cat "$cache_geo"
        return
    fi

    local ip=$(curl -s --max-time 2 'https://api.ipify.org')
    [ -z "$ip" ] && echo "FR 48.85 2.35" && return # Fallback Paris si hors ligne

    local geo=$(curl -s --max-time 3 "http://ip-api.com/json/$ip")
    local country=$(echo "$geo" | jq -r '.countryCode')
    local lat=$(echo "$geo" | jq -r '.lat')
    local lon=$(echo "$geo" | jq -r '.lon')
    
    local res=$(printf "%s %.2f %.2f" "$country" "$lat" "$lon")
    echo "$res" > "$cache_geo"
    echo "$res"
}

## IPFSNODEID cache 1h (myIpfsPeerId lit ~/.ipfs/config via jq — subshell évité)
_IPFSID_CACHE="$HOME/.zen/tmp/ipfsnodeid.cache"
if [[ -s "$_IPFSID_CACHE" ]] && \
   [[ $(( $(date +%s) - $(stat -c %Y "$_IPFSID_CACHE" 2>/dev/null || echo 0) )) -lt 3600 ]]; then
    IPFSNODEID=$(cat "$_IPFSID_CACHE")
else
    [[ -z "$IPFSNODEID" ]] && IPFSNODEID="$(myIpfsPeerId)"
    if [[ -n "$IPFSNODEID" ]]; then
        mkdir -p "$HOME/.zen/tmp"
        echo "$IPFSNODEID" > "$_IPFSID_CACHE"
    fi
fi

## SEE https://pad.p2p.legal/s/keygen
NODEG1PUB=$(awk '/^pub:/{print $2}' "$HOME/.zen/game/secret.NODE.dunikey" 2>/dev/null)

## my_ip_cache — isLAN et myIP calculés une seule fois, puis mis en cache
IP_CACHE="$HOME/.zen/tmp/my_ip_cache"
if [[ -f "$IP_CACHE" ]]; then
    read myIP isLAN < "$IP_CACHE"
else
    myIP=$(hostname -I | awk '{print $1}' | head -n 1)
    isLAN=$(echo "$myIP" | grep -E "(^127\.)|(^192\.168\.)|(^10\.)|(^172\.1[6-9]\.)|(^172\.2[0-9]\.)|(^172\.3[0-1]\.)|(^::1$)|(^[fF][cCdD])")
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

## Lecture unique du fichier bootstrap pour myIPFSGW, myTUBE, myASTROTUBE
_STRAPFILE="${HOME}/.zen/game/MY_boostrap_nodes.txt"
[[ ! -f "$_STRAPFILE" ]] && _STRAPFILE="${HOME}/.zen/Astroport.ONE/A_boostrap_nodes.txt"

if [[ -f "$_STRAPFILE" ]]; then
    _STRAP_LINE2=$(sed -n '2p' "$_STRAPFILE")
    myIPFSGW=$(echo "$_STRAP_LINE2" | awk '{print $2}')
    myTUBE=$(echo "$_STRAP_LINE2" | awk '{print $3}')
    myASTROTUBE="https://${myTUBE//ipfs/astroport}"
fi

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
            IFS='|' read -r large haut < "$cache_file"
        else
            # Get dimensions and cache them
            screen=$(xdpyinfo | grep dimensions | sed -r 's/^[^0-9]*([0-9]+x[0-9]+).*$/\1/')
            _w="${screen%%x*}" _h="${screen##*x}"
            large=$((_w-300))
            haut=$((_h-200))
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
CESIUMIPFS="https://cesium.copylaradio.com"  ## DNSLink /ipns/cesium.copylaradio.com

## GCHANGE HACK (bof)
HACKGIPFS="/ipfs/Qmemnmd9V4WQEQF1wjKomeBJSuvAoqFBS7Hoq4sBDxvV2F"

##################################### ENV + VENV
[[ -s "$HOME/.zen/Astroport.ONE/.env" ]] && source "$HOME/.zen/Astroport.ONE/.env"
ASTRO_VENV="$HOME/.astro"
# activer seulement si pas déjà dans ce venv
if [ -s "$ASTRO_VENV/bin/activate" ] && [ "$VIRTUAL_ENV" != "$ASTRO_VENV" ]; then
    source "$ASTRO_VENV/bin/activate"
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
    local host="$1" port="$2"
    [[ -z "$host" || -z "$port" ]] && return 1
    timeout 1 bash -c "cat < /dev/tcp/$host/$port" >/dev/null 2>&1
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
if [[ $myIPFS == https://ipfs* ]]; then
    myRELAY="${myIPFS/https:\/\/ipfs/wss:\/\/relay}"
else
    myRELAY="${myIPFS/http:\/\//ws:\/\/}"
    myRELAY="${myRELAY/8080/7777}"
fi

## UPassport API node
if [[ $myIPFS == https://ipfs* ]]; then
    uSPOT="${myIPFS/https:\/\/ipfs/https:\/\/u}"
else
    uSPOT="${myIPFS/8080/54321}"
fi

##########################
myUPLANET="${myIPFS}/ipns/copylaradio.com" ## UPLANET ENTRANCE
myLIBRA="https://ipfs.copylaradio.com" ## PUBLIC IPFS GATEWAY
myCORACLE="${myCORACLE:-https://coracle.copylaradio.com}" ## CORACLE NOSTR CLIENT

## UPLANETNAME IS $HOME/.ipfs/swarm.key OR 0000000000000000000000000000000000000000000000000000000000000000
[ -n "$(UPlanetSharedSecret)" ] \
    && UPLANETNAME="$(UPlanetSharedSecret)" \
    || UPLANETNAME="0000000000000000000000000000000000000000000000000000000000000000"

CAPTAINZENCARDG1PUB=$(cat $HOME/.zen/game/players/.current/.g1pub 2>/dev/null) ## PLAYER ONE ZEN CARD G1PUB
# Lire CAPTAINEMAIL depuis .current/.player — conserver la valeur exportée comme fallback
_captainemail_from_current=$(cat $HOME/.zen/game/players/.current/.player 2>/dev/null)
[[ -n "$_captainemail_from_current" ]] \
    && export CAPTAINEMAIL="$_captainemail_from_current" \
    || export CAPTAINEMAIL="${CAPTAINEMAIL:-}"
unset _captainemail_from_current
export CAPTAINHEX=$(cat $HOME/.zen/game/nostr/${CAPTAINEMAIL}/HEX 2>/dev/null) ## PLAYER ONE HEX
export CAPTAING1PUB=$(cat $HOME/.zen/game/nostr/${CAPTAINEMAIL}/G1PUBNOSTR 2>/dev/null) ## PLAYER ONE MULTIPASS G1PUBNOSTR

# =========================================================================
# GESTION DYNAMIQUE DU CHANGEMENT DE SWARM.KEY ET CACHES (HAUTES PERFORMANCES)
# =========================================================================
mkdir -p "$HOME/.zen/game" ## requis avant toute écriture ci-dessous (peut être sourcé avant install.sh:1350)
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
    local legacy_name="${3:-}"
    
    # Identifiant unique pour le cache en mémoire (ex: CACHE_uplanet_G1)
    local var_cache="CACHE_${file_prefix//./_}"
    
    # Si déjà en mémoire, on retourne immédiatement
    if [ -n "${!var_cache}" ]; then
        echo "${!var_cache}"
        return
    fi

    local dunikey_file="$HOME/.zen/game/${file_prefix}.dunikey"
    local cache_file="$HOME/.zen/game/${file_prefix}.ss58"
    
    # 1. Création fichier si absent
    if [[ ! -s "$dunikey_file" ]]; then
        "$HOME/.zen/Astroport.ONE/tools/keygen" -t duniter -o "$dunikey_file" "$seed" "$seed" >/dev/null 2>&1
        chmod 600 "$dunikey_file" 2>/dev/null
    fi
    
    # 2. Lecture cache disque ou calcul Python
    local ss58=""
    if [[ -f "$cache_file" ]]; then
        ss58=$(cat "$cache_file")
    else
        local pub=$(awk '/pub:/{print $2}' "$dunikey_file")
        ss58=$("$HOME/.zen/Astroport.ONE/tools/g1pub_to_ss58.py" "$pub")
        echo "$ss58" > "$cache_file"
    fi

    # 3. Mise en mémoire pour les prochains appels
    printf -v "$var_cache" "%s" "$ss58"
    
    # Compatibilité descendante
    if [[ -n "$legacy_name" ]]; then
        echo "$ss58" > "$HOME/.zen/tmp/${legacy_name}"
        ln -sf "$dunikey_file" "$HOME/.zen/tmp/${legacy_name}.dunikey" 2>/dev/null
    fi

    echo "$ss58"
}

# ensure_g1ss58 <pubkey>
# Convertit une clé Duniter v1 base58 en SS58 si nécessaire.
# Passe-plat si la clé commence déjà par "g1" (format SS58).
# Retourne vide si la conversion échoue.
ensure_g1ss58() {
    local key="${1:-}"
    [[ -z "$key" ]] && return
    if [[ "$key" == g1* ]]; then
        echo "$key"
    else
        python3 "$HOME/.zen/Astroport.ONE/tools/g1pub_to_ss58.py" "$key" 2>/dev/null
    fi
}
export -f ensure_g1ss58

## Application immédiate sur tous les portefeuilles de l'écosystème UPLANET :
## Cela garantit que tous les .dunikey existent physiquement sur le disque pour PAYforSURE.sh etc.
export UPLANETNAME_G1=$(init_and_cache_wallet "uplanet.G1" "${UPLANETNAME}.G1" "UPLANETNAME_G1")
export UPLANETG1PUB=$(init_and_cache_wallet "uplanet" "${UPLANETNAME}" "UPLANETG1PUB")
export UPLANETNAME_SOCIETY=$(init_and_cache_wallet "uplanet.SOCIETY" "${UPLANETNAME}.SOCIETY" "UPLANETNAME_SOCIETY")
export UPLANETNAME_INTRUSION=$(init_and_cache_wallet "uplanet.INTRUSION" "${UPLANETNAME}.INTRUSION" "UPLANETNAME_INTRUSION")
export UPLANETNAME_CAPITAL=$(init_and_cache_wallet "uplanet.CAPITAL" "${UPLANETNAME}.CAPITAL" "UPLANETNAME_CAPITAL")
export UPLANETNAME_AMORTISSEMENT=$(init_and_cache_wallet "uplanet.AMORTISSEMENT" "${UPLANETNAME}.AMORTISSEMENT" "UPLANETNAME_AMORTISSEMENT")
export UPLANETNAME_IMPOT=$(init_and_cache_wallet "uplanet.IMPOT" "${UPLANETNAME}.IMPOT" "UPLANETNAME_IMPOT")
export UPLANETNAME_TREASURY=$(init_and_cache_wallet "uplanet.CASH" "${UPLANETNAME}.TREASURY" "UPLANETNAME_TREASURY")
export UPLANETNAME_ASSETS=$(init_and_cache_wallet "uplanet.ASSETS" "${UPLANETNAME}.ASSETS" "UPLANETNAME_ASSETS")
export UPLANETNAME_RND=$(init_and_cache_wallet "uplanet.RnD" "${UPLANETNAME}.RND" "UPLANETNAME_RND")

# Portefeuille CAPTAIN
if [[ -n "${CAPTAINEMAIL}" ]]; then
    export UPLANETNAME_CAPTAIN=$(init_and_cache_wallet "uplanet.captain" "${UPLANETNAME}.${CAPTAINEMAIL}")
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
        export UPLANETNAME_NODE=$(cat "$cache_node")
    else
        UPLANETNAME_NODE=$(awk '/^pub:/{print $2}' "$HOME/.zen/game/secret.NODE.dunikey")
        UPLANETNAME_NODE=$("$HOME/.zen/Astroport.ONE/tools/g1pub_to_ss58.py" "${UPLANETNAME_NODE}")
        echo "$UPLANETNAME_NODE" > "$cache_node"
    fi
elif [[ -n "$IPFSNODEID" ]]; then
    if [[ -f "$cache_node" ]]; then
        export UPLANETNAME_NODE=$(cat "$cache_node")
    else
        UPLANETNAME_NODE=$("$HOME/.zen/Astroport.ONE/tools/ipfs_to_g1.py" "$IPFSNODEID")
        UPLANETNAME_NODE=$("$HOME/.zen/Astroport.ONE/tools/g1pub_to_ss58.py" "${UPLANETNAME_NODE}")
        echo "$UPLANETNAME_NODE" > "$cache_node"
    fi
else
    echo "⚠️  NODE wallet not found and IPFSNODEID not available" >&2
fi

# =========================================================================
## MY_boostrap_nodes -- NODE specific bootstrap list 
[[ -s ${HOME}/.zen/game/MY_boostrap_nodes.txt ]] \
    && STRAPFILE="${HOME}/.zen/game/MY_boostrap_nodes.txt" \
    || STRAPFILE="${HOME}/.zen/Astroport.ONE/A_boostrap_nodes.txt"

export TODATE=$(date -d "today 13:00" '+%Y-%m-%d')
export YESTERDATE=$(date -d "yesterday 13:00" '+%Y-%m-%d')
export DEMAINDATE=$(date -d "tomorrow 13:00" '+%Y-%m-%d')

## Charger les clés coopératives (APIKEY etc.) depuis le cache NOSTR local
if [ -z "$COOP_CONFIG_LOADED" ]; then
    _COOP_CFG="${HOME}/.zen/Astroport.ONE/tools/cooperative_config.sh"
    if [[ -f "$_COOP_CFG" ]]; then
        source "$_COOP_CFG" 2>/dev/null
        coop_load_env_vars 2>/dev/null && export COOP_CONFIG_LOADED=1
    fi
    unset _COOP_CFG
fi