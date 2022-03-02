#!/bin/bash
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"
######## YOUTUBE-DL ##########
if [[ $(which youtube-dl) ]]; then
    sudo apt-get remove youtube-dl
fi
    sudo wget https://yt-dl.org/downloads/latest/youtube-dl -O /usr/local/bin/youtube-dl || sudo cp $MY_PATH/youtube-dl /usr/local/bin/ || (echo "error installing youtube-dl" && exit 1)
    sudo chmod a+rx /usr/local/bin/youtube-dl
    sudo chown $USER /usr/local/bin/youtube-dl
    youtube-dl -U

