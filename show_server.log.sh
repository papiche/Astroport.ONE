#!/bin/bash
#############################################################
## DISPLAY SERVER LOG FILES
#############################################################
## 1234 API ~/.zen/tmp/12345.log
## 12345 API ~/.zen/tmp/_12345.log
#############################################################

[[ ! $(which multitail) ]] && sudo apt install multitail

multitail -s 2 -I ~/.zen/tmp/12345.log ~/.zen/tmp/_12345.log
