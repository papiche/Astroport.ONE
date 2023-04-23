#!/bin/bash
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"
########################################################################
######## https://discuss.ipfs.tech/t/how-to-add-a-file-to-ipfs-with-a-right-clic-in-your-file-manager/16294 ##########
########################################################################

if [[ $(which nemo) && -d ~/.local/share/nemo/actions/ ]]; then

    echo '[Nemo Action]
Name=Add to IPFS
Comment=Adding %f to IPFS
Exec=sh -c "/usr/local/bin/ipfs add -q %F | xargs -L1 -I %  /usr/bin/zenity --width=300 --height=100 --info --text=%"
Selection=s
Extensions=nodirs;
Quote=double
EscapeSpaces=true' > ~/.local/share/nemo/actions/add2ipfs.nemo_action

fi

exit 0
