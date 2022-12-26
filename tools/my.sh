#shellcheck shell=sh

ipfsNodeId() {
	ipfsNodeId=$(jq -r .Identity.PeerID ~/.ipfs/config)
	[ -n "$ipfsNodeId" ] && echo "$ipfsNodeId"
}

isLan() {
	isLan=$(ip route |awk '$1 == "default" {print $3}' | grep -E "/(^127\.)|(^192\.168\.)|(^10\.)|(^172\.1[6-9]\.)|(^172\.2[0-9]\.)|(^172\.3[0-1]\.)|(^::1$)|(^[fF][cCdD])/" \
	     || route -n |awk '$1 == "0.0.0.0" {print $2}' | grep -E "/(^127\.)|(^192\.168\.)|(^10\.)|(^172\.1[6-9]\.)|(^172\.2[0-9]\.)|(^172\.3[0-1]\.)|(^::1$)|(^[fF][cCdD])/")
	[ -n "$isLan" ] && echo "$isLan"
} 2>/dev/null

myDomainName() {
	myDomainName=$(hostname -d 2>/dev/null) && [ -z "$myDomainName" ] && myDomainName=$(domainname 2>/dev/null) && [ "$myDomainName" = "(none)" ] && myDomainName="localhost"
	[ -n "$myDomainName" ] && echo "$myDomainName"
}

myHash() {
	[ -f ~/.zen/game/players/localhost/latest ] \
	 && myHash=$(cat ~/.zen/game/players/localhost/latest) \
	 || myHash=$(myTmpl |ipfs add -q)
	[ ! -f ~/.zen/game/players/localhost/latest ] \
	 && echo "$myHash" > ~/.zen/game/players/localhost/latest
	[ -n "$myHash" ] && echo "$myHash"
}

myHttp() {
	[ -n "$(myHttpHeader)" ] \
	 && myHttp="$(myHttpHeader)" \
	 && myHttp+="

" \
         || myHttp=""
	[ -n "$(myHttpContent)" ] \
	 && myHttp+="$(myHttpContent)"
	[ -n "$myHttp" ] \
	 && echo "$myHttp"
}

myHttpContent() {
	[ -n "$(myHash)" ] \
	 && myHttpContent="<html><head><title>302 Found</title></head><body><h1>Found</h1>
<p>The document is <a href=\""ipfs/$(myHash)"\">here</a> in IPFS.</p></body></html>" \
	 && echo "$myHttpContent"
}

myHttpHeader() {
	[ -n "$(myHash)" ] \
	 && myHttpHeader="HTTP/1.0 302 Found
Content-Type: text/html; charset=UTF-8
Content-Length: $(myHttpContent |wc -c)
Date: $(date -R)
Location: ipfs/$(myHash)
Server: and"
	[ -n "$(myKey)" ] && myHttpHeader+="
set-cookie: AND=$(myKey); expires=$(date -R -d "+1 month"); path=/; domain=.$(myDomainName); Secure; SameSite=lax"
	[ -n "$myHttpHeader" ] && echo "$myHttpHeader"
}

myHostName() {
	myHostName=$(hostname |sed 's/\.'$(myDomainName)'$//')
	[ -n "$(myDomainName)" ] && myHostName="${myHostName}.$(myDomainName)" || myDomainName=${myHostName#*.}
	[ -z "$(myDomainName)" ] && myDomainName=localhost
	[ -n "$myHostName" ] && echo "$myHostName"
}

myIp() {
	myIp=$(hostname -I | awk '{print $1}' | head -n 1)
	[ -n "$myIp" ] && echo "$myIp"
}

myIpfs() {
	[ -n "$(myHash)" ] \
	 && myIpfs="${myIPFS}/ipfs/$(myHash)" \
	 && echo "$myIpfs"
}

myIpns() {
	[ -n "$(myKey)" ] \
	 && myIpns="${myIPFS}/ipns/${myKey}" \
	 && echo "$myIpns"
}

myKey() {
	myKey=$(ipfs key list -l | awk '$2 == "self" {print $1}')
	[ -n "$myKey" ] && echo "$myKey"
}

myPath() {
	myPath=$(cd "$(dirname \"$0\")" 2>/dev/null && pwd -P)
	[ -n "$myPath" ] && echo "$myPath"
}

myTmpl() {
	[ -n "$isLAN" ] \
	 && SED_SCRIPT='sed -e "s~<input type='"'hidden'"' name='"'salt'"' value='"'0'"'>~<input name='"'salt'"' value='"''"'>~g"
	                    -e "s~<input type='"'hidden'"' name='"'pepper'"' value='"'0'"'>~<input name='"'pepper'"' value='"''"'>~g"' \
	 || SED_SCRIPT='tee'
	myTmpl=$($RUN sed \
	    -e "s~\"http://127.0.0.1:1234/\"~\"${myIPFS}/\"~g" \
	    -e "s~\"http://127.0.0.1:1234\"~\"${myASTROPORT}\"~g" \
	    -e "s~http://127.0.0.1:8080~${myIPFS}~g" \
	    -e "s~http://127.0.0.1:12345~http://${myHOST}:12345~g" \
	    -e "s~_IPFSNODEID_~${IPFSNODEID}~g" \
	    -e "s~_HOSTNAME_~$(hostname)~g" \
	    -e "s~.000.~.$(printf '%03d' $(seq 0 17 |shuf -n 1)).~g" \
	    ~/.zen/Astroport.ONE/templates/register.html | \
	    eval ${SED_SCRIPT:-tee})
	[ -n "$myTmpl" ] && echo "$myTmpl"
}

myTs() {
	myTs=$(date -u +"%Y%m%d%H%M%S%4N")
	[ -n "$myTs" ] && echo "$myTs"
}

[ -n "$(myTs)" ] && MOATS="${myTs}"
[ -n "$(ipfsNodeId)" ] && IPFSNODEID="${ipfsNodeId}"
[ -n "$(myIp)" ] && myIP="${myIp}"
[ -n "$(isLan)" ] && isLAN="${isLan}"
[ -n "$(myDomainName)" ] \
 && myHOST="astroport.${myDomainName}" \
 && myIPFS="http://ipfs.${myDomainName}:8080" \
 && myASTROPORT="http://astroport.${myDomainName}:1234"
## WAN STATION
[ -n "$(myHostName)" ] && [ -z "$isLAN" ] \
 && myHOST="astroport.${myHostName}" \
 && myIPFS="https://ipfs.${myDomainName}" \
 && myASTROPORT="https://astroport.${myDomainName}"
