#shellcheck shell=sh

myHash() {
	[ -f ~/.zen/game/players/localhost/latest ] \
	 && myHash=$(cat ~/.zen/game/players/localhost/latest) \
	 || myHash=$(template_register |ipfs add -q)
	[ ! -f ~/.zen/game/players/localhost/latest ] \
	 && echo "$myHash" > ~/.zen/game/players/localhost/latest
	[ -n "$myHash" ] \
	 && echo "$myHash"
}

myHttp() {
	echo "$(myHttpHeader)"
	echo
	echo "$(myHttpContent)"
}

myIpfs() {
	myIpfs=${myIPFS}/ipfs/$(myHash)
	echo "$myIpfs"
}

myIpns() {
	myIpns=${myIPFS}/ipns/$(myKey)
	echo "$myIpns"
}

myKey() {
	myKey=$(ipfs key list -l | awk '$2 == "self" {print $1}')
	[ -n "$myKey" ] && echo "$myKey"
}

myHttpContent() {
	myHash=$(myHash)
	myHttpContent="<html><head><title>302 Found</title></head><body><h1>Found</h1>
<p>The document has moved <a href="ipfs/$myHash">here</a>.</p></body></html>"
	echo "$myHttpContent"
}

myHttpHeader() {
	myHttpContent=$(myHttpContent)
	myHttpHeader="HTTP/1.0 302 Found
Content-Type: text/html; charset=UTF-8
Content-Length: $(myHttpContent |wc -c)
Date: $(date -R)
Location: ipfs/$myHash
set-cookie: AND=$myKey; expires=$(date -R -d "+1 month"); path=/; domain=.$myDomainName; Secure; SameSite=lax
Server: and"
	echo "$myHttpHeader"
}
