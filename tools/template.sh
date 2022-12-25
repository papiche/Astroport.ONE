#shellcheck shell=sh

template_register() {
  sed -e "s~http://127.0.0.1:1234~${myASTROPORT}~g" \
      -e "s~http://127.0.0.1:8080~${myIPFS}~g" \
      -e "s~_IPFSNODEID_~${IPFSNODEID}~g" \
      -e "s~_HOSTNAME_~$(hostname)~g" \
      -e "s~.000.~.$(printf '%03d' $(seq 0 17 |shuf -n 1)).~g" \
    ~/.zen/Astroport.ONE/templates/register.html
}
