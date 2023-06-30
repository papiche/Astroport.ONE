#!/usr/bin/env sh
[ -n "${DEBUG}" ] && set -x
set -euo errexit

ASTROPORT_DIR=/home/zen/.zen/Astroport.ONE
ASTROPORT_REPO=https://git.p2p.legal/qo-op/Astroport.ONE.git

cron() {
  sudo service cron start
}

log() {
  tail -F /var/log/auth.log /var/log/pam-script.log >&2
}

zen() {
  mkdir -p /home/zen/Astroport
  sudo chown zen:users /home/zen /home/zen/.zen /home/zen/.zen/game /home/zen/.zen/game/players
  [ -d "$ASTROPORT_DIR" ] && cd "$ASTROPORT_DIR" && git pull -q || git clone -q "$ASTROPORT_REPO" "$ASTROPORT_DIR"
  cd "$ASTROPORT_DIR" && make
}

case "${1:-${cmd:-start}}" in

  start)
    cron
    log &
    zen
    sudo systemctl restart ipfs
    sudo systemctl restart g1billet
    sudo systemctl restart astroport
    # exec "$ASTROPORT_DIR/launch.sh"
  ;;

  install)
    exec /install.sh
  ;;

  *)
    exec "$@"
  ;;

esac
