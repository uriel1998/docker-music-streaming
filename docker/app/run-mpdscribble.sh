#!/bin/sh
set -eu

app_runtime_root="${APP_RUNTIME_ROOT:-/run/music-stack}"
mpd_password="${MUSICSTACK_MPD_PASSWORD:-mycomplicatedpassword}"
mpd_connect_host="${MPD_CONNECT_HOST:-${app_runtime_root}/mpd/socket}"
lastfm_username="${MUSICSTACK_LASTFM_USERNAME:-}"
lastfm_password="${MUSICSTACK_LASTFM_PASSWORD:-}"
librefm_username="${MUSICSTACK_LIBREFM_USERNAME:-}"
librefm_password="${MUSICSTACK_LIBREFM_PASSWORD:-}"

export MPD_HOST="${MPD_HOST:-${mpd_password}@${mpd_connect_host}}"
export MPD_PORT="${MPD_PORT:-6600}"

# Do not run the service unless at least one scrobbling target is configured.
if [ -z "${lastfm_username}" ] && [ -z "${librefm_username}" ]; then
    exec sleep infinity
fi

if { [ -n "${lastfm_username}" ] && [ -z "${lastfm_password}" ]; } || \
   { [ -n "${librefm_username}" ] && [ -z "${librefm_password}" ]; }; then
    exec sleep infinity
fi

mkdir -p /var/cache/mpdscribble

cat > /etc/mpdscribble.conf <<EOF
verbose = 1

[last.fm]
url = https://post.audioscrobbler.com/
username = ${lastfm_username}
password = ${lastfm_password}
journal = /var/cache/mpdscribble/lastfm.journal
EOF

if [ -n "${librefm_username}" ]; then
    cat >> /etc/mpdscribble.conf <<EOF

[libre.fm]
url = http://turtle.libre.fm/
username = ${librefm_username}
password = ${librefm_password}
journal = /var/cache/mpdscribble/librefm.journal
EOF
fi

# Keep logging on stdout/stderr for `docker compose logs`.
exec mpdscribble --no-daemon --conf /etc/mpdscribble.conf --log -
