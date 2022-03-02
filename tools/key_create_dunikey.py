#!/usr/bin/env python3
# This Python script gets Duniter creddentials as arguments, and writes a PubSec file that should be compatible with Cesium and Silkaj(DuniterPy) clients.
# launch with :
# python3 key_create_dnuikey.py <id> <mdp>

# depends on duniterpy 0.56

### Licence - WTFPL
# This script was written my Matograine, in the hope that it will be helpful.
# Do What The Fuck you like with it. There is :
#  * no guarantee that this will work
#  * no support of any kind
#
# If this is helpful, please consider making a donation to the developper's pubkey : 78ZwwgpgdH5uLZLbThUQH7LKwPgjMunYfLiCfUCySkM8
# Have fun

from sys import argv
from duniterpy.key import SigningKey

# path to save to
path = "/tmp/secret.dunikey"

key = SigningKey.from_credentials(argv[1], argv[2], None)
key.save_pubsec_file(path)
print(
    key.pubkey,
)
