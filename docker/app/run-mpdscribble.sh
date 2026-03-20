#!/bin/sh
set -eu

if [ -f /config/mpdscribble.conf ]; then
    cp /config/mpdscribble.conf /etc/mpdscribble.conf
fi

if ! grep -Eq '^[[:space:]]*username[[:space:]]*=[[:space:]]*[^[:space:]#]+' /etc/mpdscribble.conf; then
    exec sleep infinity
fi

if ! grep -Eq '^[[:space:]]*password[[:space:]]*=[[:space:]]*[^[:space:]#]+' /etc/mpdscribble.conf; then
    exec sleep infinity
fi

mkdir -p /var/cache/mpdscribble

exec mpdscribble --no-daemon --conf /etc/mpdscribble.conf --log -
