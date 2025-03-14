#!/usr/bin/env bash
########################################################################
exit 0

########################################################################
### REWRITE NEEDED
########################################################################
set -e

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Enable camera on the Raspberry Pi
# sudo "$BASE_DIR/enable-camera.sh"

# Install ffmpeg and supporting tools
sudo apt-get install -y ffmpeg lsof inotify-tools nginx

# Copy placeholder for audio-only streams
cp "$BASE_DIR/audio.jpg" "$HOME/audio.jpg"

# Add user to be able to modify nginx directories
sudo usermod -a -G "$USER" www-data
sudo chmod g+rw /var/www/html

# TODO: why is this needed?
sudo chmod a+rw /var/www/html

sudo cp -f "$BASE_DIR/process-stream.sh" /usr/bin/process-stream.sh
sudo cp -f "$BASE_DIR/process-stream.service" /etc/systemd/system/process-stream.service
sudo systemctl daemon-reload
sudo systemctl enable process-stream



# Add hourly job to clear out old data
# echo "41 * * * * $USER /usr/local/bin/ipfs repo gc" | sudo tee --append /etc/crontab

# Install the ipfs video player
mkdir "$BASE_DIR/tmp"
current_dir="$(pwd)"

git clone https://github.com/tomeshnet/ipfs-live-streaming.git "$BASE_DIR/tmp/ipfs-live-streaming"
cd "$BASE_DIR/tmp/ipfs-live-streaming"
git checkout b9be352582317e5336ddd7183ecf49042dafb33e
cd "$current_dir"

VIDEO_PLAYER_PATH="$BASE_DIR/tmp/ipfs-live-streaming/terraform/shared/video-player"
sed -i s#__IPFS_GATEWAY_SELF__#/ipfs/# "$VIDEO_PLAYER_PATH/js/common.js"
sed -i s#__IPFS_GATEWAY_ORIGIN__#https://ipfs.io/ipfs/# "$VIDEO_PLAYER_PATH/js/common.js"
IPFS_ID=$(ipfs id | grep ID | head -n 1 | awk -F\" '{print $4}')
sed -i "s#live.m3u8#/ipns/$IPFS_ID#" "$VIDEO_PLAYER_PATH/js/common.js"
sed -i s#__M3U8_HTTP_URLS__#\ # "$VIDEO_PLAYER_PATH/js/common.js"
cp -r "$VIDEO_PLAYER_PATH" /var/www/html/video-player
rm -rf "$BASE_DIR/tmp"

# Add entry into nginx home screen
APP="<div class='app'><h2>IPFS Pi Stream Player</h2>IPFS Video player for Pi Stream. <br />M3U8 Stream located <a href='/ipns/$IPFS_ID'>over ipns</a> <br/><a href='/video-player/'>Go </a> and play with built in video player</div>"
sudo sed -i "s#<\!--APPLIST-->#$APP\n<\!--APPLIST-->#" "/var/www/html/index.html"

## ACTIVATE nginx rtmp
# GUIDES
# https://bartsimons.me/nginx-rtmp-streaming-server-installation-guide/
# https://blog.100tb.com/how-to-set-up-an-rtmp-server-on-ubuntu-linux-using-nginx
# https://obsproject.com/forum/resources/how-to-set-up-your-own-private-rtmp-server-using-nginx.50/
# https://www.hostwinds.com/guide/live-streaming-from-a-vps-with-nginx-rtmp/
# CONFIG
# https://github.com/arut/nginx-rtmp-module/wiki/Directives
# https://github.com/arut/nginx-rtmp-module/wiki/Directives#hls_variant
printf "
rtmp {
    server {
        listen 1935;
        chunk_size 8192;

        application vod {

            play $HOME/live;

        }
        
        application stream {
            live on;
            record off;

            allow publish 127.0.0.1;
            deny publish all;
            allow play all;
        }
        
        application src {
			live on;
			exec_push ffmpeg -i rtmp://localhost/src/$name -vcodec libx264 -vprofile baseline -g 10 -s 300x200 -acodec aac -ar 44100 -ac 1 -f flv rtmp://localhost/hls/$name 2>>/var/log/ffmpeg-$name.log;
		}
    }
}
" | sudo tee -a /etc/nginx/nginx.conf
