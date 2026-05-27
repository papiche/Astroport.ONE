#!/usr/bin/env bash

set -euo pipefail

show_help() {
cat << EOF
Usage:
  sudo ./clean-kernels.sh [OPTIONS]

Description:
  Nettoie automatiquement Linux Mint / Debian :
   - supprime les anciens kernels
   - conserve les 3 kernels les plus récents
   - garde toujours le kernel actuellement utilisé
   - nettoie APT
   - nettoie les paquets résiduels
   - nettoie les logs systemd
   - met à jour GRUB

Options:
  -h, --help           Affiche cette aide
  -n, --dry-run        Affiche ce qui serait supprimé sans rien faire
  -k, --keep N         Nombre de kernels à conserver (défaut: 3)
  --no-journal         Ne pas nettoyer journalctl
  --no-apt             Ne pas nettoyer APT
  --no-grub            Ne pas lancer update-grub

Exemples:
  sudo ./clean-kernels.sh
  sudo ./clean-kernels.sh --dry-run
  sudo ./clean-kernels.sh --keep 5
EOF
}

# Valeurs par défaut
KEEP_COUNT=3
DRY_RUN=false
CLEAN_JOURNAL=true
CLEAN_APT=true
UPDATE_GRUB=true

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -k|--keep)
            KEEP_COUNT="$2"
            shift 2
            ;;
        --no-journal)
            CLEAN_JOURNAL=false
            shift
            ;;
        --no-apt)
            CLEAN_APT=false
            shift
            ;;
        --no-grub)
            UPDATE_GRUB=false
            shift
            ;;
        *)
            echo "Option inconnue : $1"
            echo
            show_help
            exit 1
            ;;
    esac
done

echo "=== Nettoyage système Linux Mint / Debian ==="

# Vérifie root
if [[ $EUID -ne 0 ]]; then
    echo "Relance avec sudo."
    exit 1
fi

CURRENT_KERNEL="$(uname -r)"

echo
echo "Kernel actuel : $CURRENT_KERNEL"

if [[ "$CLEAN_APT" == true ]]; then
    echo
    echo "=== Nettoyage cache APT ==="

    if [[ "$DRY_RUN" == false ]]; then
        apt clean
        apt autoremove --purge -y
    else
        echo "[DRY RUN] apt clean"
        echo "[DRY RUN] apt autoremove --purge -y"
    fi
fi

echo
echo "=== Recherche des kernels installés ==="

mapfile -t INSTALLED_KERNELS < <(
    dpkg --list | awk '/^ii  linux-image-[0-9]/{print $2}' \
    | sed 's/linux-image-//' \
    | sort -V
)

echo "Kernels installés :"
printf ' - %s\n' "${INSTALLED_KERNELS[@]}"

echo
echo "=== Sélection des ${KEEP_COUNT} kernels les plus récents ==="

mapfile -t KEEP_KERNELS < <(
    printf '%s\n' "${INSTALLED_KERNELS[@]}" \
    | tail -n "$KEEP_COUNT"
)

# Toujours garder le kernel courant
if ! printf '%s\n' "${KEEP_KERNELS[@]}" | grep -qx "$CURRENT_KERNEL"; then
    KEEP_KERNELS[0]="$CURRENT_KERNEL"
fi

echo "Kernels conservés :"
printf ' - %s\n' "${KEEP_KERNELS[@]}"

echo
echo "=== Suppression des anciens kernels ==="

for KERNEL in "${INSTALLED_KERNELS[@]}"; do

    KEEP=false

    for KEEPK in "${KEEP_KERNELS[@]}"; do
        if [[ "$KERNEL" == "$KEEPK" ]]; then
            KEEP=true
            break
        fi
    done

    if [[ "$KEEP" == false ]]; then

        echo
        echo "Suppression de : $KERNEL"

        if [[ "$DRY_RUN" == false ]]; then

            apt purge -y \
                "linux-image-$KERNEL" \
                "linux-headers-$KERNEL" \
                "linux-modules-$KERNEL" \
                "linux-modules-extra-$KERNEL" \
                "linux-tools-$KERNEL" \
                || true

            rm -rf "/lib/modules/$KERNEL" || true

        else
            echo "[DRY RUN] apt purge linux-*-$KERNEL"
            echo "[DRY RUN] rm -rf /lib/modules/$KERNEL"
        fi
    fi
done

echo
echo "=== Nettoyage des paquets résiduels (rc) ==="

RC_PACKAGES=$(dpkg -l | awk '/^rc/ { print $2 }')

if [[ -n "${RC_PACKAGES:-}" ]]; then

    if [[ "$DRY_RUN" == false ]]; then
        dpkg -P $RC_PACKAGES || true
    else
        echo "[DRY RUN] dpkg -P $RC_PACKAGES"
    fi
fi

if [[ "$CLEAN_JOURNAL" == true ]]; then
    echo
    echo "=== Nettoyage des logs systemd ==="

    if [[ "$DRY_RUN" == false ]]; then
        journalctl --vacuum-time=7d || true
    else
        echo "[DRY RUN] journalctl --vacuum-time=7d"
    fi
fi

if [[ "$UPDATE_GRUB" == true ]]; then
    echo
    echo "=== Mise à jour GRUB ==="

    if [[ "$DRY_RUN" == false ]]; then
        update-grub
    else
        echo "[DRY RUN] update-grub"
    fi
fi

echo
echo "=== Résultat ==="

echo
echo "Kernels restants :"
ls /lib/modules

echo
echo "Occupation disque :"
df -h /

echo
echo "Taille /lib/modules :"
du -sh /lib/modules

echo
echo "=== Terminé ==="