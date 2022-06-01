#!/bin/bash
######################################################################### ADD ASTROPORT DESKTOP SHORTCUT
[[ -d ~/Bureau ]] && sed "s/_USER_/$USER/g" ~/.zen/astrXbian/.install/astroport.desktop > ~/Bureau/astroport.desktop && chmod +x ~/Bureau/astroport.desktop
[[ -d ~/Desktop ]] && sed "s/_USER_/$USER/g" ~/.zen/astrXbian/.install/astroport.desktop > ~/Desktop/astroport.desktop && chmod +x ~/Desktop/astroport.desktop
