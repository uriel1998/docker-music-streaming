# docker-music-streaming

Dockerized home audio stack built around `MPD`, `myMPD`, `Caddy`, and a few optional extras.

If you want a practical music server instead of a tiny one, this is that. The point here is not to win image-size contests. The point is to get a usable setup with a web UI, native MPD access, optional Snapcast, optional DLNA, and host-managed state so you do not have to rebuild the whole thing from scratch every time you move machines.  Also with minimal setup needed (may vary depending on your host OS, though).  

Works well on Linux hosts -- I am currently using it! -- and *should* work on macOS and Windows with Docker Desktop, though I haven't explicitly tested it.  

## What’s In Here

- `myMPD` for the main browser UI
- `MPD` for playback control and the native HTTP stream
- `Caddy` as the browser-facing router
- `Snapcast` and `Snapweb` for synchronized playback
- `MiniDLNA` for DLNA clients
- `Avahi` for local service discovery
- `mpdscribble` for Last.fm or Libre.fm scrobbling

## Table Of Contents

- [How It Works](#how-it-works)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Paths And Persistence](#paths-and-persistence)
- [Ports And Access](#ports-and-access)
- [Deployment Modes](#deployment-modes)
- [Securing The Web UI](#securing-the-web-ui)
- [Platform Notes](#platform-notes)
- [Extra Admin Tasks](#extra-admin-tasks)
- [Bundled Music Attribution](#bundled-music-attribution)

## How It Works

There are two containers:

- `app`: runs MPD, myMPD, mpdscribble, and the optional Snapcast, MiniDLNA, and Avahi services under Supervisor
- `caddy`: handles the browser-facing entrypoint and routes requests to the right internal service

Browser traffic goes through Caddy:

- `/` -> `myMPD`
- `/mpd.mp3` -> MPD's native HTTP stream
- `/snapweb/` -> Snapweb
- `/jsonrpc` and `/stream` -> Snapcast web endpoints

Native service ports stay available too, so regular MPD clients can still talk to `MPD_CONTROL_PORT`, and clients that expect MPD's built-in HTTP stream can still use `MPD_STREAM_PORT`.

## Quick Start

### Requirements

- Docker Engine
- Docker Compose
- a host path containing your music library
- DNS if you want direct public HTTPS
- a FreeDNS update URL if you want built-in dynamic DNS updates

### Fastest Setup

1. Copy [`.env.example`](./.env.example) to `.env`.
2. Set `MUSICSTACK_MUSIC_DIR` to your library path.
3. Set `MUSICSTACK_MPD_PASSWORD`.
4. Review [`config/mpd.conf`](./config/mpd.conf) and [`config/minidlna.conf`](./config/minidlna.conf) if you care about those defaults.
5. Start it:

```bash
docker compose up -d --build
```

Useful follow-ups:

```bash
docker compose logs -f
docker compose down
```

If you just want the short version: by default this is meant to sit behind another reverse proxy, serve plain HTTP on `EXTERIOR_PORT`, and keep persistent state under [`state/`](./state).

## Configuration

Create `.env` from [`.env.example`](./.env.example). The important variables are:

#### Core Site Behavior

- `MUSICSTACK_DOMAIN`: primary hostname
- `MUSICSTACK_SECDOMAIN`: only for the FreeDNS redirect-to-custom-port setup
- `EXTERIOR_PORT`: HTTP port published by Caddy
- `EXTERIOR_PORT_HTTPS`: HTTPS port used in direct-TLS mode
- `BEHIND_PROXY`: defaults to `true`
- `GET_HTTPS_CERTIFICATE`: defaults to `false`

### Music And MPD

- `MUSICSTACK_MUSIC_DIR`: host path mounted at `/media/music`
- `MUSICSTACK_MPD_PASSWORD`: MPD control password
- `MPD_CONNECT_HOST`: what `myMPD` should use to reach MPD; defaults to `/run/music-stack/mpd/socket`
- `MPD_CONTROL_PORT`: native MPD TCP port
- `MPD_STREAM_PORT`: native MPD HTTP stream port
- `STREAM_OUT`: enables or disables `/mpd.mp3`

### Optional Services

- `USE_SNAPCAST`
- `USE_MINIDLNA`
- `USE_AVAHI`
- `SNAPCAST_STREAM_PORT`
- `SNAPCAST_CONTROL_PORT`
- `SNAPWEB_PORT`
- `MINIDLNA_PORT`
- `MINIDLNA_DISCOVERY_PORT`
- `AVAHI_PUBLISHED_PORT`

### Scrobbling

- `MUSICSTACK_LASTFM_USERNAME`
- `MUSICSTACK_LASTFM_PASSWORD`
- `MUSICSTACK_LIBREFM_USERNAME`
- `MUSICSTACK_LIBREFM_PASSWORD`

### Web Authentication

- `MUSICSTACK_HTTP_BASIC_USER`
- `MUSICSTACK_HTTP_BASIC_PASSWORD_HASH`

### Host Avahi Integration

- `USE_HOST_AVAHI`: when `true`, the container prefers a mounted host Avahi socket if one is really there
- `HOST_DBUS_DIR`: host directory mounted at `/var/run/dbus`
- `HOST_AVAHI_DIR`: host directory mounted at `/run/avahi-daemon`

By default `HOST_DBUS_DIR` and `HOST_AVAHI_DIR` point at harmless repo-local stub directories. That is intentional. It lets the stack start cleanly on macOS and Windows instead of assuming Linux host sockets exist.

### Dynamic DNS

- `UPDATE_URL`: FreeDNS update endpoint; blank disables the updater

## Paths And Persistence

The host-managed parts are:

- [`music/`](./music) or whatever you set as `MUSICSTACK_MUSIC_DIR`
- [`config/`](./config) for editable service config
- [`state/`](./state) for persistent runtime state

Persistent state includes things like:

- MPD database
- MPD sticker database
- myMPD state
- MiniDLNA cache
- Snapserver state

That means container rebuilds do not wipe your learned state unless you remove `state/` yourself.

## Ports And Access

### Browser Paths Through Caddy

- `http://host:EXTERIOR_PORT/`
- `http://host:EXTERIOR_PORT/mpd.mp3`
- `http://host:EXTERIOR_PORT/snapweb/`
- `https://MUSICSTACK_DOMAIN[:EXTERIOR_PORT_HTTPS]/`
- `https://MUSICSTACK_DOMAIN[:EXTERIOR_PORT_HTTPS]/mpd.mp3`
- `https://MUSICSTACK_DOMAIN[:EXTERIOR_PORT_HTTPS]/snapweb/`

### Direct Service Ports

- `host:MPD_CONTROL_PORT` for native MPD clients
- `host:MPD_STREAM_PORT` for clients that expect MPD's built-in `httpd` output on `8000`
- `host:MINIDLNA_PORT` for MiniDLNA
- `host:SNAPCAST_STREAM_PORT` and `host:SNAPCAST_CONTROL_PORT` for Snapcast
- `host:SNAPWEB_PORT` for direct Snapweb access if you want it outside the Caddy path routing

### What To Forward Publicly

Usual sane defaults:

- If another reverse proxy is in front, forward only `EXTERIOR_PORT/tcp`
- If Caddy is doing public TLS itself, forward `80/tcp` and `443/tcp`
- Do not forward the native service ports to the internet unless you actually mean to

## Deployment Modes

### Default Mode: Behind Another Reverse Proxy

This is the intended default:

- `BEHIND_PROXY=true`
- `GET_HTTPS_CERTIFICATE=false`
- Caddy serves plain HTTP on `EXTERIOR_PORT`
- nginx, Caddy, Traefik, or something else in front can terminate TLS

### Optional Mode: Direct HTTPS

This is the no-other-reverse-proxy setup:

- `BEHIND_PROXY=false`
- `GET_HTTPS_CERTIFICATE=true`
- Caddy publishes `80` and `443`
- Caddy obtains certificates itself

## Example Setup: Behind Nginx

Example `.env`:

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
MUSICSTACK_LASTFM_USERNAME=
MUSICSTACK_LASTFM_PASSWORD=
MUSICSTACK_LIBREFM_USERNAME=
MUSICSTACK_LIBREFM_PASSWORD=
MUSICSTACK_HTTP_BASIC_USER=
MUSICSTACK_HTTP_BASIC_PASSWORD_HASH=
MPD_CONNECT_HOST=/run/music-stack/mpd/socket
USE_SNAPCAST=true
USE_MINIDLNA=true
USE_AVAHI=false
USE_HOST_AVAHI=true
HOST_DBUS_DIR=/var/run/dbus
HOST_AVAHI_DIR=/run/avahi-daemon
AVAHI_PUBLISHED_PORT=39535
STREAM_OUT=true
MPD_CONTROL_PORT=6600
MPD_STREAM_PORT=8000
MINIDLNA_PORT=8200
MINIDLNA_DISCOVERY_PORT=1900
SNAPCAST_STREAM_PORT=1704
SNAPCAST_CONTROL_PORT=1705
SNAPWEB_PORT=1780
```

Bring it up:

```bash
docker compose up -d --build
```

Then make nginx proxy `/`, `/mpd.mp3`, `/snapweb`, `/jsonrpc`, and `/stream` to `http://docker-host:38180`.

Example nginx config:

```nginx
map $http_upgrade $connection_upgrade {
    default upgrade;
    ''      close;
}

upstream music_caddy {
    server docker-host:38180;
    keepalive 32;
}

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
        proxy_pass http://music_caddy;
        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Host $host;

        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;

        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
        proxy_buffering off;
    }
}
```

## Example Setup: Direct HTTPS

Example `.env`:

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
MUSICSTACK_LASTFM_USERNAME=
MUSICSTACK_LASTFM_PASSWORD=
MUSICSTACK_LIBREFM_USERNAME=
MUSICSTACK_LIBREFM_PASSWORD=
MUSICSTACK_HTTP_BASIC_USER=
MUSICSTACK_HTTP_BASIC_PASSWORD_HASH=
MPD_CONNECT_HOST=/run/music-stack/mpd/socket
USE_SNAPCAST=true
USE_MINIDLNA=true
USE_AVAHI=true
USE_HOST_AVAHI=true
HOST_DBUS_DIR=/var/run/dbus
HOST_AVAHI_DIR=/run/avahi-daemon
AVAHI_PUBLISHED_PORT=5353
STREAM_OUT=true
MPD_CONTROL_PORT=6600
MPD_STREAM_PORT=8000
MINIDLNA_PORT=8200
MINIDLNA_DISCOVERY_PORT=1900
SNAPCAST_STREAM_PORT=1704
SNAPCAST_CONTROL_PORT=1705
SNAPWEB_PORT=1780
```

Then:

1. Point DNS at the host.
2. Forward `80/tcp` and `443/tcp` to the host.
3. Run `docker compose up -d --build`.

That is it. In this mode Caddy does its own certificate management.

## Securing The Web UI

If you want password protection for the browser-facing site without breaking native MPD clients, put the auth at the HTTP layer, not in MPD itself.

### Option 1: Caddy Basic Auth

Set both of these:

- `MUSICSTACK_HTTP_BASIC_USER`
- `MUSICSTACK_HTTP_BASIC_PASSWORD_HASH`

Caddy wants a hash, not plaintext. Generate one with:

```bash
docker run --rm caddy:2 caddy hash-password --plaintext 'your-password'
```

or:

```bash
htpasswd -nbB youruser 'your-password' | cut -d: -f2
```

Example:

```dotenv
MUSICSTACK_HTTP_BASIC_USER=youruser
MUSICSTACK_HTTP_BASIC_PASSWORD_HASH=$2y$05$...
```

### Option 2: Nginx Basic Auth

If nginx sits in front, you can leave Caddy unaware of the auth layer and enforce it there instead:

```nginx
location / {
    auth_basic "music";
    auth_basic_user_file /etc/nginx/.htpasswd;

    add_header Cache-Control "no-store, no-cache, must-revalidate" always;
    add_header Pragma "no-cache" always;

    proxy_pass http://music_caddy;
    proxy_http_version 1.1;

    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto https;
    proxy_set_header X-Forwarded-Host $host;

    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $connection_upgrade;

    proxy_read_timeout 86400;
    proxy_send_timeout 86400;
    proxy_buffering off;
}
```

### Using `mpv` With HTTP Basic Auth

If the stream is protected by HTTP auth, the reliable `mpv` form is usually:

```bash
printf '%s' 'username:password' | base64 -w0
mpv --http-header-fields='Authorization: Basic BASE64_USERPASS' \
  'https://music.example.com/mpd.mp3'
```

Embedding credentials in the URL can work too:

```bash
mpv 'https://username:password@music.example.com/mpd.mp3'
```

The header method is generally less annoying when the password contains special characters.

## Platform Notes

### Linux

If you want the container to use the real host Avahi and D-Bus sockets, set:

```dotenv
HOST_DBUS_DIR=/var/run/dbus
HOST_AVAHI_DIR=/run/avahi-daemon
```

If you do not care about that integration, leave the defaults alone.

### macOS And Windows

This stack should start cleanly on Docker Desktop without assuming Linux host sockets exist, but there are still a few caveats:

- Avahi, Bonjour, mDNS, and DLNA discovery are the least portable parts
- multicast and broadcast discovery are usually less reliable than on native Linux Docker hosts
- large libraries can scan more slowly because bind mounts go through Docker Desktop's file-sharing layer
- if you use an absolute `MUSICSTACK_MUSIC_DIR`, make sure Docker Desktop can actually see that path
- CRLF line endings can still break shell scripts on Windows if the checkout is wrong

In practice, direct MPD access on `MPD_CONTROL_PORT`, the native stream on `MPD_STREAM_PORT`, and the browser UI are much more dependable than LAN discovery features on Docker Desktop.

## Extra Admin Tasks

### Running A Second Instance On The Same Machine

You can do it, but do not try to share ports or state.

Recommended approach:

1. Use a different Compose project name, for example:

```bash
docker compose -p musicstack2 up -d --build
```

2. Point both stacks at the same music directory if you want.
3. Give the second stack different published ports.
4. Use a different hostname if both stacks are exposed through DNS or a reverse proxy.

Each stack should keep its own state. Sharing the music library is fine. Sharing the runtime state is not.

### Importing A Bare-Metal MPD Sticker Database

Inside the container, MPD uses:

- `sticker_file "/var/lib/mpd/sticker.sql"`

That path is redirected into the persistent state root, so one practical import method is:

```bash
docker compose cp /path/to/old/sticker.sql app:/var/lib/music-stack/mpd/sticker.sql
docker compose restart app
```

If this is a brand-new stack, do it before generating fresh MPD state.

### Importing Selected Stickers From A Remote MPD

This repo includes [`tools/import_remote_stickers.py`](./tools/import_remote_stickers.py), which copies selected stickers from an older MPD instance into the local Docker MPD.

It copies only:

- `bpm`
- `lastPlayed`
- `lastSkipped`
- `playCount`
- `skipCount`

Basic usage:

```bash
python3 tools/import_remote_stickers.py 'REMOTE_PASSWORD@remote-mpd-host'
```

Dry run:

```bash
python3 tools/import_remote_stickers.py 'REMOTE_PASSWORD@remote-mpd-host' --dry-run
```

The script reads local defaults from this repo's `.env`, not from your current shell directory.

## Bundled Music Attribution

The sample music files kept in [`music/`](./music) are attributed from [`1_reference/credit_music.txt`](./1_reference/credit_music.txt).

- `Javolenus_-_C95-RoutineMaintenanceMission.mp3`: "C95-RoutineMaintenanceMission" by Javolenus feat. nickleus. <http://ccmixter.org/files/Javolenus/37693>. CC BY 3.0.
- `_ghost_-_Reverie_(small_theme).mp3`: "Reverie (small theme)" by _ghost feat. Pitx. <http://ccmixter.org/files/_ghost/25389>. CC BY 3.0.
- `_ghost_-_Two_Swords.mp3`: "Two Swords" by _ghost feat. rocavaco and redhair. <http://ccmixter.org/files/_ghost/26146>. CC BY 3.0.
