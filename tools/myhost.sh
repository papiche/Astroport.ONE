#shellcheck shell=sh

MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
IPFSNODEID=$(jq -r .Identity.PeerID ~/.ipfs/config)
myIP=$(hostname -I | awk '{print $1}' | head -n 1)
isLAN=$(route -n |awk '$1 == "0.0.0.0" {print $2}' | grep -E "/(^127\.)|(^192\.168\.)|(^10\.)|(^172\.1[6-9]\.)|(^172\.2[0-9]\.)|(^172\.3[0-1]\.)|(^::1$)|(^[fF][cCdD])/")

myDomainName=$(hostname -d 2>/dev/null) && [ -z "$myDomainName" ] && myDomainName=$(domainname 2>/dev/null) && [ "$myDomainName" = "(none)" ] && myDomainName="localhost"
myHostName=$(hostname |sed 's/\.'${myDomainName}'$//')
[ -n "$myDomainName" ] && myHostName="${myHostName}.${myDomainName}" || myDomainName=${myHostName#*.}
[ -z "$myDomainName" ] && myDomainName=localhost
myHOST="astroport.${myDomainName}"
myIPFS="http://ipfs.${myDomainName}:8080"
myASTROPORT="http://astroport.${myDomainName}:1234"

[ -z "$isLAN" ] && myIPFS="https://ipfs.${myDomainName}" && myASTROPORT="https://astroport.${myDomainName}" ||: ## WAN STATION
