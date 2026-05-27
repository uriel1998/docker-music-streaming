#!/bin/sh
set -eu

stream_out="${STREAM_OUT:-true}"
use_snapcast="${USE_SNAPCAST:-true}"
mpd_password="${MUSICSTACK_MPD_PASSWORD:-mycomplicatedpassword}"
app_runtime_root="${APP_RUNTIME_ROOT:-/run/music-stack}"
mpd_socket_path="${MPD_SOCKET_PATH:-${app_runtime_root}/mpd/socket}"
source_conf="/config/mpd.conf"
target_conf="/etc/mpd.conf"

# Ensure MPD sees the bind-mounted music and playlist paths it expects.
mkdir -p /media/music /config/playlists /pipe /var/lib/mpd "$(dirname "${mpd_socket_path}")"

if [ -f "${source_conf}" ]; then
    cp "${source_conf}" "${target_conf}"
fi

# Keep MPD authentication env-driven so the mounted sample config does not have
# to be edited just to change the local control password.
sed -i "s|^[[:space:]]*password[[:space:]]*\".*@read,add,control,admin\"|password                        \"${mpd_password}@read,add,control,admin\"|" "${target_conf}"

# myMPD can auto-detect MPD's music directory only over a local socket, so
# publish one in addition to the existing TCP listener.
if ! grep -Fq "bind_to_address \"${mpd_socket_path}\"" "${target_conf}"; then
    printf '\nbind_to_address "%s"\n' "${mpd_socket_path}" >> "${target_conf}"
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

# MPD expects its state/database files to exist on first boot for this config.
# Create missing paths explicitly so a clean volume does not fail before the
# daemon can initialize its own state, but do not truncate existing data.
for path_key in db_file state_file sticker_file pid_file; do
    path_value="$(awk -v key="${path_key}" '
        $1 == key {
            value = $2
            gsub(/"/, "", value)
            print value
            exit
        }
    ' "${target_conf}")"

    if [ -n "${path_value}" ]; then
        mkdir -p "$(dirname "${path_value}")"
        if [ ! -e "${path_value}" ]; then
            : > "${path_value}"
        fi
    fi
done

# Foreground mode lets Supervisor own restart behavior.
exec mpd --stderr --no-daemon "${target_conf}"
