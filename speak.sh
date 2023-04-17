#!/bin/bash
## TURN ON & OFF espeak
# TODO CHANGE PROG  LINK

    PROG=$(which espeak)

if [[ $1 == "OFF" ]]; then

    espeak "SHUT UP NOW"

    [[ ! $PROG == "$HOME/.local/bin/espeak" ]] \
    && echo '#!/bin/bash' > $HOME/.local/bin/espeak \
    && chmod +x $HOME/.local/bin/espeak


fi

if [[ $1 == "ON" || $1 == "" ]]; then

    [[ ! $PROG == "/usr/bin/espeak" ]] \
    && rm $HOME/.local/bin/espeak

    espeak "TALKING NOW"

fi

##########################################################
## TRYING TO ADD Add To IPFS Nemo right click action
## https://discuss.ipfs.tech/t/how-to-add-a-file-to-ipfs-with-a-right-clic-in-your-file-manager/16294/1
# Exec=sh -c "/usr/local/bin/ipfs add -q %F | xclip -selection c"
if [[ -d ~/.local/share/nemo/actions ]]; then

echo '[Nemo Action]
Name=+ to IPFS
Comment=Adding %f to IPFS
Exec=sh -c "/usr/local/bin/ipfs add -q %F | xargs -L1 -I %  /usr/bin/zenity --width=300 --height=100 --info --text=%"
Selection=s
Extensions=nodirs;
Quote=double
EscapeSpaces=true' > ~/.local/share/nemo/actions/add2ipfs.nemo_action

fi
###################################################

exit 0
