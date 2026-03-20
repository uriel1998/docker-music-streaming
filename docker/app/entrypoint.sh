#!/bin/sh
set -eu

APP_STATE_ROOT="${APP_STATE_ROOT:-/var/lib/music-stack}"
APP_RUNTIME_ROOT="${APP_RUNTIME_ROOT:-/run/music-stack}"

link_dir() {
    target="$1"
    source_dir="$2"

    mkdir -p "${source_dir}"

    if [ -L "${target}" ]; then
        return
    fi

    if [ -e "${target}" ]; then
        rm -rf "${target}"
    fi

    ln -s "${source_dir}" "${target}"
}

mkdir -p \
    "${APP_STATE_ROOT}/mpd" \
    "${APP_STATE_ROOT}/minidlna" \
    "${APP_STATE_ROOT}/mpdscribble" \
    "${APP_STATE_ROOT}/mympd" \
    "${APP_STATE_ROOT}/mympd-cache" \
    "${APP_STATE_ROOT}/snapserver" \
    "${APP_RUNTIME_ROOT}" \
    /config/playlists \
    /media/music \
    /pipe \
    /run/dbus

link_dir /var/lib/mpd "${APP_STATE_ROOT}/mpd"
link_dir /var/cache/minidlna "${APP_STATE_ROOT}/minidlna"
link_dir /var/cache/mpdscribble "${APP_STATE_ROOT}/mpdscribble"
link_dir /var/lib/mympd "${APP_STATE_ROOT}/mympd"
link_dir /var/cache/mympd "${APP_STATE_ROOT}/mympd-cache"
link_dir /var/lib/snapserver "${APP_STATE_ROOT}/snapserver"

if [ ! -S /run/dbus/system_bus_socket ]; then
    dbus-daemon --system --fork --nopidfile
fi

exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
