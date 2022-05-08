#!/bin/bash
# RESET PLAYERS FROM ASTROPORT !!
# USED FOR DEV MOD
#
#_____ REINIT COMMAND____

for p in $(ls ~/.zen/game/players/); do rm -Rf ~/.zen/game/players/$p
for k in $(ipfs key list | grep $p); do ipfs key rm $k; done; done

# Todo
echo "
RESTAURER ANCIENNE CONFIG IPFS
~/.ipfs/keystore.astrXbian
~/.ipfs/config.astrXbian"


#_____ALL PLAYERS REMOVAL____

