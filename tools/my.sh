#shellcheck shell=sh disable=SC2034

isLan() {
    isLan=$(ip route |awk '$1 == "default" {print $3}' | grep -E "/(^127\.)|(^192\.168\.)|(^10\.)|(^172\.1[6-9]\.)|(^172\.2[0-9]\.)|(^172\.3[0-1]\.)|(^::1$)|(^[fF][cCdD])/" \
         || route -n |awk '$1 == "0.0.0.0" {print $2}' | grep -E "/(^127\.)|(^192\.168\.)|(^10\.)|(^172\.1[6-9]\.)|(^172\.2[0-9]\.)|(^172\.3[0-1]\.)|(^::1$)|(^[fF][cCdD])/" \
         || true)
    [ -n "$isLan" ] && echo "$isLan" || true
} 2>/dev/null

isPlayerLegal() {
    isPlayerLegal=$(cat "$(myPlayerPath)"/.legal 2>/dev/null || true)
    [ -n "$isPlayerLegal" ] && echo "$isPlayerLegal" || true
}

myAstronauteKey() {
    myAstronauteKey=$(ipfs --api "$(myIpfsApi)" key list -l | awk '$2 == "'"$(myPlayer)"'" {print $1}')
     [ -n "$myAstronauteKey" ] && echo "$myAstronauteKey"
}

myDomainName() {
    myDomainName=$(hostname -d 2>/dev/null) && [ -z "$myDomainName" ] && myDomainName=$(domainname 2>/dev/null) && [ "$myDomainName" = "(none)" ] && myDomainName="localhost"
    [ -n "$myDomainName" ] && echo "$myDomainName"
}

myIpfsHash() {
    [ -f "$(myPath)"/localhost/latest ] \
     && myIpfsHash=$(cat "$(myPath)"/localhost/latest) \
     || myIpfsHash=$(myTmpl |ipfs add -q)
    [ ! -f "$(myPath)"/localhost/latest ] \
     && echo "$myIpfsHash" > "$(myPath)"/localhost/latest
    [ -n "$myIpfsHash" ] && echo "$myIpfsHash"
}

myHttp() {
    [ -n "$(myHttpHeader)" ] \
     && myHttp="$(myHttpHeader)

"    || myHttp=""
    [ -n "$(myHttpContent)" ] \
     && myHttp="${myHttp}$(myHttpContent)"
    [ -n "$myHttp" ] \
     && echo "$myHttp"
}

myHttpContent() {
    [ -n "$(myIpfsHash)" ] \
     && myHttpContent="<html><head><title>302 Found</title></head><body><h1>Found</h1>
<p>The document is <a href=\"ipfs/$(myIpfsHash)\">here</a> in IPFS.</p></body></html>" \
     && echo "$myHttpContent"
}

myHttpHeader() {
    [ -n "$(myIpfsHash)" ] \
     && myHttpHeader="HTTP/1.0 302 Found
Content-Type: text/html; charset=UTF-8
Content-Length: $(myHttpContent |wc -c)
Date: $(date -R)
Location: ipfs/$(myIpfsHash)
Server: and"
    [ -n "$(myIpfsKey)" ] && myHttpHeader="${myHttpHeader}
set-cookie: AND=$(myIpfsKey); expires=$(date -R -d "+1 month"); path=/; domain=.$(myDomainName); Secure; SameSite=lax"
    [ -n "$myHttpHeader" ] && echo "$myHttpHeader"
}

myHome() {
    myHome=$(cd ~ && pwd -P)
    [ -n "$myHome" ] && echo "$myHome"
}

myHostName() {
    myHostName=$(hostname |sed 's/\.'"$(myDomainName)"'$//')
    [ -n "$(myDomainName)" ] && myHostName="${myHostName}.$(myDomainName)" || myDomainName=${myHostName#*.}
    [ -n "$myHostName" ] && echo "$myHostName"
}

myIp() {
    myIp=$(hostname -I | awk '{print $1}' | head -n 1)
    [ -n "$myIp" ] && echo "$myIp"
}

myIpfs() {
    [ -n "$(myIpfsHash)" ] \
     && myIpfs="${myIPFS}/ipfs/$(myIpfsHash)" \
     && echo "$myIpfs"
}

myIpfsApi() {
    ipfs --api "$(cat "$(myHome)"/.ipfs/api)" swarm peers >/dev/null 2>&1 \
     && myIpfsApi=$(cat "$(myHome)"/.ipfs/api) \
     && echo "$myIpfsApi"
}

myIpfsKey() {
    myIpfsKey=$(ipfs --api "$(myIpfsApi)" key list -l | awk '$2 == "self" {print $1}')
    [ -n "$myIpfsKey" ] && echo "$myIpfsKey"
}

myIpfsKeystore() {
    myIpfsKeystore=$(cd "$(myHome)"/.ipfs/keystore && pwd -P)
    [ -n "$myIpfsKeystore" ] && echo "$myIpfsKeystore"
}

myIpfsPeerId() {
    myIpfsPeerId=$(jq -r .Identity.PeerID "$(myHome)"/.ipfs/config)
    [ -n "$myIpfsPeerId" ] && echo "$myIpfsPeerId"
}

myIpns() {
    [ -n "$(myIpfsKey)" ] \
     && myIpns="${myIPFS}/ipns/$(myIpfsKey)" \
     && echo "$myIpns"
}

myPath() {
    myPath=$(cd ~/.zen/game/players/ && pwd -P)
    [ -n "$myPath" ] && echo "$myPath"
}

myPlayer() {
    myPlayer=$(cat "$(myPath)"/.current/.player 2>/dev/null)
    [ -n "$myPlayer" ] && echo "$myPlayer"
}

myPlayerPath() {
    [ -n "$myPlayer" ] \
     && myPlayerPath=$(cd "$(myPath)"/"$(myPlayer)" && pwd -P)
     echo "$myPlayerPath"
}

myPlayerApi() {
    ipfs --api "$(cat "$(myPlayerPath)"/.ipfs/api )" swarm peers >/dev/null 2>&1 \
     && myPlayerApi=$(cat "$(myPlayerPath)"/.ipfs/api) \
     && echo "$myPlayerApi"
}

myPlayerBrowser() {
    myPlayerBrowser=$(xdg-settings get default-web-browser | cut -d '.' -f 1 | cut -d '-' -f 1)
    [ -n "$myPlayerBrowser" ] && echo "$myPlayerBrowser"
}

myPlayerFeedKey() {
    myPlayerFeedKey=$(ipfs --api "$(myPlayerApi)" key list -l | awk '$2 == "'"$(myPlayer)"'_feed" {print $1}')
     [ -n "$myPlayerFeedKey" ] && echo "$myPlayerFeedKey"
}

myPlayerG1Pub() {
    myPlayerG1Pub=$(cat "$(myPlayerPath)"/.g1pub 2>/dev/null)
    [ -n "$myPlayerG1Pub" ] && echo "$myPlayerG1Pub"
}

myPlayerKey() {
    myPlayerKey=$(ipfs --api "$(myPlayerApi)" key list -l | awk '$2 == "'"$(myPlayer)"'" {print $1}')
     [ -n "$myPlayerKey" ] && echo "$myPlayerKey"
}

myPlayerKeystore() {
    myPlayerKeystore=$(cd "$(myPlayerPath)"/.ipfs/keystore && pwd -P)
    [ -n "$myPlayerKeystore" ] && echo "$myPlayerKeystore"
}

myPlayerNs() {
    myPlayerNs=$(cat "$(myPlayerPath)"/.playerns 2>/dev/null)
    [ -n "$myPlayerNs" ] && echo "$myPlayerNs"
}

myPlayerPseudo() {
    myPlayerPseudo=$(cat "$(myPlayerPath)"/.pseudo 2>/dev/null)
    [ -n "$myPlayerPseudo" ] && echo "$myPseudo"
}

myTmpl() {
    myTmpl=$($RUN sed \
        -e "s~\"http://127.0.0.1:1234/\"~\"${myIPFS}/\"~g" \
        -e "s~\"http://127.0.0.1:1234\"~\"${myASTROPORT}\"~g" \
        -e "s~http://127.0.0.1:8080~${myIPFS}~g" \
        -e "s~http://127.0.0.1:12345~http://${myHOST}:12345~g" \
        -e "s~_IPFSNODEID_~${IPFSNODEID}~g" \
        -e "s~_HOSTNAME_~$(hostname)~g" \
        -e "s~.000.~.$(printf '%03d' "$(seq 0 17 |shuf -n 1)").~g" \
      ~/.zen/Astroport.ONE/templates/register.html)
    [ -n "$isLAN" ] \
     && myTmpl=$($RUN echo "$myTmpl" | sed \
      -e "s~<input type='"'hidden'"' name='"'salt'"' value='"'0'"'>~<input name='"'salt'"' value='"''"'>~g" \
      -e "s~<input type='"'hidden'"' name='"'pepper'"' value='"'0'"'>~<input name='"'pepper'"' value='"''"'>~g")
    [ -n "$myTmpl" ] && echo "$myTmpl"
}

myTs() {
    myTs=$(date -u +"%Y%m%d%H%M%S%4N")
    [ -n "$myTs" ] && echo "$myTs"
}

MOATS="$(myTs)"
IPFSNODEID="$(myIpfsPeerId)"
myIP="$(myIp)"
isLAN="$(isLan)"
myHOST="astroport.$(myDomainName)" \
myIPFS="http://ipfs.$(myDomainName):8080" \
myASTROPORT="http://astroport.$(myDomainName):1234"
## WAN STATION
[ -z "$isLAN" ] \
 && myHOST="astroport.$(myHostName)" \
 && myIPFS="https://ipfs.$(myDomainName)" \
 && myASTROPORT="https://astroport.$(myDomainName)"
