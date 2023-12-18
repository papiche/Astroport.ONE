#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.2
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "$MY_PATH/my.sh"
################################################################################

PLAYER="$1"
[[ ! -s ~/.zen/game/players/${PLAYER}/secret.dunikey ]] && PLAYER=".current"

if [[ ! -s ~/.zen/game/players/${PLAYER}/private_color.png ]]; then
    PUBKEY=$(cat ~/.zen/game/players/${PLAYER}/secret.dunikey | grep 'pub:' | cut -d ' ' -f 2)
    SECKEY=$(cat ~/.zen/game/players/${PLAYER}/secret.dunikey | grep 'sec:' | cut -d ' ' -f 2)

    DESTMAIL="$2"

    # Convert the public key to a color (hexadecimal representation)
    color_hex=$(echo -n ${SECKEY} | sha256sum | awk '{print $1}')

    # Ensure the color is 6 characters long (for RGB)
    color_hex=${color_hex:0:6}
    echo "Color Hex: #$color_hex"

    # Convert the color to an Image
    convert -size 100x100 xc:"#${color_hex}" ~/.zen/game/players/${PLAYER}/private_color.png
fi

# Choosing IPFSNODEID Base Color
color_hex=$(echo -n ${IPFSNODEID} | sha256sum | awk '{print $1}')
color_hex=${color_hex:0:6}
convert -size 100x100 xc:"#${color_hex}" ~/.zen/base_white.png

# Step 3: Mixing Colors
composite -compose Multiply ~/.zen/tmp/base_white.png \
                                                        ~/.zen/game/players/${PLAYER}/private_color.png \
                                                        ~/.zen/tmp/mixed_color.png

xdg-open ~/.zen/tmp/mixed_color.png

echo "Sharing 'mixed_color.png' on ipfs pubsub channel"

# Step 4: Exchange Mixed Colors using IPFS pubsub
ipfs_pubsub_channel="diffie_hellman_colors_channel"

ipfs_pubsub_pub_cmd="ipfs pubsub pub $ipfs_pubsub_channel"
ipfs_pubsub_sub_cmd="ipfs pubsub sub $ipfs_pubsub_channel"

$ipfs_pubsub_pub_cmd < ~/.zen/tmp/mixed_color.png

# Wait for Bob to publish his mixed color
echo "Waiting for Other to publish his mixed color..."
mixed_bob_ipfs=$(eval $ipfs_pubsub_sub_cmd)
echo "Received Bob's mixed color from IPFS pubsub."

# Save Bob's mixed color to a file
echo "$mixed_bob_ipfs" > ~/.zen/tmp/mixed_bob_from_ipfs.png

# Step 5: Final Color Agreement
composite -compose Multiply ~/.zen/tmp/mixed_bob_from_ipfs.png \
                                                        ~/.zen/game/players/${PLAYER}/private_color.png \
                                                         ~/.zen/tmp/shared_secret.png

echo "Completed. You have a ~/.zen/tmp/shared_secret.png"
xdg-open ~/.zen/tmp/shared_secret.png
