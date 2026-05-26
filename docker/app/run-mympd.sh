#!/bin/sh
set -eu

# myMPD reads basic networking and MPD connection settings from environment.
app_runtime_root="${APP_RUNTIME_ROOT:-/run/music-stack}"
mpd_password="${MUSICSTACK_MPD_PASSWORD:-mycomplicatedpassword}"
mpd_connect_host="${MPD_CONNECT_HOST:-${app_runtime_root}/mpd/socket}"

export MPD_HOST="${MPD_HOST:-${mpd_password}@${mpd_connect_host}}"
export MPD_PORT="${MPD_PORT:-6600}"
export MYMPD_HTTP_PORT="${MYMPD_HTTP_PORT:-8080}"
export MYMPD_SSL="${MYMPD_SSL:-false}"
export MYMPD_SSL_PORT="${MYMPD_SSL_PORT:-443}"
export MYMPD_LOGLEVEL="${MYMPD_LOGLEVEL:-5}"
mpd_db_file="${MPD_DB_FILE:-/var/lib/mpd/tag_cache}"

mkdir -p /var/lib/mympd /var/cache/mympd

# If the user has not explicitly pinned a different MPD endpoint, clear the
# persisted network-host state so myMPD falls back to the local socket and can
# auto-detect MPD's music directory on startup.
if [ -z "${MPD_HOST:-}" ]; then
    rm -f /var/lib/mympd/state/mpd_host /var/lib/mympd/state/mpd_port
fi

# Supervisor start priority only controls launch order. Wait until MPD is
# actually accepting commands so first boot does not race myMPD against MPD.
mpd_ready=0
for _ in $(seq 1 60); do
    if mpc status >/dev/null 2>&1; then
        mpd_ready=1
        break
    fi

    sleep 1
done

if [ "${mpd_ready}" -ne 1 ]; then
    echo "MPD did not become ready before myMPD startup" >&2
    exit 1
fi

# On a brand-new state volume, force the first library scan before myMPD starts
# serving so the UI does not persist an empty initial view of the library.
if [ ! -s "${mpd_db_file}" ]; then
    mpc update >/dev/null 2>&1 || true

    for _ in $(seq 1 300); do
        if [ -s "${mpd_db_file}" ]; then
            break
        fi

        sleep 1
    done
fi

exec mympd -w /var/lib/mympd -a /var/cache/mympd
