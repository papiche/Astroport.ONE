#!/bin/bash
########################################################################
# Author: Fred (support@qo-op.com)
# Version: 2020.12.05
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
# FirstBOOT.sh
# Let AstrXbian ISO resize Filesystem 
# Change /etc/rc.local to activate ISOconfig.sh n next reboot
# 

sudo sed -i "s/FirstBOOT/ISOconfig/g" /etc/rc.local

exit 0
