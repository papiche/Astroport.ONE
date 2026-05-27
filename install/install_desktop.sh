#!/bin/bash
########################################################################
# install_desktop.sh — Logiciels de création libres (idempotent)
#
# Détecte les paquets déjà installés avant de proposer l'installation.
# Affiche ✅ (installé) / ❌ (absent) dans le menu.
# En mode upgrade : saute le menu si tout est déjà installé.
# Appelé par install.sh (uniquement si environnement graphique détecté).
# License: AGPL-3.0
########################################################################
[ $(id -u) -eq 0 ] && echo "LANCEMENT root INTERDIT." && exit 1

## ── Détection environnement graphique ────────────────────────────────
if [[ -z "$(which X 2>/dev/null)" && -z "$DISPLAY" && -z "$WAYLAND_DISPLAY" ]]; then
    echo "ℹ️  Pas d'environnement graphique — install_desktop.sh ignoré."
    exit 0
fi

## ── Variables globales ────────────────────────────────────────────────
_SCORE="${_SCORE:-0}"
_VRAM="${_VRAM:-0}"
_IS_UPGRADE="${_IS_UPGRADE:-false}"
_SILENT="${_SILENT:-false}"
_ERROR_LOG="${_ERROR_LOG:-$HOME/.zen/log/install.errors.log}"
mkdir -p "$(dirname "$_ERROR_LOG")"

## ── Helpers ───────────────────────────────────────────────────────────
_installed() { dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -c "ok installed"; }
_mark() { [[ "$(_installed "$1")" -gt 0 ]] && echo "✅" || echo "❌"; }

## ── Définition des packs ─────────────────────────────────────────────
PACK1_PKGS=(gimp inkscape krita scribus)
PACK2_PKGS=(libreoffice libreoffice-l10n-fr thunderbird vlc)
PACK3_PKGS=(kdenlive mixxx obs-studio audacity)
PACK4_PKGS=(blender freecad lmms ardour)

## ── Comptage des paquets déjà installés par pack ──────────────────────
_count_missing() {
    local _missing=0
    for _p in "$@"; do [[ "$(_installed "$_p")" -eq 0 ]] && (( _missing++ )) || true; done
    echo "$_missing"
}

_M1=$(_count_missing "${PACK1_PKGS[@]}")
_M2=$(_count_missing "${PACK2_PKGS[@]}")
_M3=$(_count_missing "${PACK3_PKGS[@]}")
_M4=$(_count_missing "${PACK4_PKGS[@]}")
_TOTAL_MISSING=$(( _M1 + _M2 + _M3 + _M4 ))

## ── Outils graphiques de base (toujours) ─────────────────────────────
echo "#############################################"
echo "######### INSTALL DESKTOP TOOLS  ############"
echo "#############################################"
for _i in x11-utils xclip zenity; do
    if [[ "$(_installed "$_i")" -eq 0 ]]; then
        echo ">>> Installation $_i..."
        sudo apt install -y "$_i" \
            || { echo "INSTALL $_i FAILED." | tee -a "$_ERROR_LOG"; }
    fi
done

## ── En upgrade silencieux, skip si rien à faire ──────────────────────
if [[ "$_IS_UPGRADE" == "true" && "$_TOTAL_MISSING" -eq 0 ]]; then
    echo "✅ Tous les logiciels desktop déjà installés — rien à faire."
    exit 0
fi

## ── Affichage du menu avec état ─────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  🎨 LOGICIELS DESKTOP — L'ÉMANCIPATION NUMÉRIQUE             ║"
echo "╠══════════════════════════════════════════════════════════════╣"
printf  "║  Score : %s | VRAM : %s Go | Manquants : %s              \n" \
    "$_SCORE" "$_VRAM" "$_TOTAL_MISSING"
echo "╠══════════════════════════════════════════════════════════════╣"

printf "║ [1] Graphisme 2D ~1150€    %s GIMP  %s Inkscape  %s Krita  %s Scribus\n" \
    "$(_mark gimp)" "$(_mark inkscape)" "$(_mark krita)" "$(_mark scribus)"
printf "║     → %s paquet(s) manquant(s)\n" "$_M1"
echo "║"

printf "║ [2] Bureautique ~250€      %s LibreOffice  %s Thunderbird  %s VLC\n" \
    "$(_mark libreoffice)" "$(_mark thunderbird)" "$(_mark vlc)"
printf "║     → %s paquet(s) manquant(s)\n" "$_M2"
echo "║"

if [[ $_SCORE -gt 10 ]]; then
    printf "║ [3] Audiovisuel ~630€      %s Kdenlive  %s Mixxx  %s OBS  %s Audacity\n" \
        "$(_mark kdenlive)" "$(_mark mixxx)" "$(_mark obs-studio)" "$(_mark audacity)"
    printf "║     → %s paquet(s) manquant(s)\n" "$_M3"
else
    echo "║ [3] Audiovisuel ⚠️  (Score > 10 recommandé)"
fi
echo "║"

if [[ $_SCORE -gt 40 || $_VRAM -ge 4 ]]; then
    printf "║ [4] 3D/CAO/MAO ~4200€      %s Blender  %s FreeCAD  %s LMMS  %s Ardour\n" \
        "$(_mark blender)" "$(_mark freecad)" "$(_mark lmms)" "$(_mark ardour)"
    printf "║     → %s paquet(s) manquant(s)\n" "$_M4"
else
    echo "║ [4] 3D/CAO/MAO ⚠️  (Brain-Node ou GPU 4Go+ recommandé)"
fi

echo "╠══════════════════════════════════════════════════════════════╣"
echo "║ [5] TOUT INSTALLER   [0] Passer                             ║"
echo "╚══════════════════════════════════════════════════════════════╝"

## ── Sélection ─────────────────────────────────────────────────────────
if [[ "$_SILENT" == "true" ]]; then
    _desktop_choices="0"
    echo "ℹ️  Mode silencieux — aucun logiciel desktop supplémentaire."
else
    read -r -p "Choix des packs (ex: 1 2 3) [0] : " _desktop_choices
fi

## ── Construction de la liste des paquets à installer ─────────────────
_PKGS=()
_SAVINGS=0

if [[ "$_desktop_choices" == *"1"* || "$_desktop_choices" == *"5"* ]]; then
    _PKGS+=("${PACK1_PKGS[@]}"); _SAVINGS=$(( _SAVINGS + 1150 ))
fi
if [[ "$_desktop_choices" == *"2"* || "$_desktop_choices" == *"5"* ]]; then
    _PKGS+=("${PACK2_PKGS[@]}"); _SAVINGS=$(( _SAVINGS + 250 ))
fi
if [[ "$_desktop_choices" == *"3"* || "$_desktop_choices" == *"5"* ]]; then
    if [[ $_SCORE -gt 10 || "$_desktop_choices" != *"5"* ]]; then
        _PKGS+=("${PACK3_PKGS[@]}"); _SAVINGS=$(( _SAVINGS + 630 ))
    fi
fi
if [[ "$_desktop_choices" == *"4"* || "$_desktop_choices" == *"5"* ]]; then
    if [[ $_SCORE -gt 40 || $_VRAM -ge 4 || "$_desktop_choices" != *"5"* ]]; then
        _PKGS+=("${PACK4_PKGS[@]}"); _SAVINGS=$(( _SAVINGS + 4200 ))
    fi
fi

## ── Installation des paquets manquants uniquement ────────────────────
if [[ "${#_PKGS[@]}" -gt 0 ]]; then
    echo ">>> Installation des logiciels manquants..."
    for _p in "${_PKGS[@]}"; do
        if [[ "$(_installed "$_p")" -eq 0 ]]; then
            echo "    ❌ → installing $_p..."
            sudo apt install -y "$_p" \
                && echo "    ✅ $_p installé" \
                || { echo "INSTALL $_p FAILED." | tee -a "$_ERROR_LOG"; }
        else
            echo "    ✅ $_p déjà installé — ignoré"
        fi
    done
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    printf  "║  🎉 Économie logiciels libres : ~%s€/an                    ║\n" "$_SAVINGS"
    echo "╚══════════════════════════════════════════════════════════════╝"
fi
