#!/bin/bash
########################################################################
# Version: 0.3
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
{
[ $(id -u) -eq 0 ] && echo "LANCEMENT root INTERDIT. Utilisez un simple utilisateur du groupe \"sudo\" SVP" && exit 1

########################################################################
echo "DISABLE ipfs"
if [[ "$USER" == "xbian" ]]
then
    mv /etc/rc2.d/S02ipfs /etc/rc2.d/K01ipfs
    mv /etc/rc3.d/S02ipfs /etc/rc3.d/K01ipfs
    mv /etc/rc4.d/S02ipfs /etc/rc4.d/K01ipfs
    mv /etc/rc5.d/S02ipfs /etc/rc5.d/K01ipfs
else
    # DISABLE ipfs
    sudo systemctl disable ipfs
    sudo systemctl daemon-reload
fi

########################################################################
# RESTORE OLD KODI
[[ -e ~/.kodi.old ]] && echo "RESTORE KODI" && rm -Rf ~/.kodi && mv ~/.kodi.old ~/.kodi

########################################################################
# RESTORE resolv.conf
[[ -s /etc/resolv.conf.backup ]] &&  echo "RESTORE resolv.conf" \
            && sudo chattr -i /etc/resolv.conf \
            && sudo cat /etc/resolv.conf.backup > /etc/resolv.conf


########################################################################
echo "REMOVE cron_MINUTE from CRONTAB"
crontab -l > /tmp/mycron
# Remove any previous line containing "cron_MINUTE"
awk -i inplace -v rmv="20h12.process.sh" '!index($0,rmv)' /tmp/mycron
crontab /tmp/newcron
rm -f /tmp/mycron

########################################################################
echo "REMOVE /etc/sudoers EXTRA PERMISSION"
[[ "$USER" == "xbian" ]] && rm -f /etc/sudoers.d/astroport
sudo rm -f /etc/sudoers.d/fail2ban-client
sudo rm -f /etc/sudoers.d/mount
sudo rm -f /etc/sudoers.d/umount
sudo rm -f /etc/sudoers.d/apt-get
sudo rm -f /etc/sudoers.d/apt
sudo rm -f /etc/sudoers.d/systemctl

mv ~/.zen ~/.zen.todelete
echo "ASTROPORT DESACTIVATED. FINISH MANUAL REMOVE
RUN :  rm -RF ~/.zen.todelete"

}
