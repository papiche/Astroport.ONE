#!/bin/bash
########################################################################
MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"
######## YOUTUBE-DL ##########
## NOW INSTALL yt-dlp AND LINK TO $HOME/.local/binyoutube-dl

if [[ ! -f $HOME/.local/bin/yt-dlp ]]; then
        curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o $HOME/.local/bin/yt-dlp

        ytdl=$(which youtube-dl) # modify old
        [[ -f ${ytdl} && ! -f ${ytdl}.old ]] \
            && cp ${ytdl} ${ytdl}.old \
            && rm ${ytdl}

        ln -s $HOME/.local/bin/yt-dlp $HOME/.local/bin/youtube-dl ##  NOW youtube-dl is linked to yt-dlp (COMMANDS ARE THE SAME)
fi

## UPGRADE TO LATEST
# ls -al $HOME/.local/bin/youtube-dl
