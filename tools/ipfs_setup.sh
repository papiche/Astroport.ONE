#!/bin/bash
########################################################################
{ # this ensures the entire script is downloaded #
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

# CHECK not root user !!
if [ "$EUID" -eq 0 ]
  then echo -e "DO NOT EXECUTE AS root. Choose a user for your Astroport Station (we like pi)"
  exit 1
else echo -e "OK $USER, let's go!";
fi

# Ask user password on start
sudo true

## Error funciton
err() {
    echo -e "ERREUR: $1"
    exit 1
}

# CHECK node IP isLAN?
myIP=$(hostname -I | awk '{print $1}')
isLAN=$(route -n |awk '$1 == "0.0.0.0" {print $2}' | grep -E "/(^127\.)|(^192\.168\.)|(^10\.)|(^172\.1[6-9]\.)|(^172\.2[0-9]\.)|(^172\.3[0-1]\.)|(^::1$)|(^[fF][cCdD])/")
YOU=$(ipfs swarm peers >/dev/null 2>&1 && echo "$USER" || ps auxf --sort=+utime | grep -w ipfs | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1);

MACHINE_TYPE=`uname -m`

# CHECK if daemon is already running
if [[ $YOU ]]; then
    echo "ipfs daemon already running...! Run by $YOU $MACHINE_TYPE"
    [[ $YOU == $USER ]] && echo "Stopping ipfs daemon" && killall ipfs \
                                        || (echo "ERROR $YOU is running ipfs, must be $USER" && exit 1)
else
    # REINIT ipfs
    [[ -s ~/.ipfs/config ]] && echo ">>> WARNING BACKUP OLD IPFS CONFIG ~/.ipfs/config.old"
    rm -f ~/.ipfs/config.old 2>/dev/null
    mv ~/.ipfs/config ~/.ipfs/config.old 2>/dev/null

    [[ $isLAN ]] && ipfs init -p lowpower \
    || ipfs init -p server
    # RESET NODE SECRET
    rm -f ~/.zen/game/secret.* 2>/dev/null
fi

echo -e "Astroport activate IPFS Layer installation..."

if [[ "$USER" == "xbian" ]]
then
    echo "enabling ipfs initV service autostart"
    cd /etc/rc2.d && sudo ln -s ../init.d/ipfs S02ipfs
    cd /etc/rc3.d && sudo ln -s ../init.d/ipfs S02ipfs
    cd /etc/rc4.d && sudo ln -s ../init.d/ipfs S02ipfs
    cd /etc/rc5.d && sudo ln -s ../init.d/ipfs S02ipfs

    cd /etc/rc0.d && sudo ln -s ../init.d/ipfs K01ipfs
    cd /etc/rc1.d && sudo ln -s ../init.d/ipfs K01ipfs
    cd /etc/rc6.d && sudo ln -s ../init.d/ipfs K01ipfs

    # Disable xbian-config auto launch
    echo 0 > ~/.xbian-config-start

fi

    ## DEBIAN
    echo "CREATE SYSTEMD ipfs SERVICE >>>>>>>>>>>>>>>>>>"
cat > /tmp/ipfs.service <<EOF
[Unit]
Description=IPFS daemon
After=network.target
Requires=network.target

[Service]
Type=simple
User=_USER_
RestartSec=1
Restart=always
Environment=IPFS_FD_MAX=8192
ExecStart=/usr/local/bin/ipfs daemon --migrate --enable-pubsub-experiment --enable-namesys-pubsub --routing=dhtclient
CPUAccounting=true
CPUQuota=60%

[Install]
WantedBy=multi-user.target
EOF

    ## LAN is dhtclient only
    [[ ! $isLAN ]] \
        && sed -i "s/--routing=dhtclient//g" /tmp/ipfs.service

    sudo cp -f /tmp/ipfs.service /etc/systemd/system/
    sudo sed -i "s/_USER_/$USER/g" /etc/systemd/system/ipfs.service


sudo systemctl daemon-reload
sudo systemctl enable ipfs

###########################################
# ACTIVATE IPFS OPTIONS: #swarm0 INIT
###########################################
$MY_PATH/ipfs_config.sh

sudo systemctl restart ipfs

## Add ulimit "open files" (avoid ipfs hang)
ulimit -n 2048

} # this ensures the entire script is downloaded #
# IPFS CONFIG documentation: https://github.com/ipfs/go-ipfs/blob/master/docs/config.md#addressesswarm
# https://github.com/ipfs/kubo/blob/master/docs/config.md

# VISUALISER DHT
# ipfs stats dht wan

# CONSUMING RESSOURCES
# export DPID=26024; watch -n0 'printf "sockets: %s\nleveldb: %s\nflatfs: %s\n" $(ls /proc/${DPID}/fd/ -l | grep "socket:" | wc -l) $(ls /proc/${DPID}/fd/ -l | grep "\\/datastore\\/" | wc -l) $(ls /proc/${DPID}/fd/ -l | grep "\\/blocks\\/" | wc -l)'
