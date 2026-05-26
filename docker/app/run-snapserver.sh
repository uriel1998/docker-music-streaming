#!/bin/sh
set -eu

# Allow the whole Snapcast branch to be disabled without editing the base image.
if [ "${USE_SNAPCAST:-true}" != "true" ]; then
    exec sleep infinity
fi

snapweb_port="${SNAPWEB_PORT:-1780}"
snapcast_control_port="${SNAPCAST_CONTROL_PORT:-1705}"
snapcast_stream_port="${SNAPCAST_STREAM_PORT:-1704}"

mkdir -p /var/lib/snapserver /pipe

cat > /etc/snapserver.conf <<EOF
[server]
threads = -1

[http]
enabled = true
bind_to_address = 0.0.0.0
port = ${snapweb_port}
doc_root = /var/www/snapweb

[tcp]
enabled = true
bind_to_address = 0.0.0.0
port = ${snapcast_control_port}

[stream]
bind_to_address = 0.0.0.0
port = ${snapcast_stream_port}
source = pipe:///pipe/snapfifo?name=default
sampleformat = 48000:16:2
codec = pcm
chunk_ms = 20
buffer = 2000
send_to_muted = false
EOF

# Snapserver serves both the synchronization protocol and the bundled Snapweb UI.
exec snapserver --logging.sink=stderr --server.datadir=/var/lib/snapserver --config=/etc/snapserver.conf
