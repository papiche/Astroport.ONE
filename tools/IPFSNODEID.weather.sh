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

## GET IPFSNODEID WHEATER
source ~/.zen/GPS
echo "... ~/.zen/GPS ... $LAT $LON ..."
ville=$(my_IPCity)
echo "my_IPCity = $ville"
api_key="ac5e65a2fd10d3788d40cdae0d4516ba" # Remplacez YOUR_API_KEY par votre clé API OpenWeatherMap
url="http://api.openweathermap.org/data/2.5/weather?q=$ville&APPID=$api_key&units=metric"
meteo=$(curl -s $url)
# Extraire les informations pertinentes de la réponse JSON
temperature=$(echo $meteo | jq -r '.main.temp')
description=$(echo $meteo | jq -r '.weather[0].description')
echo "$ville : $description, ( $temperature °C )"

##  SATELLITE IMAGE ...
## Add more +++
