#shellcheck shell=sh

myHash() {
	[ -f ~/.zen/game/players/localhost/latest ] \
	 && myHash=$(cat ~/.zen/game/players/localhost/latest) \
	 || myHash=$(template_register |ipfs add -q)
	[ ! -f ~/.zen/game/players/localhost/latest ] \
	 && echo "$myHash" > ~/.zen/game/players/localhost/latest
	[ -n "$myHash" ] && echo "$myHash"
}

myHttp() {
	[ -n "$(myHttpHeader)" ] \
	 && echo "${myHttpHeader}" \
	 && echo
	[ -n "$(myHttpContent)" ] \
	 && echo "${myHttpContent}"
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
set-cookie: AND=$(myKey); expires=$(date -R -d "+1 month"); path=/; domain=.$myDomainName; Secure; SameSite=lax"
	[ -n "$myHttpHeader" ] && echo "$myHttpHeader"
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
