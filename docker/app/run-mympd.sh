#!/bin/sh
set -eu

export MPD_HOST="${MPD_HOST:-mycomplicatedpassword@127.0.0.1}"
export MPD_PORT="${MPD_PORT:-6600}"
export MYMPD_HTTP_PORT="${MYMPD_HTTP_PORT:-8080}"
export MYMPD_SSL="${MYMPD_SSL:-false}"
export MYMPD_SSL_PORT="${MYMPD_SSL_PORT:-443}"
export MYMPD_LOGLEVEL="${MYMPD_LOGLEVEL:-5}"

mkdir -p /var/lib/mympd /var/cache/mympd

if [ ! -d /var/lib/mympd/config ]; then
    mympd -c -w /var/lib/mympd -a /var/cache/mympd >/dev/null 2>&1 || true
fi

exec mympd -w /var/lib/mympd -a /var/cache/mympd
