#!/bin/bash
########################################################################
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
## EXPLORE SWARM MAPNS
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

. "$MY_PATH/../tools/my.sh"

# Mapping of weather conditions to emoticons
weather_emoticon_map=(
    ["Clear"]="😊"
    ["Clouds"]="☁️"
    ["Rain"]="🌧️"
    ["Snow"]="❄️"
    ["Thunderstorm"]="⛈️"
    # Add more mappings as needed
)

default_emoticon="😊"

## GET IPFSNODEID WHEATER
source ~/.zen/GPS
echo "... ~/.zen/GPS ... $LAT $LON ..."

## caching IPCity
[[ ~/.zen/IPCity ]] \
    && my_IPCity > ~/.zen/IPCity
ville=$(cat ~/.zen/IPCity)

api_key="ac5e65a2fd10d3788d40cdae0d4516ba" # Remplacez YOUR_API_KEY par votre clé API OpenWeatherMap
url="http://api.openweathermap.org/data/2.5/weather?q=$ville&APPID=$api_key&units=metric"
meteo=$(curl -s $url)

# Extract relevant weather information
condition=$(echo "$meteo" | jq -r '.weather[0].main')
emoticon=${weather_emoticon_map[$condition]}
selected_emoticon=${emoticon:-$default_emoticon}

description=$(echo "$meteo" | jq -r '.weather[0].description')
temp=$(echo "$meteo" | jq -r '.main.temp')
humidity=$(echo "$meteo" | jq -r '.main.humidity')
wind_speed=$(echo "$meteo" | jq -r '.wind.speed')

# Create a sentence with "emoticons" and ASCII art decorations
echo "# $ville

## $selected_emoticon  $condition
$description

---

T=${temp} °C
H=${humidity} %
W=${wind_speed} m/s

---

😊 Stay cozy BRO !
"

##  SATELLITE IMAGE ...
## Add more +++
