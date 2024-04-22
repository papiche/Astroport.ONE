#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
## TRANSFORM EMAIL IN IPNS NAMING ADDRESS
# mail=geg-la_debrouille@super.chez-moi.com
YUSER=$(echo "${1}" | cut -d '@' -f1)    # YUSER=geg-la_debrouille
LYUSER=($(echo "$YUSER" | sed 's/[^a-zA-Z0-9]/\ /g')) # LYUSER=(geg la debrouille)
CLYUSER=$(printf '%s\n' "${LYUSER[@]}" | tac | tr '\n' '.' ) # CLYUSER=debrouille.la.geg.
YOMAIN=$(echo "${1}" | cut -d '@' -f 2)    # YOMAIN=super.chez-moi.com
echo "${CLYUSER}${YOMAIN}"
