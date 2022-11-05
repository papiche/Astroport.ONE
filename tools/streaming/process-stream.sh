#!/usr/bin/env bash

HLS_TIME=40
M3U8_SIZE=3
IPFS_GATEWAY="http://127.0.0.1:8080"

echo "Astroport stream is playing on star_1 : https://tube.copylaradio.com/ipns/$(ipfs key list -l | grep star_1 | cut -d ' ' -f 1)"

# Load settings

# Prepare Pi Camera
# sudo modprobe bcm2835-v4l2
# sudo v4l2-ctl --set-ctrl video_bitrate=100000

function startFFmpeg() {
  while true; do
    mv /tmp/ffmpeg.log /tmp/ffmpeg.1
    echo 1 > /tmp/stream-reset

    # Stream WebCamera
    #ffmpeg -f pulse -i 1 -f video4linux2 -video_size 1280x720 -framerate 25 -i /dev/video0 -hls_time "${HLS_TIME}" "${what}.m3u8" > /tmp/ffmpeg.log 2>&1
    ffmpeg -f pulse -i 1 -f video4linux2 -video_size 720x480 -framerate 25 -i /dev/video0 -hls_time "${HLS_TIME}" "${what}.m3u8" > /tmp/ffmpeg.log 2>&1

    ## MORE SOURCES
    # http://4youngpadawans.com/stream-camera-video-and-audio-with-ffmpeg/
    ## STILL BAD :: ffmpeg -f v4l2 -i /dev/video0 -f alsa -i hw:0 -profile:v high -pix_fmt yuvj420p -level:v 4.1 -preset ultrafast -tune zerolatency -vcodec libx264 -r 10 -b:v 512k -s 640x360 -acodec aac -strict -2 -ac 2 -ab 32k -ar 44100 -f mpegts -flush_packets 0 -hls_time "${HLS_TIME}" "${what}.m3u8" > /tmp/ffmpeg.log 2>&1
    ################ GOOD ?
    # Stream FM Station from a SDR module (see contrib/pi-stream to install drivers)
    # Frequency ends in M IE 99.9M
    # rtl_fm  -f 99.9M -M fm -s 170k -A std -l0 -E deemp -r 44.1k | ffmpeg  -r 15 -loop 1 -i ../audio.jpg  -f s16le -ac 1 -i pipe:0 -c:v libx264 -tune stillimage -preset ultrafast  -hls_time "${HLS_TIME}" "${what}.m3u8"  > /tmp/ffmpeg 2>&1

    sleep 0.5
  done
}

# Create directory for HLS content

currentpath="$HOME/live"
sudo umount "${currentpath}"
rm -rf "${currentpath}"
mkdir "${currentpath}"
sudo mount -t tmpfs tmpfs "${currentpath}"
# shellcheck disable=SC2164
cd "${currentpath}"

what="$(date +%Y%m%d%H%M)-LIVE"
echo "STARTING $what"

# Start ffmpeg in background
startFFmpeg &

while true; do
#TODO# Fix this one
# shellcheck disable=SC2086,SC2012
  nextfile=$(ls -tr ${what}*.ts 2>/dev/null | head -n 1)

  if [ -n "${nextfile}" ]; then
    # Check if the next file on the list is still being written to by ffmpeg
    if lsof "${nextfile}" | grep -1 ffmpeg; then
      # Wait for file to finish writing
      # If not finished in 45 seconds something is wrong, timeout
      inotifywait -e close_write "${nextfile}" -t ${HLS_TIME}
    fi

    # Grab the timecode from the m3u8 file so we can add it to the log
    timecode=$(grep -B1 "${nextfile}" "${what}.m3u8" | head -n1 | awk -F : '{print $2}' | tr -d ,)
    attempts=5
    until [[ "${timecode}" || ${attempts} -eq 0 ]]; do
      # Wait and retry
      sleep 0.5
      timecode=$(grep -B1 "${nextfile}" "${what}.m3u8" | head -n1 | awk -F : '{print $2}' | tr -d ,)
      attempts=$((attempts-1))
    done

    if ! [[ "${timecode}" ]]; then
      # Set approximate timecode
      timecode="${HLS_TIME}.000000"
    fi

    reset_stream=$(cat /tmp/stream-reset)
    reset_stream_marker=''
    if [[ ${reset_stream} -eq '1' ]]; then
      reset_stream_marker=" #EXT-X-DISCONTINUITY"
    fi

    echo 0 > /tmp/stream-reset
    # Current UTC date for the log
    time=$(date "+%F-%H-%M-%S")

    echo "Add ts file to IPFS"
    ret=$(ipfs add --pin=false "${nextfile}" 2>/dev/null > /tmp/tmp.txt; echo $?)
    attempts=5
    until [[ ${ret} -eq 0 || ${attempts} -eq 0 ]]; do
      # Wait and retry
      sleep 0.5
      ret=$(ipfs add --pin=false "${nextfile}" 2>/dev/null > /tmp/tmp.txt; echo $?)
      echo "$attempts RETRY"
      attempts=$((attempts-1))
    done
    if [[ ${ret} -eq 0 ]]; then
      # Update the log with the future name (hash already there)
      echo "$(cat /tmp/tmp.txt) ${time}.ts ${timecode}${reset_stream_marker}" >> /tmp/process-stream.log

      # Remove nextfile and tmp.txt
      rm -f "${nextfile}" /tmp/tmp.txt

      # Write the m3u8 file with the new IPFS hashes from the log
      totalLines="$(wc -l /tmp/process-stream.log | awk '{print $1}')"

      sequence=0
      if ((totalLines>M3U8_SIZE)); then
          sequence=$((totalLines-M3U8_SIZE))
      fi
      {
        echo "#EXTM3U"
        echo "#EXT-X-VERSION:3"
        echo "#EXT-X-TARGETDURATION:${HLS_TIME}"
        echo "#EXT-X-MEDIA-SEQUENCE:${sequence}"
      }  > current.m3u8
      tail -n ${M3U8_SIZE} /tmp/process-stream.log | awk '{print $6"#EXTINF:"$5",\n'${IPFS_GATEWAY}'/ipfs/"$2}' | sed 's/#EXT-X-DISCONTINUITY#/#EXT-X-DISCONTINUITY\n#/g' >> current.m3u8

      echo 'Add m3u8 file to IPFS and IPNS publish'
      m3u8hash=$(ipfs add current.m3u8 | awk '{print $2}')
      ipfs name publish --key='star_1' --timeout=5s "${m3u8hash}" &

      # Copy files to web server
      cat current.m3u8
      # cp current.m3u8 /var/www/html/live.m3u8
      # cp /tmp/process-stream.log /var/www/html/live.log
    fi
  else
    sleep 5
  fi
done
