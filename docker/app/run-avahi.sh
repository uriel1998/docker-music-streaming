#!/bin/sh
set -eu

if [ "${USE_AVAHI:-true}" != "true" ]; then
    exec sleep infinity
fi

if [ "${USE_HOST_AVAHI:-true}" = "true" ] && [ -S /run/avahi-daemon/socket ]; then
    exec sleep infinity
fi

# Stay in the foreground so Supervisor can monitor the Avahi daemon directly.
exec avahi-daemon --no-chroot --debug
