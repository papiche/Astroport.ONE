#!/usr/bin/env sh
[ -n "${DEBUG}" ] && set -x
set -euo errexit

ASTROPORT_DIR=/home/zen/.zen/Astroport.ONE
ASTROPORT_REPO=https://github.com/papiche/Astroport.ONE.git

cron() {
  sudo service cron start
}

log() {
  tail -F /var/log/auth.log /var/log/pam-script.log >&2
}

zen() {
  sudo chown zen:users /home/zen /home/zen/.zen /home/zen/.zen/game /home/zen/.zen/game/players
  mkdir -p /home/zen/Astroport
  [ -d "$ASTROPORT_DIR" ] && cd "$ASTROPORT_DIR" && git pull -q || git clone -q "$ASTROPORT_REPO" "$ASTROPORT_DIR"
}

case "${1:-${cmd:-start}}" in

  start)
    cron
    log &
    zen
    exec "$ASTROPORT_DIR/launch.sh"
  ;;

  install)
    exec /install.sh
  ;;

  *)
    exec "$@"
  ;;

esac
