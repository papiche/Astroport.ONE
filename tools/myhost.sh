#!/bin/bash
set -eu

MY_PATH="$(pwd -P)" # absolute
ME="${0##*/}"

MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
IPFSNODEID=$(jq -r .Identity.PeerID ~/.ipfs/config)
myIP=$(hostname -I | awk '{print $1}' | head -n 1)
isLAN=$(route -n |awk '$1 == "0.0.0.0" {print $2}' | grep -E "/(^127\.)|(^192\.168\.)|(^10\.)|(^172\.1[6-9]\.)|(^172\.2[0-9]\.)|(^172\.3[0-1]\.)|(^::1$)|(^[fF][cCdD])/")

myDOMAINName=$(hostname -d 2>/dev/null) && [ -z "$myDOMAINName" ] && myDOMAINName=$(domainname 2>/dev/null) && [ "$myDOMAINName" = "(none)" ] && myDOMAINName="localhost"
myHOSTName=$(hostname |sed 's/\.'${myDOMAINName}'$//')
[ -n "$myDOMAINName" ] && myHOSTName="${myHOSTName}.${myDOMAINName}" || myDOMAINName=${myHOSTName#*.}
[ -z "$myDOMAINName" ] && myDOMAINName=localhost
myHOST="astroport.${myDOMAINName}"
myIPFS="http://ipfs.${myDOMAINName}:8080"
myASTROPORT="http://astroport.${myDOMAINName}:1234"

[ -z "$isLAN" ] && myIPFS="https://ipfs.${myDOMAINName}" && myASTROPORT="https://astroport.${myDOMAINName}" ||: ## WAN STATION
