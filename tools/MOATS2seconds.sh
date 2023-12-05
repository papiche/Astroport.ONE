#!/bin/bash
# ROUGHLY CONVERT moats IN SECONDS
moats="$1"

[[ ${moats} == "" ]] && echo 0 && exit 1
Zmoats=${moats::-4}

# Calculate the number of days in the specified month (for simplicity, assuming 30 days per month)
DAYS_IN_MONTH=30

# Calculate Zmoats in seconds since the epoch manually
YEAR=${Zmoats:0:4}
SECYEAR=$((YEAR * 365 * 24 * 3600))

MONTH=$((${Zmoats:4:2}+0))
SECMONTH=$((MONTH * DAYS_IN_MONTH * 24 * 3600))

DAY=$((${Zmoats:6:2}+0))
SECDAY=$((DAY * 24 * 3600))

HOUR=$((${Zmoats:8:2}+0))
SECHOUR=$((HOUR * 3600))

MINUTE=$((${Zmoats:10:2}+0))
SECMINUTE=$((MINUTE * 60))

SECOND=$((${Zmoats:12:2}+0))


# Calculate the time difference in seconds
Zmoats_SECONDS=$(( SECYEAR + SECMONTH + SECDAY + SECHOUR + SECMINUTE + SECOND))

echo "$Zmoats_SECONDS"
exit 0

