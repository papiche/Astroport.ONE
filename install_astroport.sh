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

echo "Hello,

This script (you could read and modify as it is open source software) is about to transform your computer into an astroport station.

This process involve different upgrades to be made on your system.
1. install IPFS, the interplanetary file system (https://ipfs.io)
2. install python cryptographic libraries to run natools, your key wizard companion
3. download 'astroport' code release you have choosen.

~/.zen directory and datastructure will emerge
~/.zen/ipfs & ~/.zen/ipfs_swarm contains all meshed media index from you and your friends.

ASTROPORT is activated by cron every minute it maintains the connection with your friends.
It is the vessel that gives you avvess to your p2p AVATAR.
You carry and share your data around your friends through a confidence network
established through 1 to 5 'hearts' exchanged, opening 5 stargates where any can push/pull data.

TODO
Just indicate which is the directory assigned to each star.
Then any of your friends from such star level can replicate (modify) those data with you.

Your station is publishing its index every time it changes and every 6 hours for all MEDIAKEY from PIN station.
Following that principle add new directory into ~/.zen/ipfs and index any dataset, it will be published on your IPFS semaphore.

Now you need to enter your password to obtain sudo access.
Please.
"
# Ask user password on start
sudo true

## Error funciton
err() {
    echo -e "ERREUR: $1"
    exit 1
}

# CHECK if daemon is already running
if [[ $(ps auxf --sort=+utime | grep -w ipfs | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1) ]]; then
    ipfs id && echo "ipfs swarm peers: " && ipfs swarm peers
    echo "ipfs bootstrap list: " && ipfs bootstrap list
    echo "ipfs daemon already running...! Must STOP ipfs AND remove ~/.ipfs to install again !!"
    echo "Please RUN : sudo service ipfs stop"
    exit 1
fi

[[ -d ~/.ipfs ]] && echo "IPFS install exist! Please remove or backup before executing this script EXIT" && exit 1

echo -e "Check and install python curl, git and tools."

[[ $(which pip3) ]] &&  python3 -m pip install -U pip && python3 -m pip install -U wheel cryptography Ed25519 base58 google protobuf duniterpy==0.62.0 termcolor python-dotenv gql==3.0.0a5 requests pybase64 || (echo "python3 pip3 is missing on your device. EXIT" && exit 1)
[[ ! $(which curl) ]] && sudo apt-get install curl -y
[[ ! $(which git) ]] && sudo apt-get install git -y

[[ ! -d ~/.zen ]] && mkdir ~/.zen

# CHECK node IP isLAN?
myIP=$(hostname -I | awk '{print $1}')
echo "Your IP is $myIP"
isLAN=$(echo $myIP | grep -E "/(^127\.)|(^192\.168\.)|(^10\.)|(^172\.1[6-9]\.)|(^172\.2[0-9]\.)|(^172\.3[0-1]\.)|(^::1$)|(^[fF][cCdD])/")
[[ $isLAN ]] && echo "You are located in a LAN" || echo "You have a public IP address"
MACHINE_TYPE=`uname -m`
echo "You are running $MACHINE_TYPE CPU"

echo "Downloading ipfs binaries"
if [ ${MACHINE_TYPE} == 'x86_64' ]; then
    curl -s https://dist.ipfs.io/ipfs-update/v1.6.0/ipfs-update_v1.6.0_linux-amd64.tar.gz -o $MY_PATH/ipfs-update.tar.gz
elif [ ${MACHINE_TYPE:0:3} == 'arm' ]; then
    curl -s https://dist.ipfs.io/ipfs-update/v1.6.0/ipfs-update_v1.6.0_linux-arm.tar.gz -o $MY_PATH/ipfs-update.tar.gz
elif [ ${MACHINE_TYPE} == 'aarch64' ]; then
    curl -s https://dist.ipfs.io/go-ipfs/v0.9.1/go-ipfs_v0.9.1_linux-arm64.tar.gz -o /tmp/ipfs_aarch64_v0.9.1.tar.gz
else
    echo "Your $MACHINE_TYPE is not supported yet... Please add an issue." && exit 1
fi

if  [ -f $MY_PATH/ipfs-update.tar.gz ]; then
    echo "INSTALL ipfs-update >>>>>>>>>>>>>>>>>>>>>>>>>>"
    sudo tar -xvzf $MY_PATH/ipfs-update.tar.gz -C /usr/src/ || err "Untar ipfs-update"
    rm $MY_PATH/ipfs-update.tar.gz
    cd /usr/src/ipfs-update/
    sudo ./install.sh || err "Install ipfs-update"
    cd $MY_PATH

    echo "INSTALL ipfs 0.9.1 >>>>>>>>>>>>>>>>>>>>>>>>>>"
    sudo ipfs-update install 0.9.1 || err "Install IPFS"

else
    ## TERRAPI4 aarch64 install ipfs_aarch64_v0.9.1
    echo "INSTALL ipfs 0.9.1 >>>>>>>>>>>>>>>>>>>>>>>>>> arm64"
    sudo tar -xvzf /tmp/ipfs_aarch64_v0.9.1.tar.gz -C /usr/src/ || err "Untar ipfs_aarch64"
    rm /tmp/ipfs_aarch64_v0.9.1.tar.gz
    cd /usr/src/go-ipfs/
    sudo ./install.sh || err "Install ipfs_aarch64"
    cd $MY_PATH

fi

# INIT ipfs
[[ $isLAN ]] && ipfs init -p lowpower \
|| ipfs init -p server

## Special Xbian init.d config
    ## DEBIAN SYSTEMCTL
    echo "SYSTEMD ipfs SERVICE >>>>>>>>>>>>>>>> ON"
cat > /tmp/ipfs.service <<EOF
[Unit]
Description=IPFS daemon
After=network.target

[Service]
User=_USER_
ExecStart=/usr/local/bin/ipfs daemon --enable-pubsub-experiment --enable-namesys-pubsub --enable-gc
Restart=on-failure
CPUAccounting=true
CPUQuota=60%

[Install]
WantedBy=multi-user.target
EOF

    sudo cp -f /tmp/ipfs.service /etc/systemd/system/
    sudo sed -i "s/_USER_/$USER/g" /etc/systemd/system/ipfs.service
    echo "Activating ipfs daemon >>>>>>>>>>>>>>>>>> "
#    echo "Vous pouvez régler la ressouce CPU maximum (60%)?" && read cpuy

    [[ -d ~/.ipfs ]] && sudo chown -R $USER:$USER ~/.ipfs
    sudo systemctl daemon-reload
    sudo systemctl enable ipfs


###########################################
echo "# ACTIVATE IPFS OPTIONS: #swarm0 INIT"
###########################################
### IMPORTANT !!!!!!! IMPORTANT !!!!!!
###########################################
# DHT PUBSUB mode
ipfs config Pubsub.Router gossipsub
# MAXSTORAGE = 1/2 available
availableDiskSize=$(df -P ~/ | awk 'NR>1{sum+=$4}END{print sum}')
diskSize="$((availableDiskSize / 2))"
ipfs config Datastore.StorageMax $diskSize
## Activate Rapid "ipfs p2p"
ipfs config --json Experimental.Libp2pStreamMounting true
ipfs config --json Experimental.P2pHttpProxy true
ipfs config --json Swarm.ConnMgr.LowWater 50
ipfs config --json Swarm.ConnMgr.HighWater 100

## Install gateway on 8181 port
ipfs config Addresses.Gateway "/ip4/127.0.0.1/tcp/8181"

########################################################################
# GET IPFS KEYS & CONVERSIONS
########################################################################
IPFSNODEID=$(ipfs config Identity.PeerID)
## TODO convert to secret.dunikey

########################################################################
echo "CREATION IDENTITE BALISE IPFS ~/.zen/ipfs/.${IPFSNODEID} /G1SSB"
########################################################################
rm -Rf ~/.zen/ipfs
mkdir -p ~/.zen/ipfs/.${IPFSNODEID}/G1SSB
########################################################################
# Give $XZUID to your (gchange friends)
########################################################################
XZUID="$(hostname)-$RANDOM$RANDOM"
echo "SETTING .player PROFILE NAME = $XZUID"
echo "$XZUID" > ~/.zen/ipfs/.${IPFSNODEID}/.player
echo 'balise /ipns/$IPFSNODEID/.$IPFSNODEID/.player'

########################################################################
########################################################################
echo "Getting tryme.addr & .mycode from OASIS
-- Change oasis address to fork your Astroport Code Universe --"
########################################################################
ipfs bootstrap rm --all

OASIS=12D3KooWBYme2BsNUrtx4mEdNX6Yioa9AV7opWzQp6nrPs6ZKabN
# aries=12D3KooWSQYTxeoZZ39SNosEKxi7RUdGTtAQAqpKeZJxjzqqrZTx
for bootnode in $(curl -s https://tube.copylaradio.com/ipns/$OASIS/.$OASIS/tryme.addr)
do
    ## ADD $bootnode TO BOOTSTRAP
    ipfs bootstrap add $bootnode
done

codesign=$(curl -s https://tube.copylaradio.com/ipns/$OASIS/.$OASIS/.mycode)

## ADD NETWORK EXPLORATION FROM LIKES
########################################################################
echo "RESTARTING ipfs"
########################################################################
sudo service ipfs restart
echo ".... WAIT for SWARM to connect ..."
sleep 10

echo ".... ACTUAL SWARM PEERS ..."
ipfs swarm peers

echo "IPFS DONE
====================
Station Astroport INSTALL
Activation ~/.zen/astrXbian/zen/cron_VRFY.sh
Récupération CODE /ipfs/$codesign
"

## GETTING SAME SOURCE CODE AS OASIS
mkdir -p /home/$USER/.zen/astrXbian/
ipfs get --output=/home/$USER/.zen/astrXbian/ /ipfs/$codesign

## Make scripts executable
find /home/$USER/.zen/astrXbian/ -name "*.sh" -exec chmod u+x '{}' \;
find /home/$USER/.zen/astrXbian/ -name "*.py" -exec chmod u+x '{}' \;

########################################################################
echo "# Setting $USER SUDO permissions ON fail2ban mount umount apt-get apt systemctl"
########################################################################
## USED FOR fail2ban-client (DEFCON)
echo "$USER ALL=(ALL) NOPASSWD:/usr/bin/fail2ban-client" | (sudo su -c 'EDITOR="tee" visudo -f /etc/sudoers.d/fail2ban-client')
## USED FOR RAMDISK (video live streaming)
echo "$USER ALL=(ALL) NOPASSWD:/bin/mount" | (sudo su -c 'EDITOR="tee" visudo -f /etc/sudoers.d/mount')
echo "$USER ALL=(ALL) NOPASSWD:/bin/umount" | (sudo su -c 'EDITOR="tee" visudo -f /etc/sudoers.d/umount')
## USED FOR SYSTEM UPGRADE
echo "$USER ALL=(ALL) NOPASSWD:/usr/bin/apt-get" | (sudo su -c 'EDITOR="tee" visudo -f /etc/sudoers.d/apt-get')
echo "$USER ALL=(ALL) NOPASSWD:/usr/bin/apt" | (sudo su -c 'EDITOR="tee" visudo -f /etc/sudoers.d/apt')
## USED FOR "systemctl restart ipfs"
echo "$USER ALL=(ALL) NOPASSWD:/bin/systemctl" | (sudo su -c 'EDITOR="tee" visudo -f /etc/sudoers.d/systemctl')

## TODO G1SSB CONFIG
echo "## INSTALL TiddlyWiki /ipns/${IPFSNODEID}/.${IPFSNODEID}/index.html"
[[ ! -f ~/.zen/ipfs/.${IPFSNODEID}/index.html ]] && mkdir -p ~/.zen/ipfs/.${IPFSNODEID} && cp ~/.zen/astrXbian/.install/templates/tiddlywiki/index.html ~/.zen/ipfs/.${IPFSNODEID}/index.html


echo "Congratulation ! You are part of the astroport interplanetary fleet.

New. Activate your station offline storage.
Install ipfs companion : https://docs.ipfs.io/install/ipfs-companion/
FR : https://translate.google.com/translate?sl=auto&tl=fr&u=https://docs.ipfs.io/install/ipfs-companion/
"

echo "FIND AND CONNECT WITH YOUR FRIENDS
https://tube.copylaradio.com/ipns/$OASIS/.$OASIS/"
## OPEN https://translate.google.com/translate?sl=auto&tl=fr&u=https://docs.ipfs.io/install/ipfs-companion/

} # this ensures the entire script is downloaded #
# IPFS CONFIG documentation: https://github.com/ipfs/go-ipfs/blob/master/docs/config.md#addressesswarm
