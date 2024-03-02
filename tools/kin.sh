#!/bin/bash

echo "THIS KIN CALCULATION HAS DEFAULT - EDIT - CORRECT and run by hand"

# Function to describe tonality based on the provided tonality
describe_tonality() {
    local tonality=$1

    # Add logic to display tonality description based on the provided information
    case $tonality in
        "Magnétique") echo "Action: Attirer dans le but d'unifier | Pouvoir: Unification | Essence: Présence";;
        "Lunaire") echo "Action: Polariser et stabiliser | Pouvoir: Stabilisation | Essence: Définition";;
        "Électrique") echo "Action: Activer et unifier | Pouvoir: Activation | Essence: Unification";;
        "Auto-existante") echo "Action: Mesurer afin de pouvoir définir | Pouvoir: Mesure | Essence: Définition";;
        "Harmonique") echo "Action: Autoriser la prise de pouvoir, le commandement | Pouvoir: Commandement | Essence: Pouvoir";;
        "Rythmique") echo "Action: Autoriser à organiser dans le but d'atteindre un équilibre | Pouvoir: Organisation | Essence: Équilibre";;
        "Résonnante") echo "Action: Canaliser et inspirer | Pouvoir: Inspiration | Essence: Canalisation";;
        "Galactique") echo "Action: Harmoniser et modéliser | Pouvoir: Harmonisation | Essence: Modélisation";;
        "Solaire") echo "Action: Pulser et réaliser | Pouvoir: Réalisation | Essence: Pulser";;
        "Planétaire") echo "Action: Chercher à perfectionner et à produire | Pouvoir: Perfectionnement | Essence: Production";;
        "Spectrale") echo "Action: Dissoudre et s'abandonner | Pouvoir: Dissolution | Essence: Abandon";;
        "Cristal") echo "Action: Dédier et universaliser | Pouvoir: Dédication | Essence: Universalisation";;
        "Cosmique") echo "Action: Confronter et transcender | Pouvoir: Confrontation | Essence: Transcendance";;
        *) echo "Description de la Tonalité Inconnue";;
    esac
}


# Function to describe glyph based on the provided glyph
describe_glyph() {
    local glyph=$1

    # Add logic to display glyph description based on the provided information
    case $glyph in
        "Imix") echo "Glyphe: Imix - La naissance du nouveau, le crocodile";;
        "Ik") echo "Glyphe: Ik - Le vent, le souffle de vie";;
        "Akbal") echo "Glyphe: Akbal - L'obscurité, la nuit, la maison";;
        "Kan") echo "Glyphe: Kan - Le serpent, l'énergie vitale, la germination";;
        "Chicchan") echo "Glyphe: Chicchan - Le serpent, la force vitale, l'instinct";;
        "Cimi") echo "Glyphe: Cimi - La mort, le changement, la transformation";;
        "Manik") echo "Glyphe: Manik - La main, l'accomplissement, la guérison";;
        "Lamat") echo "Glyphe: Lamat - L'étoile, l'abondance, la prospérité";;
        "Muluc") echo "Glyphe: Muluc - L'eau, l'émotion, la purification";;
        "Oc") echo "Glyphe: Oc - Le chien, la loyauté, l'abondance";;
        "Chuen") echo "Glyphe: Chuen - Le singe, l'illusion, la créativité";;
        "Eb") echo "Glyphe: Eb - L'humain, le chemin de vie, le libre arbitre";;
        "Ben") echo "Glyphe: Ben - Le roseau, l'adaptabilité, la croissance";;
        "Ix") echo "Glyphe: Ix - La jaguar, le féminin, le mystère";;
        "Men") echo "Glyphe: Men - Le faucon, la vision, la perspective";;
        "Cib") echo "Glyphe: Cib - Le vautour, la sagesse, la connaissance";;
        "Caban") echo "Glyphe: Caban - La terre, la navigation, l'énergie";;
        "Etznab") echo "Glyphe: Etznab - Le miroir, la réflexion, la vérité";;
        "Cauac") echo "Glyphe: Cauac - L'orage, la purification, le renouveau";;
        "Ahau") echo "Glyphe: Ahau - Le soleil, l'illumination, la réalisation";;
        *) echo "Description du Glyphe Inconnue";;
    esac

    # Add logic to display three keywords associated with the glyph
    case $glyph in
        "Imix") echo "Action: Naissance du Nouveau, Essence: Crocodile, Pouvoir: La Matière";;
        "Ik") echo "Action: Souffle de Vie, Essence: Vent, Pouvoir: Inspiration";;
        "Akbal") echo "Action: L'Obscurité, Essence: Nuit, Pouvoir: Réceptivité";;
        "Kan") echo "Action: Énergie Vitale, Essence: Serpent, Pouvoir: Force";;
        "Chicchan") echo "Action: Force Vitale, Essence: Serpent, Pouvoir: L'Instinct";;
        "Cimi") echo "Action: Mort, Essence: Changement, Pouvoir: Transformation";;
        "Manik") echo "Action: Accomplissement, Essence: Main, Pouvoir: Guérison";;
        "Lamat") echo "Action: Abondance, Essence: Étoile, Pouvoir: Prospérité";;
        "Muluc") echo "Action: Eau, Essence: Émotion, Pouvoir: Purification";;
        "Oc") echo "Action: Loyauté, Essence: Chien, Pouvoir: Abondance";;
        "Chuen") echo "Action: Illusion, Essence: Singe, Pouvoir: Créativité";;
        "Eb") echo "Action: Humain, Essence: Chemin de Vie, Pouvoir: Libre Arbitre";;
        "Ben") echo "Action: Adaptabilité, Essence: Roseau, Pouvoir: Croissance";;
        "Ix") echo "Action: Jaguar, Essence: Féminin, Pouvoir: Mystère";;
        "Men") echo "Action: Faucon, Essence: Vision, Pouvoir: Perspective";;
        "Cib") echo "Action: Vautour, Essence: Sagesse, Pouvoir: Connaissance";;
        "Caban") echo "Action: Terre, Essence: Navigation, Pouvoir: Énergie";;
        "Etznab") echo "Action: Miroir, Essence: Réflexion, Pouvoir: Vérité";;
        "Cauac") echo "Action: Orage, Essence: Purification, Pouvoir: Renouveau";;
        "Ahau") echo "Action: Soleil, Essence: Illumination, Pouvoir: Réalisation";;
        *) echo "Mots-clés du Glyphe Inconnus";;
    esac
}

# Function to describe kin based on the provided kin
describe_kin() {
    local kin=$1

    # Define an array with descriptions for each kin
    local descriptions=(
        "Tonalité #1 - Magnétique: Attirer dans le but d'unifier"
        "Tonalité #2 - Lunaire: Polariser et stabiliser"
        "Tonalité #3 - Électrique: Activer et unifier"
        "Tonalité #4 - Auto-existante: Mesurer afin de pouvoir définir"
        "Tonalité #5 - Harmonique: Autoriser la prise de pouvoir, le commandement"
        "Tonalité #6 - Rythmique: Autoriser à organiser dans le but d'atteindre un équilibre"
        "Tonalité #7 - Résonnante: Canaliser et inspirer"
        "Tonalité #8 - Galactique: Harmoniser et modéliser"
        "Tonalité #9 - Solaire: Pulser et réaliser"
        "Tonalité #10 - Planétaire: Chercher à perfectionner et à produire"
        "Tonalité #11 - Spectrale: Dissoudre et s'abandonner"
        "Tonalité #12 - Cristal: Dédier et universaliser"
        "Tonalité #13 - Cosmique: Confronter et transcender"
    )

    # Use modulo 13 to map kin to tonalities
    local mapped_kin=$(( (kin - 1) % 13 + 1 ))

    echo "${descriptions[mapped_kin - 1]}"
}


# Function to describe color based on the provided color
describe_color() {
    local color=$1

    # Add logic to display color description based on the provided information
    case $color in
        "Rouge") echo "Création, naissance";;
        "Blanc") echo "Stockage";;
        "Bleu") echo "Manifestation, transformation";;
        "Jaune") echo "Expansion, floraison";;
        "Vert") echo "Dissolution";;
        *) echo "Description de la Couleur Inconnue";;
    esac
}

# Function to calculate the Maya Kin based on date
#!/bin/bash

# Function to calculate Maya Kin
calculate_maya_kin() {
    local year=$1
    local month=$2
    local day=$3
    local numMes

    # Array of cumulative days for each month
    local meses=(0 31 59 90 120 151 181 212 243 13 44 74)

    # Calculate the cumulative days for the given month
    numMes=${meses[$((month - 1))]}

    # Define an associative array for mapping anios to sumaAnio
    declare -A sumaAnio_mapping=(
        [30]=2 [35]=7 [40]=12 [45]=17 [50]=22 [3]=27
        [8]=32 [13]=37 [18]=42 [23]=47 [28]=52 [32]=57
        [38]=62 [42]=67 [48]=72 [1]=76 [6]=82 [11]=87
        [16]=92 [21]=97 [26]=102 [31]=107 [36]=112 [41]=117
        [46]=122 [51]=127 [4]=132 [9]=137 [14]=142 [19]=147
        [24]=152 [29]=157 [34]=162 [39]=167 [44]=172 [49]=177
        [2]=182 [7]=187 [12]=192 [17]=197 [22]=202 [27]=207
        [32]=212 [37]=217 [42]=222 [47]=227 [0]=232 [5]=237
        [10]=242 [15]=247 [20]=252 [25]=257
    )

    # Get sumaAnio based on the year
    local sumaAnio=${sumaAnio_mapping[$((year % 52))]}

    # Calculate the Maya Kin
    local kin=$((day + numMes + sumaAnio))

    # Adjust kin if it exceeds 260
    if [ $kin -gt 260 ]; then
        kin=$((kin - 260))
    fi

    aplay /ipfs/Qmbt31Txi8hq9FUMhrEHbjtpgv8A8o3SqysJUrEA4nuZBe/kin$kin.mp3 &

    # Print the calculated kin
    echo $kin
}


# Function to display Maya Kin details
display_maya_kin_details() {
    local kin=$1

    # Define arrays for Maya glyphs, tonalities, and colors
    glyphs=("Imix" "Ik" "Akbal" "Kan" "Chicchan" "Cimi" "Manik" "Lamat" "Muluc" "Oc" "Chuen" "Eb" "Ben" "Ix" "Men" "Cib" "Caban" "Etznab" "Cauac" "Ahau")
    tonalities=("Magnétique" "Lunaire" "Électrique" "Auto-existante" "Harmonique" "Rythmique" "Résonnante" "Galactique" "Solaire" "Planétaire" "Spectrale" "Cristal" "Cosmique")
    colors=("Rouge" "Blanc" "Bleu" "Jaune" "Vert")

    # Determine the glyph, tonality, and color based on the Maya Kin
    local glyph_index=$(( (kin - 1) % 20 ))
    local tonality_index=$(( (kin - 1) % 13 ))
    local color_index=$(( (tonality_index % 4) + 1 )) # Assuming 4 colors in each tonality

    local glyph=${glyphs[$glyph_index]}
    local tonality=${tonalities[$tonality_index]}
    local color=${colors[$color_index]}

    # Display Maya Kin details
    echo "Maya Kin: $kin"
    describe_kin "$kin"
    echo "------------------------------"

    echo "Glyph: $glyph"
    describe_glyph "$glyph"
    echo "------------------------------"

    echo "Tonalité: $tonality"
    describe_tonality "$tonality"
    echo "------------------------------"

    echo "Couleur: $color"
    describe_color "$color"
    echo "------------------------------"
    echo "Le Maya Kin est $color, $color_description , gouverné par la tonalité $tonality et représenté par le glyphe $glyph."
}

# Input date of birth
[[ -z $1 ]] \
    && read -p "Entrez votre date de naissance (YYYY-MM-DD): " dob \
    || dob="$1"

# Extract year, month, and day from the input
year=$(echo $dob | cut -d'-' -f1)
month=$(echo $dob | cut -d'-' -f2)
day=$(echo $dob | cut -d'-' -f3)

# Calculate the Maya Kin based on the provided date
maya_kin=$(calculate_maya_kin $year $month $day)

# Display Maya Kin details
display_maya_kin_details $maya_kin


