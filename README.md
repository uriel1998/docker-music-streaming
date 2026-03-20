# docker-music-streaming

Containerized music streaming stack built around MPD, myMPD, Snapcast, Snapweb, MiniDLNA, mpdscribble, Avahi, and Caddy.

## Overview

This project packages a small home-audio stack behind Docker Compose.

- `myMPD` provides the main web UI.
- `MPD` provides playback control and the optional HTTP stream.
- `Snapcast` and `Snapweb` provide synchronized multi-room playback.
- `MiniDLNA` exposes the library to DLNA/UPnP clients.
- `Avahi` advertises local services over mDNS.
- `mpdscribble` can scrobble playback to Last.fm or compatible services.
- `Caddy` fronts the web UI and can automatically manage HTTPS certificates.

The current stack replaces the older Apache/RompR setup. The legacy material remains in `1_reference/` as local migration reference and is intentionally excluded from the tracked deliverable.

## Repository Layout

- [`compose.yaml`](/home/steven/Documents/programming/docker-music-streaming/compose.yaml): main deployment definition
- [`docker/app/Dockerfile`](/home/steven/Documents/programming/docker-music-streaming/docker/app/Dockerfile): application image
- [`docker/app/`](/home/steven/Documents/programming/docker-music-streaming/docker/app): service entrypoint and per-service startup scripts
- [`docker/caddy/start-caddy.sh`](/home/steven/Documents/programming/docker-music-streaming/docker/caddy/start-caddy.sh): generates the runtime Caddy configuration from environment variables
- [`config/`](/home/steven/Documents/programming/docker-music-streaming/config): host-managed service configuration files
- [`music/`](/home/steven/Documents/programming/docker-music-streaming/music): default bind mount target for media
- [`CHANGELOG.md`](/home/steven/Documents/programming/docker-music-streaming/CHANGELOG.md): implementation log requested in the project instructions

## Requirements

- Docker Engine
- Docker Compose
- A host path containing your music library
- A public DNS record if you want automatic HTTPS
- A FreeDNS update URL if you want in-container dynamic DNS updates

## Configuration

Create a local `.env` file based on [`.env.example`](/home/steven/Documents/programming/docker-music-streaming/.env.example).

Important variables:

- `DOMAIN`: primary hostname served by Caddy
- `SECDOMAIN`: secondary hostname used only for the FreeDNS redirect-to-custom-port case
- `UPDATE_URL`: FreeDNS update endpoint; leave blank to disable the updater
- `EXTERIOR_PORT`: published HTTP port for Caddy
- `EXTERIOR_PORT_HTTPS`: published HTTPS port for Caddy
- `BEHIND_PROXY`: set to `true` when another reverse proxy or TLS terminator sits in front of Caddy
- `GET_HTTPS_CERTIFICATE`: set to `true` when Caddy should request certificates itself
- `MUSIC_DIRECTORY`: host path mounted into `/media/music`
- `USE_SNAPCAST`: set to `false` to skip starting Snapcast
- `STREAM_OUT`: set to `false` to remove the MPD HTTP stream output

`SECDOMAIN` should normally be blank. It only exists for the FreeDNS redirect workflow where the primary hostname redirects to a second hostname that resolves directly to your IP and custom port.

## Host Configuration

The service configuration files live in [`config/`](/home/steven/Documents/programming/docker-music-streaming/config) and are copied into the container at startup.

- [`config/mpd.conf`](/home/steven/Documents/programming/docker-music-streaming/config/mpd.conf): MPD configuration
- [`config/minidlna.conf`](/home/steven/Documents/programming/docker-music-streaming/config/minidlna.conf): MiniDLNA configuration
- [`config/mpdscribble.conf`](/home/steven/Documents/programming/docker-music-streaming/config/mpdscribble.conf): scrobbling configuration
- [`config/snapserver.conf`](/home/steven/Documents/programming/docker-music-streaming/config/snapserver.conf): Snapcast server configuration
- [`config/snapserver`](/home/steven/Documents/programming/docker-music-streaming/config/snapserver): extra Snapserver options

Runtime state is stored in Docker volumes so rebuilding the image does not wipe service data.

## Running

1. Edit `.env`.
2. Review the files in [`config/`](/home/steven/Documents/programming/docker-music-streaming/config).
3. Point `MUSIC_DIRECTORY` at your music library.
4. Start the stack:

```bash
docker compose up -d --build
```

5. Watch logs if needed:

```bash
docker compose logs -f
```

6. Stop the stack:

```bash
docker compose down
```

## Access

- `http://DOMAIN[:EXTERIOR_PORT]/`: main web UI through Caddy
- `https://DOMAIN[:EXTERIOR_PORT_HTTPS]/`: main web UI through Caddy when automatic HTTPS is enabled
- `http://DOMAIN[:EXTERIOR_PORT]/mpd.mp3`: MPD HTTP stream when `STREAM_OUT=true`
- `https://DOMAIN[:EXTERIOR_PORT_HTTPS]/mpd.mp3`: MPD HTTP stream over HTTPS when automatic HTTPS is enabled
- `http://host:1780/`: direct Snapweb access
- `host:6600`: direct MPD client access
- `host:8200`: MiniDLNA
- `host:1704` and `host:1705`: Snapcast

The MPD stream is intentionally served on the same public HTTP or HTTPS port as the web UI. There is no separate public stream port to open or forward. Caddy proxies `/mpd.mp3` to MPD's internal port `8000` inside the Compose network.

## Service Model

The deployment uses two containers.

- `app`: Debian-based image running MPD, myMPD, Snapserver, MiniDLNA, Avahi, mpdscribble, and the optional FreeDNS cron updater under Supervisor
- `caddy`: public-facing reverse proxy for the web UI and optional MPD stream

The Caddy container reads the same `.env` values and generates its runtime config on startup so certificate behavior and hostnames stay aligned with Compose settings.

## HTTPS Behavior

Caddy requests and manages certificates only when both conditions are met:

- `GET_HTTPS_CERTIFICATE=true`
- `BEHIND_PROXY=false`

If the stack is behind another reverse proxy, set `BEHIND_PROXY=true` so Caddy serves plain HTTP internally and does not attempt ACME validation.

## Ports To Open And Forward

Which ports must be open depends on which parts of the stack you want reachable from outside your LAN.

Always required for the web UI and `/mpd.mp3` stream:

- `EXTERIOR_PORT` TCP: HTTP entrypoint exposed by Caddy
- `EXTERIOR_PORT_HTTPS` TCP: HTTPS entrypoint exposed by Caddy when automatic HTTPS is enabled

Usually not required to expose publicly unless you explicitly want remote access to them:

- `6600/tcp`: direct MPD client access
- `8200/tcp`: MiniDLNA HTTP service
- `1704/tcp`: Snapcast audio stream
- `1705/tcp`: Snapcast control protocol
- `1780/tcp`: direct Snapweb access without Caddy

LAN-only discovery ports:

- `1900/udp`: SSDP for DLNA discovery
- `5353/udp`: mDNS/Avahi service discovery

Recommended forwarding model:

- Forward `EXTERIOR_PORT` and, if used, `EXTERIOR_PORT_HTTPS` from your router to the Docker host for browser access and `/mpd.mp3`.
- Do not forward `1900/udp` or `5353/udp` through the internet-facing router.
- Only forward `6600`, `8200`, `1704`, `1705`, or `1780` if you have a specific remote-use case and understand the security implications.

## Dynamic DNS Updates

When `UPDATE_URL` is set, the application container installs a cron entry matching the schedule requested in `INSTRUCTIONS.txt`. Each run appends output to a log file under `/tmp`.

When `UPDATE_URL` is blank, the updater process idles and no cron job is created.

## Notes

- `catt` is installed in the application image for manual casting workflows; it is not run as a daemon.
- Avahi and DLNA discovery are more reliable on Linux Docker hosts than on macOS or Windows Docker backends because multicast networking is more direct.
- The bundled Snapweb assets come from [`build/snapweb/`](/home/steven/Documents/programming/docker-music-streaming/build/snapweb) and are copied into the image during build.

## Verification

The repository currently validates cleanly with:

```bash
sh -n docker/caddy/start-caddy.sh docker/app/*.sh
docker compose config
```

Image build and runtime behavior should still be tested on the target host with:

```bash
docker compose up -d --build
docker compose ps
docker compose logs -f
```
