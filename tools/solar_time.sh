#!/bin/bash

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

# Vérification des arguments
if [ $# -ne 2 ]; then
    echo "Usage: $0 <latitude> <longitude>"
    exit 1
fi

LAT=$1
LON=$2

# Calcul de l'équation du temps
EOT=$(equation_of_time)

# Calcul du décalage horaire
OFFSET=$(time_offset $LON $EOT)

# Conversion du décalage en heures et minutes
OFFSET_HOURS=$(echo "scale=0; $OFFSET / 60" | bc)
OFFSET_MINUTES=$(echo "scale=0; ($OFFSET - $OFFSET_HOURS * 60) / 1" | bc)

# Calcul de l'heure légale
LEGAL_HOUR=$(echo "scale=0; (20 - $OFFSET_HOURS + 24) % 24" | bc)
LEGAL_MINUTE=$(echo "scale=0; (12 - $OFFSET_MINUTES + 60) % 60" | bc)

# Formatage de l'heure légale
echo "Aux coordonnées GPS $1 $2"
printf "L'heure légale correspondant à 20h12 solaire est %02d:%02d\n" $LEGAL_HOUR $LEGAL_MINUTE
echo "$LEGAL_HOUR $LEGAL_MINUTE"
