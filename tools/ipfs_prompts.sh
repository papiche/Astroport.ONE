#!/bin/bash
########################################################
# this script show (extreme control) ipfs commands
#########################################################

#############################
# remove all pins from node
echo "UNPIN ALL"
echo "ipfs pin ls -q --type recursive | xargs ipfs pin rm"

#############################
# empty garbage collector
echo "EMPTY GC"
echo "ipfs repo gc"

#############################
# get IPNS actual CID
echo "ipfs name resolve $ipnskey"

