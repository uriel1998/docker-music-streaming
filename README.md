# docker-music-streaming

This is a Dockerized home-audio stack for people who want a browser-based control surface, a plain old MPD server, optional whole-house audio, and a setup that does not require hand-assembling a bunch of services every time they move to a new machine.

The short version is this:

- `myMPD` gives you the main web interface.
- `MPD` gives you the music server and the HTTP stream.
- `Snapcast` and `Snapweb` handle synchronized playback around the house.
- `MiniDLNA` exposes the library to DLNA clients.
- `Avahi` handles local service discovery.
- `mpdscribble` can scrobble if you want it to.
- `Caddy` is the browser-facing router.

This repository replaces the older Apache/RompR setup. Older materials from that version were removed from the public repository, and the active tracked project is the newer myMPD-and-Caddy stack.

## What This Is Trying To Do

The goal here is not to make the smallest possible image. The goal is to get a practical music server up and running with:

- a host-managed music directory
- host-managed config files
- a browser-facing entrypoint that works behind a reverse proxy by default
- optional direct HTTPS mode when there is no other reverse proxy
- path-based routing so one Caddy entrypoint serves the UI, the MPD stream, and Snapweb
- explicit env vars for every extra exposed service port

## Default Behavior

The desired default mode is:

- `BEHIND_PROXY=true`
- `GET_HTTPS_CERTIFICATE=false`
- Caddy serves plain HTTP on `EXTERIOR_PORT`
- some other reverse proxy can sit in front and terminate TLS if you want public HTTPS

In that default mode, Caddy is not trying to obtain certificates. It is just taking traffic that reaches the container on the configured HTTP port and routing it to the correct internal service.

The optional direct-public mode is:

- `BEHIND_PROXY=false`
- `GET_HTTPS_CERTIFICATE=true`
- Caddy serves ports `80` and `443`
- Caddy performs TLS termination itself

## Routing

All browser-facing routing goes through Caddy:

- `/` goes to myMPD
- `/mpd.mp3` goes to the MPD HTTP stream
- `/snapweb` goes to Snapweb
- `/jsonrpc` goes to the Snapweb/Snapcast websocket RPC endpoint
- `/stream` goes to the Snapweb/Snapcast streaming websocket endpoint

That means the browser only needs one entrypoint, and Caddy fans requests out to the correct internal service.

## Repository Layout

- [`compose.yaml`](/home/steven/Documents/programming/docker-music-streaming/compose.yaml): main deployment definition
- [`docker/app/Dockerfile`](/home/steven/Documents/programming/docker-music-streaming/docker/app/Dockerfile): application image
- [`docker/app/`](/home/steven/Documents/programming/docker-music-streaming/docker/app): entrypoint and per-service startup scripts
- [`docker/caddy/start-caddy.sh`](/home/steven/Documents/programming/docker-music-streaming/docker/caddy/start-caddy.sh): generates the runtime Caddy configuration from `.env`
- [`config/`](/home/steven/Documents/programming/docker-music-streaming/config): host-side configuration files copied into the container at startup
- [`music/`](/home/steven/Documents/programming/docker-music-streaming/music): default bind mount target for music

## What You Need

- Docker Engine
- Docker Compose
- a host path containing your music library
- a DNS record if you want public HTTPS
- a FreeDNS update URL if you want the container to refresh your public IP automatically

## Configuration

Create a local `.env` file based on [`.env.example`](/home/steven/Documents/programming/docker-music-streaming/.env.example).

Important core variables:

- `MUSICSTACK_DOMAIN`: the primary hostname associated with the deployment
- `MUSICSTACK_SECDOMAIN`: only for the FreeDNS redirect-to-custom-port case
- `UPDATE_URL`: the FreeDNS update endpoint; blank disables the updater
- `EXTERIOR_PORT`: the external HTTP port published by Caddy
- `EXTERIOR_PORT_HTTPS`: the external HTTPS port used only for direct HTTPS mode
- `BEHIND_PROXY`: defaults to `true`
- `GET_HTTPS_CERTIFICATE`: defaults to `false`
- `MUSICSTACK_MUSIC_DIR`: the host path mounted into `/media/music`
- `MUSICSTACK_MPD_PASSWORD`: the local MPD control password used by MPD and myMPD
- `MPD_CONNECT_HOST`: the MPD host or socket path myMPD should use; defaults to `/run/music-stack/mpd/socket`
- `USE_SNAPCAST`: enables or disables Snapcast and Snapweb routing
- `USE_MINIDLNA`: enables or disables MiniDLNA
- `USE_AVAHI`: enables or disables Avahi
- `USE_HOST_AVAHI`: defaults to `true` on Linux-style hosts and prefers talking to the host Avahi daemon over mounted sockets
- `AVAHI_PUBLISHED_PORT`: host UDP port forwarded to Avahi's internal `5353/udp`
- `STREAM_OUT`: enables or disables `/mpd.mp3`

Additional service ports are explicitly enumerated in the env files:

- `MPD_CONTROL_PORT`
- `MINIDLNA_PORT`
- `MINIDLNA_DISCOVERY_PORT`
- `SNAPCAST_STREAM_PORT`
- `SNAPCAST_CONTROL_PORT`
- `SNAPWEB_PORT`

`MUSICSTACK_SECDOMAIN` should usually be blank. It only matters for the FreeDNS redirect setup where one hostname redirects to another hostname that points at your real IP and the port you are actually using.

## Host-Managed Config Files

The files in [`config/`](/home/steven/Documents/programming/docker-music-streaming/config) are meant to be edited from the host, not from inside the container.

- [`config/mpd.conf`](/home/steven/Documents/programming/docker-music-streaming/config/mpd.conf): MPD configuration
- [`config/minidlna.conf`](/home/steven/Documents/programming/docker-music-streaming/config/minidlna.conf): MiniDLNA configuration
- [`config/mpdscribble.conf`](/home/steven/Documents/programming/docker-music-streaming/config/mpdscribble.conf): scrobbling configuration
- [`config/snapserver.conf`](/home/steven/Documents/programming/docker-music-streaming/config/snapserver.conf): Snapcast server configuration
- [`config/snapserver`](/home/steven/Documents/programming/docker-music-streaming/config/snapserver): additional Snapserver options

Runtime state lives in Docker volumes so rebuilding the image does not wipe learned or cached data.

## Running It

1. Edit `.env`.
2. Review the files in [`config/`](/home/steven/Documents/programming/docker-music-streaming/config).
3. Point `MUSICSTACK_MUSIC_DIR` at your music library.
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

Browser-facing paths through Caddy:

- `http://host:EXTERIOR_PORT/`: myMPD in the default reverse-proxy mode
- `http://host:EXTERIOR_PORT/mpd.mp3`: MPD stream in the default reverse-proxy mode
- `http://host:EXTERIOR_PORT/snapweb`: Snapweb in the default reverse-proxy mode
- `https://MUSICSTACK_DOMAIN[:EXTERIOR_PORT_HTTPS]/`: myMPD in direct HTTPS mode
- `https://MUSICSTACK_DOMAIN[:EXTERIOR_PORT_HTTPS]/mpd.mp3`: MPD stream in direct HTTPS mode
- `https://MUSICSTACK_DOMAIN[:EXTERIOR_PORT_HTTPS]/snapweb`: Snapweb in direct HTTPS mode

Direct non-browser service ports:

- `host:MPD_CONTROL_PORT`: direct MPD client access
- `host:MINIDLNA_PORT`: MiniDLNA
- `host:SNAPCAST_STREAM_PORT` and `host:SNAPCAST_CONTROL_PORT`: Snapcast
- `host:SNAPWEB_PORT`: direct Snapweb access, if you want it outside the Caddy path routing

## The Actual Container Model

There are two containers:

- `app`: runs MPD, myMPD, mpdscribble, and the optional Snapcast, MiniDLNA, Avahi, and FreeDNS updater processes under Supervisor
- `caddy`: handles the browser-facing entrypoint and routes `/`, `/mpd.mp3`, and the optional Snapweb paths

That keeps the browser side simple while leaving the native service ports available for clients that need them.

## Ports To Open And Forward

This is the part people usually wind up reconstructing from Compose files, so here it is plainly.

Browser-facing ports:

- forward `EXTERIOR_PORT/tcp` for the default reverse-proxy mode
- forward `80/tcp` and `443/tcp` only if you are using the optional direct HTTPS mode

Native service ports that exist but usually do not need internet-facing forwarding:

- `MPD_CONTROL_PORT/tcp`
- `MINIDLNA_PORT/tcp`
- `MINIDLNA_DISCOVERY_PORT/udp`
- `SNAPCAST_STREAM_PORT/tcp`
- `SNAPCAST_CONTROL_PORT/tcp`
- `SNAPWEB_PORT/tcp`
- `AVAHI_PUBLISHED_PORT/udp`

Usual sane default:

- forward only `EXTERIOR_PORT` when another reverse proxy is in front
- forward only `80` and `443` when Caddy is doing public TLS itself
- leave everything else unforwarded unless you have a specific reason not to

Within the current single-container app design, `USE_SNAPCAST`, `USE_MINIDLNA`, and `USE_AVAHI` cleanly disable the daemons themselves. Compose still keeps the matching port mappings in place because those mappings belong to the one shared `app` service rather than to separate per-feature containers.

## Dynamic DNS Updates

If `UPDATE_URL` is set, the application container creates the requested FreeDNS cron job and runs it on the configured schedule.

If `UPDATE_URL` is blank, that updater process simply idles and does nothing.

## Notes

- The active application image is based on Debian Trixie.
- `myMPD` is installed from the upstream JCorporation APT repository during image build so the container follows the official Debian packaging path.
- Avahi can be disabled with `USE_AVAHI=false`, and its published host UDP port can be changed with `AVAHI_PUBLISHED_PORT`.
- MiniDLNA can be disabled with `USE_MINIDLNA=false`.
- On Linux hosts, `USE_HOST_AVAHI=true` lets the containerized services talk to the host Avahi daemon over mounted D-Bus and Avahi sockets instead of always running a second Avahi daemon internally.
- The default deployment assumes another reverse proxy may sit in front of Caddy, so automatic certificate generation is off unless you explicitly enable direct HTTPS mode.
- Avahi and DLNA discovery tend to behave better on Linux Docker hosts than on macOS or Windows Docker backends.
- The bundled Snapweb assets are copied from [`build/snapweb/`](/home/steven/Documents/programming/docker-music-streaming/build/snapweb) during the image build.

## Example Setup 1: Behind Nginx Reverse Proxy With TLS Termination

This is the desired default case.

1. Set your `.env` values like this:

```dotenv
MUSICSTACK_DOMAIN=music.internal.example
MUSICSTACK_SECDOMAIN=
UPDATE_URL=
EXTERIOR_PORT=38180
EXTERIOR_PORT_HTTPS=443
BEHIND_PROXY=true
GET_HTTPS_CERTIFICATE=false
MUSICSTACK_MUSIC_DIR=/srv/music
MUSICSTACK_MPD_PASSWORD=mycomplicatedpassword
MPD_CONNECT_HOST=/run/music-stack/mpd/socket
USE_SNAPCAST=true
USE_MINIDLNA=true
USE_AVAHI=false
USE_HOST_AVAHI=true
AVAHI_PUBLISHED_PORT=39535
STREAM_OUT=true
MPD_CONTROL_PORT=6600
MINIDLNA_PORT=8200
MINIDLNA_DISCOVERY_PORT=1900
SNAPCAST_STREAM_PORT=1704
SNAPCAST_CONTROL_PORT=1705
SNAPWEB_PORT=1780
```

2. Start the stack:

```bash
docker compose up -d --build
```

3. Make sure nginx can reach the Docker host on `http://docker-host:38180`.
4. Terminate TLS at nginx using your existing Let’s Encrypt setup.
5. Proxy `/`, `/mpd.mp3`, `/snapweb`, `/jsonrpc`, and `/stream` to `http://docker-host:38180`.
6. Open `https://music.example.com/` for myMPD.
7. Open `https://music.example.com/mpd.mp3` for the stream.
8. Open `https://music.example.com/snapweb` for Snapweb.

Example nginx server block:

```nginx
server {
    listen 80;
    server_name music.example.com;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name music.example.com;

    ssl_certificate /etc/letsencrypt/live/music.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/music.example.com/privkey.pem;

    location / {
        proxy_pass http://docker-host:38180;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}
```

## Example Setup 2: Direct HTTPS, No Other Reverse Proxy

This is the optional case where Caddy handles TLS itself.

1. Point your DNS record for `music.example.com` at your public IP.
2. Set your `.env` values like this:

```dotenv
MUSICSTACK_DOMAIN=music.example.com
MUSICSTACK_SECDOMAIN=
UPDATE_URL=
EXTERIOR_PORT=80
EXTERIOR_PORT_HTTPS=443
BEHIND_PROXY=false
GET_HTTPS_CERTIFICATE=true
MUSICSTACK_MUSIC_DIR=/srv/music
MUSICSTACK_MPD_PASSWORD=mycomplicatedpassword
MPD_CONNECT_HOST=/run/music-stack/mpd/socket
USE_SNAPCAST=true
USE_MINIDLNA=true
USE_AVAHI=true
USE_HOST_AVAHI=true
AVAHI_PUBLISHED_PORT=5353
STREAM_OUT=true
MPD_CONTROL_PORT=6600
MINIDLNA_PORT=8200
MINIDLNA_DISCOVERY_PORT=1900
SNAPCAST_STREAM_PORT=1704
SNAPCAST_CONTROL_PORT=1705
SNAPWEB_PORT=1780
```

3. Forward router port `80/tcp` to the Docker host.
4. Forward router port `443/tcp` to the Docker host.
5. Start the stack:

```bash
docker compose up -d --build
```

6. Open `https://music.example.com/` for myMPD.
7. Open `https://music.example.com/mpd.mp3` for the stream.
8. Open `https://music.example.com/snapweb` for Snapweb.

In this mode, Caddy obtains and renews certificates itself because the container is directly reachable on ports `80` and `443`.
