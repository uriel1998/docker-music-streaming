#!/bin/sh
set -eu

# Allow the whole Snapcast branch to be disabled without editing the base image.
if [ "${USE_SNAPCAST:-true}" != "true" ]; then
    exec sleep infinity
fi

# Copy both the main config and optional distro-style defaults from `/config`.
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

# Snapserver serves both the synchronization protocol and the bundled Snapweb UI.
exec snapserver --logging.sink=stderr --server.datadir=/var/lib/snapserver ${SNAPSERVER_OPTS:-}
