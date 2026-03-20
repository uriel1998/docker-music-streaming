#!/bin/sh
set -eu

# Scrobbling is configured entirely from the host-mounted config file.
if [ -f /config/mpdscribble.conf ]; then
    cp /config/mpdscribble.conf /etc/mpdscribble.conf
fi

# Do not run the service unless both credentials are actually populated.
if ! grep -Eq '^[[:space:]]*username[[:space:]]*=[[:space:]]*[^[:space:]#]+' /etc/mpdscribble.conf; then
    exec sleep infinity
fi

if ! grep -Eq '^[[:space:]]*password[[:space:]]*=[[:space:]]*[^[:space:]#]+' /etc/mpdscribble.conf; then
    exec sleep infinity
fi

mkdir -p /var/cache/mpdscribble

# Keep logging on stdout/stderr for `docker compose logs`.
exec mpdscribble --no-daemon --conf /etc/mpdscribble.conf --log -
