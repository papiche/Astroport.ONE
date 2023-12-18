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
## Mélange de peintures et création d’un secret partagé (Diffie-Hellman)
# https://www.youtube.com/watch?v=F4Bbd0wjxSE

function get_hex_code_from_image() {
    local image_path=$1
    # Use identify to get the average color of the image
    average_color=$(convert "$image_path" -format "%[pixel:s]\n" info: | head -n 1)
    # Extract RGB values and convert to hex
    hex_code=$(printf "#%02x%02x%02x\n" \
        $(echo $average_color | sed 's/.*(\([0-9]\+\),\([0-9]\+\),\([0-9]\+\)).*/\1 \2 \3/'))

    echo "$hex_code"
}

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
convert -size 100x100 xc:"#${color_hex}" ~/.zen/tmp/base_white.png
echo "Base Hex: #$color_hex"
get_hex_code_from_image ~/.zen/tmp/base_white.png

# Step 3: Mixing Colors
composite -compose Multiply ~/.zen/tmp/base_white.png \
                                                        ~/.zen/game/players/${PLAYER}/private_color.png \
                                                        ~/.zen/tmp/mixed_color.png

xdg-open ~/.zen/tmp/mixed_color.png
get_hex_code_from_image ~/.zen/tmp/mixed_color.png

echo "WAITING FOR ANOTHER mixed_color to reveal our shared secret"
# Final Color Agreement
#~ composite -compose Multiply ~/.zen/tmp/input_mixed_color.png \
                                                        #~ ~/.zen/game/players/${PLAYER}/private_color.png \
                                                         #~ ~/.zen/tmp/shared_secret.png
