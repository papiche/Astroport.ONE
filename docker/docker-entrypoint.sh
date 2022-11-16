#!/usr/bin/env sh
set -euo errexit

# Print a debug message if debug mode is on ($DEBUG is not empty)
# @param message
debug_msg ()
{
  if [ -n "${DEBUG:-}" -a "${DEBUG:-}" != "false" ]; then
    echo "$@"
  fi
}

mkdir -p /home/zen/.zen/tmp
SOURCE_DIR="/home/zen/.zen/Astroport.ONE"
[ -d "$SOURCE_DIR" ] && cd "$SOURCE_DIR" && git pull -q || git clone -q https://git.p2p.legal/qo-op/Astroport.ONE.git "$SOURCE_DIR"
cd "$SOURCE_DIR"

sudo -n /usr/sbin/cron -L/dev/stdout

case "${1:-${cmd:-start}}" in

  start)
    debug_msg "Starting $SOURCE_DIR/start.sh ..."
    exec "$SOURCE_DIR"/start.sh
  ;;

  install)
    debug_msg "Installing..."
    exec /install.sh
  ;;

  *)
    debug_msg "Exec: $@"
    exec "$@"
  ;;

esac
