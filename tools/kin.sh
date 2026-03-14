#!/bin/bash
########################################################################
# kin.sh — Maya Kin calculator (Tzolkin calendar)
# Can be sourced as a library or run directly.
# Usage:
#   source kin.sh && maya_kin_json "1985-07-23"
#   ./kin.sh 1985-07-23
########################################################################

# 20 Solar Seals (glyphs)
KIN_GLYPHS=("Imix" "Ik" "Akbal" "Kan" "Chicchan" "Cimi" "Manik" "Lamat" "Muluc" "Oc" "Chuen" "Eb" "Ben" "Ix" "Men" "Cib" "Caban" "Etznab" "Cauac" "Ahau")

# 13 Galactic Tones (tonalities)
KIN_TONES=("Magnétique" "Lunaire" "Électrique" "Auto-existante" "Harmonique" "Rythmique" "Résonnante" "Galactique" "Solaire" "Planétaire" "Spectrale" "Cristal" "Cosmique")

# 5 Colors
KIN_COLORS=("Rouge" "Blanc" "Bleu" "Jaune" "Vert")

# Tone keywords (Action / Power / Essence)
KIN_TONE_KEYS=(
    "Unifier|Unification|Présence"
    "Polariser|Stabilisation|Définition"
    "Activer|Activation|Unification"
    "Définir|Mesure|Définition"
    "Commander|Commandement|Pouvoir"
    "Organiser|Organisation|Équilibre"
    "Canaliser|Inspiration|Canalisation"
    "Harmoniser|Harmonisation|Modélisation"
    "Réaliser|Réalisation|Impulsion"
    "Perfectionner|Perfectionnement|Production"
    "Dissoudre|Dissolution|Abandon"
    "Universaliser|Dédication|Universalisation"
    "Transcender|Confrontation|Transcendance"
)

# Calculate Maya Kin number from date (YYYY MM DD)
calculate_maya_kin() {
    local year=$1 month=$2 day=$3
    local meses=(0 31 59 90 120 151 181 212 243 13 44 74)
    local numMes=${meses[$((month - 1))]}

    declare -A sumaAnio_mapping=(
        [30]=2 [35]=7 [40]=12 [45]=17 [50]=22 [3]=27
        [8]=32 [13]=37 [18]=42 [23]=47 [28]=52 [32]=57
        [38]=62 [42]=67 [48]=72 [1]=76 [6]=82 [11]=87
        [16]=92 [21]=97 [26]=102 [31]=107 [36]=112 [41]=117
        [46]=122 [51]=127 [4]=132 [9]=137 [14]=142 [19]=147
        [24]=152 [29]=157 [34]=162 [39]=167 [44]=172 [49]=177
        [2]=182 [7]=187 [12]=192 [17]=197 [22]=202 [27]=207
        [37]=217 [42]=222 [47]=227 [0]=232 [5]=237
        [10]=242 [15]=247 [20]=252 [25]=257
    )

    local sumaAnio=${sumaAnio_mapping[$((year % 52))]}
    local kin=$((day + numMes + sumaAnio))
    [[ $kin -gt 260 ]] && kin=$((kin - 260))
    echo $kin
}

# Return Maya Kin as JSON badge object for DID integration
# Usage: maya_kin_json "YYYY-MM-DD"
# Output: {"type":"MayaKin","kin":42,"glyph":"Ik","tone":"Magnétique","color":"Blanc","action":"Unifier","power":"Unification","essence":"Présence"}
maya_kin_json() {
    local dob="$1"
    [[ -z "$dob" ]] && return 1

    local year=$(echo "$dob" | cut -d'-' -f1)
    local month=$(echo "$dob" | cut -d'-' -f2)
    local day=$(echo "$dob" | cut -d'-' -f3)

    # Remove leading zeros for arithmetic
    month=$((10#$month))
    day=$((10#$day))

    local kin=$(calculate_maya_kin $year $month $day)
    local glyph_idx=$(( (kin - 1) % 20 ))
    local tone_idx=$(( (kin - 1) % 13 ))
    local color_idx=$(( (kin - 1) / 13 % 5 ))

    local glyph="${KIN_GLYPHS[$glyph_idx]}"
    local tone="${KIN_TONES[$tone_idx]}"
    local color="${KIN_COLORS[$color_idx]}"

    IFS='|' read -r action power essence <<< "${KIN_TONE_KEYS[$tone_idx]}"

    echo "{\"type\":\"MayaKin\",\"kin\":${kin},\"glyph\":\"${glyph}\",\"tone\":\"${tone}\",\"color\":\"${color}\",\"action\":\"${action}\",\"power\":\"${power}\",\"essence\":\"${essence}\"}"
}

# Display human-readable Maya Kin details
display_maya_kin() {
    local dob="$1"
    [[ -z "$dob" ]] && echo "Usage: display_maya_kin YYYY-MM-DD" && return 1

    local year=$(echo "$dob" | cut -d'-' -f1)
    local month=$((10#$(echo "$dob" | cut -d'-' -f2)))
    local day=$((10#$(echo "$dob" | cut -d'-' -f3)))

    local kin=$(calculate_maya_kin $year $month $day)
    local glyph_idx=$(( (kin - 1) % 20 ))
    local tone_idx=$(( (kin - 1) % 13 ))
    local color_idx=$(( (kin - 1) / 13 % 5 ))

    local glyph="${KIN_GLYPHS[$glyph_idx]}"
    local tone="${KIN_TONES[$tone_idx]}"
    local color="${KIN_COLORS[$color_idx]}"
    IFS='|' read -r action power essence <<< "${KIN_TONE_KEYS[$tone_idx]}"

    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo "Date: $dob → Maya Kin: $kin"
    echo "Glyphe: $glyph | Tonalité: $tone | Couleur: $color"
    echo "Action: $action | Pouvoir: $power | Essence: $essence"
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
}

# If run directly (not sourced), behave as CLI tool
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    dob="${1}"
    [[ -z "$dob" ]] && read -p "Date de naissance (YYYY-MM-DD): " dob
    display_maya_kin "$dob"
    echo ""
    echo "JSON badge:"
    maya_kin_json "$dob"
fi
