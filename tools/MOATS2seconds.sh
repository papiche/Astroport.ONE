#!/bin/bash
# ROUGHLY CONVERT MOATS IN SECONDS
MOATS=$1
ZMOATS=${MOATS::-4}

# Calculate ZMOATS in seconds since the epoch manually
YEAR=${ZMOATS:0:4}
MONTH=${ZMOATS:4:2}
DAY=${ZMOATS:6:2}
HOUR=${ZMOATS:8:2}
MINUTE=${ZMOATS:10:2}
SECOND=${ZMOATS:12:2}

# Calculate the number of days in the specified month (for simplicity, assuming 30 days per month)
DAYS_IN_MONTH=30

# Calculate the time difference in seconds
ZMOATS_SECONDS=$((YEAR * 365 * 24 * 3600 + (MONTH - 1) * DAYS_IN_MONTH * 24 * 3600 + (DAY - 1) * 24 * 3600 + HOUR * 3600 + MINUTE * 60 + SECOND))

echo "$ZMOATS_SECONDS"
exit 0
