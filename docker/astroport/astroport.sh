#!/usr/bin/env sh
[ -n "${DEBUG}" ] && set -x
set -euo errexit

ASTROPORT_DIR=/home/zen/.zen/Astroport.ONE
ASTROPORT_REPO=https://git.p2p.legal/qo-op/Astroport.ONE.git

cron() {
  sudo service cron start
}

log() {
  tail -F /var/log/fail2ban.log /var/log/syslog /var/log/auth.log /var/log/pam-script.log >&2
}

zen() {
  rm -rf /home/zen/.zen/tmp \
   && mkdir -p /dev/shm/tmp \
   && ln -s /dev/shm/tmp /home/zen/.zen/tmp
  [ -d "$ASTROPORT_DIR" ] && cd "$ASTROPORT_DIR" && git pull -q || git clone -q "$ASTROPORT_REPO" "$ASTROPORT_DIR"
}

case "${1:-${cmd:-start}}" in

  start)
    cron
    log &
    zen
    exec "$ASTROPORT_DIR/start.sh"
  ;;

  install)
    exec /install.sh
  ;;

  *)
    exec "$@"
  ;;

esac
