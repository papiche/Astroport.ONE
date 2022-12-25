#shellcheck shell=sh

template_register() {
	[ -n "$isLAN" ] \
	 && SED_SCRIPT='sed -e "s~<input type='"'hidden'"' name='"'salt'"' value='"'0'"'>~<input name='"'salt'"' value='"''"'>~g"
	                    -e "s~<input type='"'hidden'"' name='"'pepper'"' value='"'0'"'>~<input name='"'pepper'"' value='"''"'>~g"' \
	 || SED_SCRIPT='tee'
	$RUN sed \
	    -e "s~\"http://127.0.0.1:1234/\"~\"${myIPFS}/\"~g" \
	    -e "s~\"http://127.0.0.1:1234\"~\"${myASTROPORT}\"~g" \
	    -e "s~http://127.0.0.1:8080~${myIPFS}~g" \
	    -e "s~http://127.0.0.1:12345~http://${myHOST}:12345~g" \
	    -e "s~_IPFSNODEID_~${IPFSNODEID}~g" \
	    -e "s~_HOSTNAME_~$(hostname)~g" \
	    -e "s~.000.~.$(printf '%03d' $(seq 0 17 |shuf -n 1)).~g" \
	    ~/.zen/Astroport.ONE/templates/register.html | \
	  eval ${SED_SCRIPT:-tee}
}

