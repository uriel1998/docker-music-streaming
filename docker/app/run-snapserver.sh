#!/bin/sh
set -eu

if [ "${USE_SNAPCAST:-true}" != "true" ]; then
    exec sleep infinity
fi

if [ -f /config/snapserver.conf ]; then
    cp /config/snapserver.conf /etc/snapserver.conf
fi

if [ -f /config/snapserver ]; then
    cp /config/snapserver /etc/default/snapserver
fi

mkdir -p /var/lib/snapserver /pipe

if [ -f /etc/default/snapserver ]; then
    # shellcheck disable=SC1091
    . /etc/default/snapserver
fi

exec snapserver --logging.sink=stderr --server.datadir=/var/lib/snapserver ${SNAPSERVER_OPTS:-}
