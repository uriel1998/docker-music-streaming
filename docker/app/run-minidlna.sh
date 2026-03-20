#!/bin/sh
set -eu

if [ -f /config/minidlna.conf ]; then
    cp /config/minidlna.conf /etc/minidlna.conf
fi

mkdir -p /var/cache/minidlna

exec minidlnad -S -f /etc/minidlna.conf -P /run/music-stack/minidlna.pid
