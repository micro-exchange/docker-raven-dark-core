#!/bin/sh
set -e

if [ $(echo "$1" | cut -c1) = "-" ]; then
  echo "$0: assuming arguments for ravendarkd"

  set -- ravendarkd "$@"
fi

if [ $(echo "$1" | cut -c1) = "-" ] || [ "$1" = "ravendarkd" ]; then
  mkdir -p "$RAVENDARK_DATA"
  chmod 700 "$RAVENDARK_DATA"
  chown -R ravendark "$RAVENDARK_DATA"

  echo "$0: setting data directory to $RAVENDARK_DATA"

  set -- "$@" -datadir="$RAVENDARK_DATA"
fi

if [ "$1" = "ravendarkd" ] || [ "$1" = "ravendark-cli" ] || [ "$1" = "ravendark-tx" ]; then
  echo
  exec su-exec ravendark "$@"
fi

echo
exec "$@"