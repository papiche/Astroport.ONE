#!/bin/bash
# ROUGHLY CONVERT MOATS IN SECONDS
MOATS=$1
[[ ${MOATS} == "" ]] && MOATS=0
ZMOATS=${MOATS::-4}

# Calculate the number of days in the specified month (for simplicity, assuming 30 days per month)
DAYS_IN_MONTH=30

# Calculate ZMOATS in seconds since the epoch manually
YEAR=${ZMOATS:0:4}
SECYEAR=$((YEAR * 365 * 24 * 3600))

MONTH=$((${ZMOATS:4:2}+0))
SECMONTH=$((MONTH * DAYS_IN_MONTH * 24 * 3600))

DAY=$((${ZMOATS:6:2}+0))
SECDAY=$((DAY * 24 * 3600))

HOUR=$((${ZMOATS:8:2}+0))
SECHOUR=$((HOUR * 3600))

MINUTE=$((${ZMOATS:10:2}+0))
SECMINUTE=$((MINUTE * 60))

SECOND=$((${ZMOATS:12:2}+0))


# Calculate the time difference in seconds
ZMOATS_SECONDS=$((SECYEAR + SECMONTH + SECDAY + SECHOUR + SECMINUTE + SECOND))

echo "$ZMOATS_SECONDS"
exit 0
