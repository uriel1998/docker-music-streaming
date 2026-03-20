#!/bin/sh
set -eu

# Always prefer the host-managed config when it is present.
if [ -f /config/minidlna.conf ]; then
    cp /config/minidlna.conf /etc/minidlna.conf
fi

mkdir -p /var/cache/minidlna

# `-S` keeps MiniDLNA in the foreground so Supervisor can restart it.
exec minidlnad -S -f /etc/minidlna.conf -P /run/music-stack/minidlna.pid
