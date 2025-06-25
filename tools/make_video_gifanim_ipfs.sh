#!/bin/bash
## Create gifanime ##  TODO Search for similarities BEFORE ADD
## "(✜‿‿✜) GIFANIME $PROBETIME (✜‿‿✜)"
# FORMAT MP4 max 720p
# PHI GIFANIM CREATION

# Help function
show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] <path> <file>

Create animated GIF from video file and upload to IPFS.

OPTIONS:
    -h, --help          Show this help message and exit
    -v, --verbose       Enable verbose output
    -d, --debug         Enable debug mode with detailed logging

PARAMETERS:
    path                Directory path containing the video file
    file                Video filename to process

EXAMPLES:
    $(basename "$0") /path/to/videos/ my_video.mp4
    $(basename "$0") -v /home/user/videos/ sample.avi

DESCRIPTION:
    This script processes video files to create animated GIFs and uploads them to IPFS.
    It automatically converts non-MP4 videos to MP4 format and resizes videos larger than 720p.
    The script creates a GIF animation from a 1.6-second segment starting at Phi ratio of the video duration.

REQUIREMENTS:
    - ffmpeg (for video processing)
    - ffprobe (for video metadata)
    - ipfs (for IPFS operations)
    - bc (for calculations)

EXIT CODES:
    0 - Success
    1 - File not found or invalid parameters
    2 - Missing required tools (ffmpeg, ffprobe, ipfs)
    3 - Processing error

EOF
}

# Parse command line arguments
VERBOSE=0
DEBUG=0

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=1
            shift
            ;;
        -d|--debug)
            DEBUG=1
            VERBOSE=1
            shift
            ;;
        -*)
            echo "Error: Unknown option $1" >&2
            echo "Use --help for usage information" >&2
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

# Check if we have the required number of arguments
if [[ $# -ne 2 ]]; then
    echo "Error: Invalid number of arguments" >&2
    echo "Usage: $(basename "$0") [OPTIONS] <path> <file>" >&2
    echo "Use --help for more information" >&2
    exit 1
fi

# Check for required tools
check_requirements() {
    local missing_tools=()
    
    if ! command -v ffmpeg &> /dev/null; then
        missing_tools+=("ffmpeg")
    fi
    
    if ! command -v ffprobe &> /dev/null; then
        missing_tools+=("ffprobe")
    fi
    
    if ! command -v ipfs &> /dev/null; then
        missing_tools+=("ipfs")
    fi
    
    if ! command -v bc &> /dev/null; then
        missing_tools+=("bc")
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        echo "Error: Missing required tools: ${missing_tools[*]}" >&2
        echo "Please install the missing tools and try again." >&2
        exit 2
    fi
}

# Validate input parameters
validate_input() {
    local path="$1"
    local file="$2"
    
    # Check if path exists and is a directory
    if [[ ! -d "$path" ]]; then
        echo "Error: Path '$path' does not exist or is not a directory" >&2
        exit 1
    fi
    
    # Check if file exists in the path
    if [[ ! -f "${path}${file}" ]]; then
        echo "Error: File '${path}${file}' does not exist" >&2
        exit 1
    fi
    
    # Check if file is readable
    if [[ ! -r "${path}${file}" ]]; then
        echo "Error: File '${path}${file}' is not readable" >&2
        exit 1
    fi
    
    # Check if file has content
    if [[ ! -s "${path}${file}" ]]; then
        echo "Error: File '${path}${file}' is empty" >&2
        exit 1
    fi
}

# Check requirements and validate input
check_requirements
validate_input "$1" "$2"

# Set up logging if debug mode is enabled
if [[ $DEBUG -eq 1 ]]; then
    exec 2>&1 >> ~/.zen/tmp/ajouter_media.log
fi

export HOP
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
path="$1"
file="$2"

length=${#path}
last_char=${path:length-1:1}
[[ $last_char != "/" ]] && path="$path/"; :
[[ ! -s "${path}${file}" ]] && echo "Nothing Found, please check \"${path}${file}\"" && exit 1

MIME=$(file --mime-type -b "${path}${file}")
HOP=0
#################################################################################################################
############# CONVERT NOT MP4
[[ ! $MIME == "video/mp4"  ]] \
    && echo "MP4 CONVERSION PLEASE WAIT" \
    && ffmpeg -loglevel error -i "${path}${file}" -c:v libx264 -c:a aac "${path}${file}.mp4" \
    && [[ -s "${path}${file}.mp4" ]] && rm "${path}${file}" \
    && file="${file}.mp4"  && extension="mp4" \
    && MIME=$(file --mime-type -b "${path}${file}") && HOP=1

# Utiliser ffprobe pour obtenir les dimensions de la vidéo
FILE_RES=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "${path}${file}")

# Extraire les valeurs de largeur et de hauteur
xX=$(echo $FILE_RES | cut -d "x" -f 1)
yY=$(echo $FILE_RES | cut -d "x" -f 2)

RES=${yY%?}0p && echo "File resolution : $RES"
LINES=$(echo $RES | tr -dc '0-9')
############# VIDEO LINES MAX IS 720p
if [ $LINES -gt 720 ]; then
    x2=$((xX / 2))
    y2=$((yY / 2))
    # Correct non pair result
    if [ $(($x2 % 2)) -ne 0 ]; then
        x2=$((x2 - 1))
    fi
    if [ $(($y2 % 2)) -ne 0 ]; then
        y2=$((y2 - 1))
    fi
    echo "RESIZING TO scale=$x2:$y2"
    if [[ $(which nvidia-smi) ]]; then
        ffmpeg -loglevel quiet -hwaccel cuda -i "${path}${file}" -vf "scale=$x2:$y2" "${path}2${file}"
    else
        ffmpeg -loglevel quiet -i "${path}${file}" -vf "scale=$x2:$y2" "${path}2${file}"
    fi
    ## REPLACE SOURCE FIL
    [[ -s "${path}2${file}" ]] \
        && rm "${path}${file}" \
        && mv "${path}2${file}" "${path}${file}"
    echo "conversion finished...."
    ## CHECK FOR NEW RES
    FILE_YY=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "${path}${file}" | cut -d "x" -f 2) \
    && RES=${FILE_YY%?}0p && echo $RES && HOP=2
fi
#################################################################################################################
echo "File resolution : $RES"

FILE_BSIZE=$(du -b "${path}${file}" | awk '{print $1}')

DURATION=$(ffprobe -v error -i "${path}${file}" -show_entries format=duration -v quiet -of csv="p=0" | cut -d '.' -f 1)
DUREE=$(ffprobe -v error -i "${path}${file}" -show_entries format=duration -sexagesimal -v quiet -of csv="p=0"| cut -d '.' -f 1)

PROBETIME=$(echo "0.618 * $DURATION" | bc -l | cut -d '.' -f 1)
[[ ! $PROBETIME ]] && PROBETIME="1.0"

## How many seconds are encoded by MB ?
VTRATIO=$(echo "$DURATION / $FILE_BSIZE * 1024 * 1024" | bc -l | xargs printf "%.2f")

## CREATE SOME INDEX HOOKS
# ffmpeg -skip_frame nokey -i ${path}${file} -vsync 0 -r 30 -f image2 thumbnails-%02d.jpeg

rm -f ~/.zen/tmp/screen.gif
ffmpeg -loglevel quiet -ss $PROBETIME -t 1.6 -loglevel quiet -i "${path}${file}" ~/.zen/tmp/screen.gif
[ ! -s ~/.zen/tmp/screen.gif ] && cp $MY_PATH/../images/CAP_theorem.png ~/.zen/tmp/screen.gif
ANIMH=$(ipfs add -q ~/.zen/tmp/screen.gif)
ipfs pin rm $ANIMH
cp ~/.zen/tmp/screen.gif "${path}${file}.gif"

## -- cross "bash tail -n 1" variable setting in return --- BASH TRICK ;)
echo "export HOP=$HOP ANIMH=$ANIMH PROBETIME=$PROBETIME DURATION=$DURATION DUREE=$DUREE RES=$RES MIME=$MIME VTRATIO=$VTRATIO file=$file"
exit 0
