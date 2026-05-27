#!/bin/bash
########################################################################
# install_sudoers.sh — Configuration NOPASSWD sudoers pour Astroport.ONE
#
# Idempotent : peut être relancé à chaque upgrade.
# Extrait de install_system.sh pour être réutilisable indépendamment.
# Appelé par : install_system.sh (premier install) et install.sh (upgrade).
# License: AGPL-3.0
########################################################################
[ $(id -u) -eq 0 ] && echo "LANCEMENT root INTERDIT." && exit 1

echo "######### SUDOERS ASTROPORT (NOPASSWD) #########"

########################################################################
## Full sudo pour le capitaine (NOPASSWD:ALL) — requis pour install/upgrade
########################################################################
echo "$USER ALL=(ALL) NOPASSWD:ALL" \
    | (sudo su -c 'EDITOR="tee" visudo -f /etc/sudoers.d/captain') \
    && echo "SUDOERS captain : NOPASSWD:ALL"

########################################################################
## NOPASSWD explicite par binaire (défense en profondeur)
## Liste : services utilisés par Astroport (ramdisk, systemctl, firewall, bench disque, etc.)
########################################################################
for bin in \
    fail2ban-client mount umount \
    apt-get apt \
    systemctl \
    ufw \
    docker \
    hdparm \
    powerjoular \
    kill \
    brother_ql_print
do
    binpath=$(which "$bin" 2>/dev/null)
    if [[ -n "$binpath" && -x "$binpath" ]]; then
        echo "$USER ALL=(ALL) NOPASSWD:$binpath" \
            | (sudo su -c 'EDITOR="tee" visudo -f /etc/sudoers.d/'"$bin") \
            && echo "SUDOERS RIGHT SET FOR : $binpath" \
            || echo "ERROR setting sudoers for $bin"
    else
        echo "SKIP (not found or not executable): $bin"
    fi
done

echo "######### SUDOERS OK ############################"
