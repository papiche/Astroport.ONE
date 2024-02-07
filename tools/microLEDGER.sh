#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"${MY_PATH}\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/my.sh"

## RECEVEIVE A UPlanet shared key
# Takes care of maintaining micro-ledger
# copying & swifting IPNS key
# applying token ring distibution and examine "boostrap list"
