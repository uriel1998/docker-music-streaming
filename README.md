# docker-music-streaming

This is a Dockerized home-audio stack for people who want a browser-based control surface, a plain old MPD server, optional whole-house audio, and a setup that does not require hand-assembling five different services every time they rebuild a machine.

The short version is this:

- `myMPD` gives you the web interface.
- `MPD` gives you the music server and the actual stream.
- `Snapcast` and `Snapweb` handle synchronized playback around the house.
- `MiniDLNA` makes the library visible to DLNA clients.
- `Avahi` handles local service discovery.
- `mpdscribble` can scrobble if you want it to.
- `Caddy` sits in front and handles the public web side, including HTTPS when that makes sense.

This repository replaces the older Apache/RompR setup. The earlier materials are still in `1_reference/` as local reference artifacts, but the current tracked project is the newer myMPD-and-Caddy stack.

## What This Is Trying To Do

The goal here is not to produce the smallest possible container or the most academically pure separation of services. The goal is to get a practical music server up and running with:

- a host-managed music directory
- host-managed config files
- a web UI that works over HTTP or HTTPS
- an MPD stream available at `/mpd.mp3`
- optional Snapcast support
- optional FreeDNS updates
- enough documentation that you do not have to rediscover how it works six months from now

## Repository Layout

- [`compose.yaml`](/home/steven/Documents/programming/docker-music-streaming/compose.yaml): the main deployment file
- [`docker/app/Dockerfile`](/home/steven/Documents/programming/docker-music-streaming/docker/app/Dockerfile): the application image
- [`docker/app/`](/home/steven/Documents/programming/docker-music-streaming/docker/app): entrypoint and per-service startup scripts
- [`docker/caddy/start-caddy.sh`](/home/steven/Documents/programming/docker-music-streaming/docker/caddy/start-caddy.sh): generates the runtime Caddy configuration from `.env`
- [`config/`](/home/steven/Documents/programming/docker-music-streaming/config): host-side configuration files copied into the container at startup
- [`music/`](/home/steven/Documents/programming/docker-music-streaming/music): default bind mount target for music
- [`CHANGELOG.md`](/home/steven/Documents/programming/docker-music-streaming/CHANGELOG.md): implementation log

## What You Need

- Docker Engine
- Docker Compose
- a host path containing your music library
- a DNS record if you want public HTTPS
- a FreeDNS update URL if you want the container to refresh your public IP automatically

## Configuration

Create a local `.env` file based on [`.env.example`](/home/steven/Documents/programming/docker-music-streaming/.env.example).

The important variables are:

- `DOMAIN`: the primary hostname served by Caddy
- `SECDOMAIN`: only for the FreeDNS redirect-to-custom-port case
- `UPDATE_URL`: the FreeDNS update endpoint; blank disables the updater
- `EXTERIOR_PORT`: the public HTTP port published by Caddy
- `EXTERIOR_PORT_HTTPS`: the public HTTPS port published by Caddy
- `BEHIND_PROXY`: set this to `true` if some other reverse proxy or TLS terminator sits in front of Caddy
- `GET_HTTPS_CERTIFICATE`: set this to `true` if Caddy itself should obtain certificates
- `MUSIC_DIRECTORY`: the host path mounted into `/media/music`
- `USE_SNAPCAST`: set to `false` if you do not want Snapcast running
- `STREAM_OUT`: set to `false` if you do not want the MPD HTTP stream exposed

`SECDOMAIN` should usually be blank. It only matters for the FreeDNS redirect setup where one hostname redirects to another hostname that points at your real IP and the port you are actually using.

## Host-Managed Config Files

The files in [`config/`](/home/steven/Documents/programming/docker-music-streaming/config) are meant to be edited from the host, not from inside the container.

- [`config/mpd.conf`](/home/steven/Documents/programming/docker-music-streaming/config/mpd.conf): MPD configuration
- [`config/minidlna.conf`](/home/steven/Documents/programming/docker-music-streaming/config/minidlna.conf): MiniDLNA configuration
- [`config/mpdscribble.conf`](/home/steven/Documents/programming/docker-music-streaming/config/mpdscribble.conf): scrobbling configuration
- [`config/snapserver.conf`](/home/steven/Documents/programming/docker-music-streaming/config/snapserver.conf): Snapcast server configuration
- [`config/snapserver`](/home/steven/Documents/programming/docker-music-streaming/config/snapserver): additional Snapserver options

Runtime state lives in Docker volumes so that rebuilding the image does not blow away everything the services have learned or cached.

## Running It

1. Edit `.env`.
2. Review the files in [`config/`](/home/steven/Documents/programming/docker-music-streaming/config).
3. Point `MUSIC_DIRECTORY` at your music library.
4. Build and start the stack.

```bash
docker compose up -d --build
```

If you want to watch it come up:

```bash
docker compose logs -f
```

If you want to stop it:

```bash
docker compose down
```

## Where Things Show Up

- `http://DOMAIN[:EXTERIOR_PORT]/`: the myMPD web UI through Caddy
- `https://DOMAIN[:EXTERIOR_PORT_HTTPS]/`: the same thing over HTTPS when Caddy is managing certificates
- `http://DOMAIN[:EXTERIOR_PORT]/mpd.mp3`: the MPD stream when `STREAM_OUT=true`
- `https://DOMAIN[:EXTERIOR_PORT_HTTPS]/mpd.mp3`: the same stream through HTTPS when enabled
- `http://host:1780/`: direct Snapweb access
- `host:6600`: direct MPD client access
- `host:8200`: MiniDLNA
- `host:1704` and `host:1705`: Snapcast

The important bit here is that the MPD stream is not meant to live on some separate public port. It is served on the same public HTTP or HTTPS entrypoint as the web UI, just at `/mpd.mp3`. Internally, Caddy proxies that request to MPD's own stream port.

## The Actual Container Model

There are two containers:

- `app`: runs MPD, myMPD, Snapserver, MiniDLNA, Avahi, mpdscribble, and the optional FreeDNS cron updater under Supervisor
- `caddy`: handles the public web entrypoint and proxies both the UI and `/mpd.mp3`

That means the public web surface stays simple, while the backend services can keep their normal internal ports.

## HTTPS

Caddy only tries to obtain and manage certificates when both of these are true:

- `GET_HTTPS_CERTIFICATE=true`
- `BEHIND_PROXY=false`

If this stack is sitting behind another reverse proxy, set `BEHIND_PROXY=true`. In that mode Caddy behaves as an internal HTTP service and does not try to do ACME validation.

## Ports To Open And Forward

This is the part people usually wind up having to reconstruct from Compose files and guesswork, so here it is plainly.

If you want the web UI and the `/mpd.mp3` stream reachable from outside your LAN, the required forwarded ports are:

- `EXTERIOR_PORT/tcp`
- `EXTERIOR_PORT_HTTPS/tcp`, if you are using HTTPS

That is enough for the browser-facing side. You do not need to forward a separate stream port for MPD audio.

Ports that exist, but usually do not need internet-facing forwarding:

- `6600/tcp`: direct MPD client access
- `8200/tcp`: MiniDLNA
- `1704/tcp`: Snapcast audio stream
- `1705/tcp`: Snapcast control
- `1780/tcp`: direct Snapweb access

Ports that are for local network discovery and should generally stay on the LAN:

- `1900/udp`: SSDP for DLNA discovery
- `5353/udp`: mDNS/Avahi discovery

If you are forwarding ports on a home router, the sane default is:

- forward `EXTERIOR_PORT`
- forward `EXTERIOR_PORT_HTTPS` if you are using HTTPS
- leave everything else unforwarded unless you have a specific reason not to

## Dynamic DNS Updates

If `UPDATE_URL` is set, the application container creates the requested FreeDNS cron job and runs it on the schedule specified in the project instructions.

If `UPDATE_URL` is blank, that updater process simply idles and does nothing.

## Notes

- `catt` is installed in the application image for manual casting work, not as a long-running service.
- Avahi and DLNA discovery tend to behave better on Linux Docker hosts than on macOS or Windows Docker backends.
- The bundled Snapweb assets are copied from [`build/snapweb/`](/home/steven/Documents/programming/docker-music-streaming/build/snapweb) during the image build.

## Verification

The repository currently validates cleanly with:

```bash
sh -n docker/caddy/start-caddy.sh docker/app/*.sh
docker compose config
```

The obvious next real-world test on the target host is:

```bash
docker compose up -d --build
docker compose ps
docker compose logs -f
```
