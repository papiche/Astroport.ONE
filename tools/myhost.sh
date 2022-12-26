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
	[ -n "$myDomainName" ] && echo "$myDomainNane"
}

myHostName() {
	myHostName=$(hostname |sed 's/\.'$(myDomainName)'$//')
	[ -n "$myDomainName" ] && myHostName="${myHostName}.${myDomainName}" || myDomainName=${myHostName#*.}
	[ -z "$myDomainName" ] && myDomainName=localhost
	[ -n "$myHostName" ] && echo "$myHostName"
}

myIp() {
	myIp=$(hostname -I | awk '{print $1}' | head -n 1)
	[ -n "$myIp" ] && echo "$myIp"
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
