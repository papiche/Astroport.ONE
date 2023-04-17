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
    ## NOT WORKING
rm ~/.local/share/nemo/actions/add2ipfs.nemo_action ## REMOVE WHEN WORKING
if [[ ! -s ~/.local/share/nemo/actions/add2ipfs.nemo_action ]]; then
    echo '[Nemo Action]
Name=Add To IPFS
Comment=Adding %f to IPFS (TODO: make it work into speak.sh script)
Exec=/usr/local/bin/ipfs add -rw %F | xargs -L1 -I %  /usr/bin/zenity --width=250 --height=250 --info --text=%
Selection=s
Extensions=any;
EscapeSpaces=true' > ~/.local/share/nemo/actions/add2ipfs.nemo_action
fi
###################################################

exit 0
