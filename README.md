# docker-music-streaming

Dockerized whole-house audio stack built around `mpd`, `myMPD`, `snapcast`, `snapweb`, `minidlna`, `mpdscribble`, `avahi`, and `catt`, with Caddy handling the public web entrypoint.

## What Changed

This repo now targets:

- `myMPD` instead of RompR
- `Caddy` instead of an Apache/PHP web tier
- `.env`-driven Docker Compose deployment
- host-mounted configuration under [`config/`](/home/steven/Documents/programming/docker-music-streaming/config)
- optional automatic HTTPS when the instance is public and not behind another reverse proxy
- optional FreeDNS dynamic updates from inside the application container

The older 2022 stack is intentionally left in `1_reference/` as local migration material and is not part of the new tracked deployment.

## Layout

- [`compose.yaml`](/home/steven/Documents/programming/docker-music-streaming/compose.yaml): primary deployment definition
- [`docker/app/Dockerfile`](/home/steven/Documents/programming/docker-music-streaming/docker/app/Dockerfile): application image containing MPD, myMPD, minidlna, snapserver, avahi, mpdscribble, and `catt`
- [`docker/caddy/start-caddy.sh`](/home/steven/Documents/programming/docker-music-streaming/docker/caddy/start-caddy.sh): generates the runtime Caddy config from `.env`
- [`config/`](/home/steven/Documents/programming/docker-music-streaming/config): user-editable service configs mounted from the host
- [`build/snapweb/`](/home/steven/Documents/programming/docker-music-streaming/build/snapweb): bundled snapweb assets copied into the image

## Environment

Copy [`.env.example`](/home/steven/Documents/programming/docker-music-streaming/.env.example) to `.env` if needed and adjust the values.

Key settings:

- `DOMAIN`: primary public hostname for the Caddy site
- `SECDOMAIN`: only set this when using a second FreeDNS A record for web redirection to a non-standard external port
- `UPDATE_URL`: FreeDNS dynamic-update endpoint; leave blank to disable
- `EXTERIOR_PORT`: external HTTP port published by Caddy
- `EXTERIOR_PORT_HTTPS`: external HTTPS port published by Caddy
- `BEHIND_PROXY=true`: disables Caddy automatic certificate issuance
- `GET_HTTPS_CERTIFICATE=true`: allows Caddy to obtain certificates when the instance is directly reachable
- `MUSIC_DIRECTORY`: host path mounted into `/media/music`
- `USE_SNAPCAST`: controls whether the snapserver process is started
- `STREAM_OUT`: controls whether the MPD HTTP stream is exposed through Caddy at `/mpd.mp3`

`SECDOMAIN` should normally stay blank. Use it only for the FreeDNS web-redirect case where `DOMAIN` is redirected to a second hostname that points at your actual IP and custom port.

## Running

1. Adjust `.env`.
2. Review the configs in [`config/`](/home/steven/Documents/programming/docker-music-streaming/config).
3. Put your library at the path referenced by `MUSIC_DIRECTORY`.
4. Start the stack with `docker compose up -d --build`.

Primary access paths:

- `http://DOMAIN[:EXTERIOR_PORT]/` or `https://DOMAIN[:EXTERIOR_PORT_HTTPS]/`: myMPD through Caddy
- `http://DOMAIN[:EXTERIOR_PORT]/mpd.mp3`: MPD HTTP stream when `STREAM_OUT=true`
- `http://host:1780/`: direct snapweb access
- `host:6600`: direct MPD client access
- `host:8200`: MiniDLNA
- `host:1704` and `host:1705`: Snapcast

## Notes

- Automatic HTTPS is only enabled when `GET_HTTPS_CERTIFICATE=true` and `BEHIND_PROXY=false`.
- The FreeDNS updater is implemented with an in-container cron job using the schedule requested in `INSTRUCTIONS.txt`.
- `catt` is installed in the application image for ad-hoc casting workflows; it is not a long-running service.
- Avahi and DLNA discovery inside Docker can vary by host OS and network setup. The stack keeps those services available, but multicast discovery is still more reliable on Linux hosts than on macOS or Windows Docker backends.
