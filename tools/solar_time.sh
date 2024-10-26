#!/bin/bash

LAT=$1
LON=$2
TZ=$3

# Fonction pour calculer l'équation du temps (simplifiée)
equation_of_time() {
    local day_of_year=$(date +%j)
    local B=$(echo "scale=10; 360/365 * ($day_of_year - 81)" | bc)
    local eot=$(echo "scale=10; 9.87 * s($B * 3.14159265359/180 * 2) - 7.53 * c($B * 3.14159265359/180) - 1.5 * s($B * 3.14159265359/180)" | bc -l)
    echo $eot
}

# Fonction pour calculer le décalage horaire en minutes
time_offset() {
    local lon=$1
    local eot=$2
    local offset=$(echo "scale=10; 4 * $lon + $eot" | bc)
    echo $offset
}

# Récupérer LAT et LON depuis ~/.zen/GPS si non fournies
if [ -z "$LAT" ] || [ -z "$LON" ]; then
    if [ -f ~/.zen/GPS ]; then
        source ~/.zen/GPS
    else
        echo "Fichier ~/.zen/GPS non trouvé. Veuillez fournir LAT et LON."
        exit 1
    fi
fi

# Récupérer TZ du système si non fourni
if [ -z "$TZ" ]; then
    TZ=$(timedatectl show --property=Timezone --value)
fi

# Obtenir le décalage horaire exact pour la date actuelle
CURRENT_DATE=$(date +"%Y-%m-%d")
TZ_OFFSET=$(TZ=$TZ date -d "$CURRENT_DATE" +%z)
TZ_OFFSET_HOURS=$(echo $TZ_OFFSET | cut -c1-3)
TZ_OFFSET_MINUTES=$(echo $TZ_OFFSET | cut -c4-5)
TZ_OFFSET_TOTAL=$(echo "scale=2; $TZ_OFFSET_HOURS + $TZ_OFFSET_MINUTES/60" | bc)

# Calcul de l'équation du temps
EOT=$(equation_of_time)

# Calcul du décalage horaire
OFFSET=$(time_offset $LON $EOT)

# Conversion du décalage en heures et minutes
OFFSET_HOURS=$(echo "scale=0; $OFFSET / 60" | bc)
OFFSET_MINUTES=$(echo "scale=0; ($OFFSET - $OFFSET_HOURS * 60) / 1" | bc)

# Calculer l'heure légale pour 20h12 solaire
TARGET_SOLAR_HOUR=20
TARGET_SOLAR_MINUTE=12
LEGAL_HOUR=$(echo "scale=0; ($TARGET_SOLAR_HOUR + $TZ_OFFSET_TOTAL - $OFFSET_HOURS + 24) % 24" | bc)
LEGAL_MINUTE=$(echo "scale=0; ($TARGET_SOLAR_MINUTE - $OFFSET_MINUTES + 60) % 60" | bc)

# Afficher les résultats
echo "Coordonnées : LAT=$LAT, LON=$LON"
echo "Fuseau horaire : $TZ (décalage : $TZ_OFFSET)"
echo "Heure légale correspondant à 20h12 solaire : $(printf "%02d:%02d" $LEGAL_HOUR $LEGAL_MINUTE)"
echo
echo "$LEGAL_MINUTE $LEGAL_HOUR * * * /bin/bash \$MY_PATH/../20h12.process.sh > /tmp/20h12.log 2>&1"
