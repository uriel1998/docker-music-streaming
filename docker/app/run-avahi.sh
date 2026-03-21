#!/bin/sh
set -eu

if [ "${USE_AVAHI:-true}" != "true" ]; then
    exec sleep infinity
fi

# Stay in the foreground so Supervisor can monitor the Avahi daemon directly.
exec avahi-daemon --no-chroot --debug
