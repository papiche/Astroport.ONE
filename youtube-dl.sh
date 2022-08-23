#!/bin/bash
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"
######## YOUTUBE-DL ##########
## NOW INSTALL yt-dlp AND LINK TO youtube-dl

if [[ ! -f /usr/local/bin/yt-dlp ]]; then
        sudo curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp && \
        sudo chmod a+rx /usr/local/bin/yt-dlp && sudo chown $USER /usr/local/bin/yt-dlp

        ytdl=$(which youtube-dl) # modify old
        [[ -f ${ytdl} && ! -f ${ytdl}.old ]] &&\
            sudo cp ${ytdl} ${ytdl}.old && \
            sudo rm ${ytdl}

        sudo ln -s /usr/local/bin/yt-dlp /usr/local/bin/youtube-dl ##  NOW youtube-dl is linked to yt-dlp (COMMANDS ARE THE SAME ?)
fi

## UPGRADE TO LATEST
ls -al /usr/local/bin/youtube-dl
