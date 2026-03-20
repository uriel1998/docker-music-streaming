FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_BREAK_SYSTEM_PACKAGES=1

# System packages provide the long-running services; `catt` is installed from
# PyPI because it is used as a utility rather than a daemon.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        avahi-daemon \
        ca-certificates \
        cron \
        dbus \
        ffmpeg \
        libnss-mdns \
        minidlna \
        mpc \
        mpd \
        mpdscribble \
        mympd \
        python3 \
        python3-pip \
        snapserver \
        supervisor \
        tini \
        wget && \
    pip3 install --no-cache-dir catt && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Snapweb is shipped as static assets and served by Snapserver's HTTP endpoint.
COPY build/snapweb/ /var/www/snapweb/
COPY docker/app/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY docker/app/run-avahi.sh /usr/local/bin/run-avahi.sh
COPY docker/app/run-ddns-cron.sh /usr/local/bin/run-ddns-cron.sh
COPY docker/app/run-minidlna.sh /usr/local/bin/run-minidlna.sh
COPY docker/app/run-mpd.sh /usr/local/bin/run-mpd.sh
COPY docker/app/run-mpdscribble.sh /usr/local/bin/run-mpdscribble.sh
COPY docker/app/run-mympd.sh /usr/local/bin/run-mympd.sh
COPY docker/app/run-snapserver.sh /usr/local/bin/run-snapserver.sh
COPY docker/app/supervisord.conf /etc/supervisor/conf.d/music-stack.conf

# Create the bind mount targets and shared runtime directories up front.
RUN chmod 755 /usr/local/bin/entrypoint.sh /usr/local/bin/run-*.sh && \
    mkdir -p /config /config/playlists /media/music /pipe /run/music-stack /var/lib/music-stack

EXPOSE 8080 8000 6600 8200 1704 1705 1780 1900/udp 5353/udp

# `tini` handles signal forwarding and child reaping before Supervisor starts.
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
