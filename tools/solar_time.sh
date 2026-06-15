#!/bin/bash
# solar_time.sh — Convertit 20h12 solaire en heure légale (cron Astroport)
#
# Usage : solar_time.sh [LAT] [LON] [TZ] [DATE]
#   LAT  : latitude  (ex: 48.86)   — sinon ~/.zen/GPS
#   LON  : longitude (ex: 2.35)    — sinon ~/.zen/GPS
#   TZ   : fuseau légal (ex: Europe/Paris) — sinon timedatectl
#   DATE : date YYYY-MM-DD         — sinon aujourd'hui
#
# Physique appliquée — Équation du Temps (EoT), Spencer 1971 :
#   Temps_solaire_apparent = UTC + 4×LON(min) + EoT(min)
#   → UTC = heure_solaire − 4×LON − EoT
#   → légal = UTC + offset_légal
#
#   L'EoT combine deux effets astronomiques (précision ±2 min) :
#   1. Excentricité orbitale (2e loi de Képler) :
#      La Terre avance vite au périhélie (janvier, +8 min), lentement à
#      l'aphélie (juillet, -8 min) → termes 7.53·cos B et 1.5·sin B
#   2. Obliquité axiale (23.5°) :
#      Décalage entre plan écliptique et équateur → terme 9.87·sin 2B
#   B = 2π/365 × (jour − 81),  origine à l'équinoxe de printemps
#
# Implémentation : arithmétique en minutes totales → aucun bug de dépassement
# heure/minute, gestion correcte des longitudes négatives.

# ── Forcer la locale C pour les calculs bc (décimale = point) ────────────────
export LC_ALL=C
export LANG=C

LAT=${1:-""}
LON=${2:-""}
TZ_ARG=${3:-""}
DATE_ARG=${4:-""}

# ── Récupérer LAT / LON ──────────────────────────────────────────────────────
if [[ -z "$LAT" || -z "$LON" ]]; then
    if [[ -f ~/.zen/GPS ]]; then
        source ~/.zen/GPS
    else
        echo "ERROR: Fichier ~/.zen/GPS introuvable. Fournir LAT et LON." >&2
        exit 1
    fi
fi

# ── Récupérer le fuseau légal ────────────────────────────────────────────────
if [[ -z "$TZ_ARG" ]]; then
    TZ_ARG=$(timedatectl show --property=Timezone --value 2>/dev/null || echo "UTC")
fi

# ── Date de référence ────────────────────────────────────────────────────────
[[ -z "$DATE_ARG" ]] && DATE_ARG=$(date +"%Y-%m-%d")

# ── Jour de l'année ──────────────────────────────────────────────────────────
DOY=$(date -d "$DATE_ARG" +%j 2>/dev/null || python3 -c "
import datetime, sys
d = datetime.date.fromisoformat('$DATE_ARG')
print(d.timetuple().tm_yday)")
DOY=${DOY:-1}

# ── Équation du Temps — Spencer (1971) ──────────────────────────────────────
# B en radians : 2π/365 × (doy − 81)
# EoT = 9.87·sin(2B) − 7.53·cos(B) − 1.5·sin(B)  [minutes]
# Note : bc traite les lettres majuscules comme des chiffres hex (B=11 !).
# Toutes les variables bc doivent être en minuscules.
EOT=$(bc -l <<BCEOF
scale=8
pi=4*a(1)
b=2*pi/365*($DOY-81)
9.87*s(2*b) - 7.53*c(b) - 1.5*s(b)
BCEOF
)

# ── Offset longitude [minutes] ───────────────────────────────────────────────
LON_OFFSET=$(echo "scale=6; 4 * $LON" | bc)

# ── Offset solaire total ─────────────────────────────────────────────────────
SOLAR_OFFSET=$(echo "scale=6; $LON_OFFSET + $EOT" | bc)

# ── Offset légal [minutes entières] ─────────────────────────────────────────
TZ_OFFSET_STR=$(TZ="$TZ_ARG" date -d "$DATE_ARG" +%z 2>/dev/null || echo "+0000")
TZ_SIGN=$(echo "$TZ_OFFSET_STR" | cut -c1)
TZ_H=$(echo "$TZ_OFFSET_STR"   | sed 's/^[+-]//' | cut -c1-2)
TZ_M=$(echo "$TZ_OFFSET_STR"   | sed 's/^[+-]//' | cut -c3-4)
TZ_H=${TZ_H#0}; TZ_M=${TZ_M#0}   # enlever les zéros initiaux
TZ_H=${TZ_H:-0}; TZ_M=${TZ_M:-0}
TZ_OFFSET_MIN=$(( TZ_H * 60 + TZ_M ))
[[ "$TZ_SIGN" == "-" ]] && TZ_OFFSET_MIN=$(( -TZ_OFFSET_MIN ))

# ── Calcul en minutes totales depuis minuit ──────────────────────────────────
# légal = solaire − offset_solaire + offset_légal
# Tout en minutes réelles (flottant → entier par arrondi)
TARGET_SOLAR_MIN=1212   # 20×60 + 12

LEGAL_MIN_FLOAT=$(echo "scale=6; $TARGET_SOLAR_MIN - $SOLAR_OFFSET + $TZ_OFFSET_MIN" | bc)
# Arrondir au plus proche (bc n'a pas de round — on utilise awk)
LEGAL_MIN_INT=$(echo "$LEGAL_MIN_FLOAT" | awk '{printf "%d", ($0 >= 0) ? int($0+0.5) : int($0-0.5)}')

# Ramener dans [0, 1440) — gérer le passage minuit
LEGAL_MIN_MOD=$(( (LEGAL_MIN_INT % 1440 + 1440) % 1440 ))

LEGAL_HOUR=$(( LEGAL_MIN_MOD / 60 ))
LEGAL_MINUTE=$(( LEGAL_MIN_MOD % 60 ))

# ── Affichage ────────────────────────────────────────────────────────────────
printf "Coordonnées    : LAT=%s  LON=%s\n" "$LAT" "$LON"
printf "Date           : %s  Fuseau : %s (offset légal : %+d min)\n" \
       "$DATE_ARG" "$TZ_ARG" "$TZ_OFFSET_MIN"
printf "Jour de l'an   : %d\n" "$DOY"
printf "EoT            : %+.2f min (excentricité + obliquité)\n" "$EOT"
printf "Offset lon      : %+.2f min  (%.4f° × 4 min/°)\n" "$LON_OFFSET" "$LON"
printf "Offset solaire  : %+.2f min total\n" "$SOLAR_OFFSET"
printf "\n"
printf "20h12 solaire → %02d:%02d légal\n" "$LEGAL_HOUR" "$LEGAL_MINUTE"
printf "\n"
# Sortie cron
printf "%02d %02d * * * /bin/bash \$MY_PATH/../20h12.process.sh >> \$HOME/.zen/log/20h12.log 2>&1\n" \
       "$LEGAL_MINUTE" "$LEGAL_HOUR"
printf "%02d %02d\n" "$LEGAL_MINUTE" "$LEGAL_HOUR"
