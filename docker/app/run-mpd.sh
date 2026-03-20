#!/bin/sh
set -eu

stream_out="${STREAM_OUT:-true}"
use_snapcast="${USE_SNAPCAST:-true}"
source_conf="/config/mpd.conf"
target_conf="/etc/mpd.conf"

# Ensure MPD sees the bind-mounted music and playlist paths it expects.
mkdir -p /media/music /config/playlists /pipe /var/lib/mpd

if [ -f "${source_conf}" ]; then
    cp "${source_conf}" "${target_conf}"
fi

# Strip optional audio outputs from the host config when the related feature is
# disabled through environment flags, so one config file can drive multiple
# deployment modes.
awk -v keep_stream="${stream_out}" -v keep_snap="${use_snapcast}" '
function flush_block(should_skip) {
    if (block == "") {
        return
    }

    should_skip = 0

    if (block ~ /name[[:space:]]+"My Radio"/ && keep_stream != "true") {
        should_skip = 1
    }

    if (block ~ /name[[:space:]]+"my_pipe"/ && keep_snap != "true") {
        should_skip = 1
    }

    if (!should_skip) {
        printf "%s", block
    }

    block = ""
}

/^audio_output[[:space:]]*{/ {
    in_block = 1
    block = $0 ORS
    next
}

in_block {
    block = block $0 ORS
    if ($0 ~ /^}/) {
        in_block = 0
        flush_block()
    }
    next
}

{
    print
}

END {
    flush_block()
}
' "${target_conf}" > "${target_conf}.rendered"

mv "${target_conf}.rendered" "${target_conf}"

# Foreground mode lets Supervisor own restart behavior.
exec mpd --stderr --no-daemon "${target_conf}"
