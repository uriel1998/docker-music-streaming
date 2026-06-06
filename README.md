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
- `MUSICSTACK_LASTFM_USERNAME` and `MUSICSTACK_LASTFM_PASSWORD`: enable Last.fm scrobbling when both are set
- `MUSICSTACK_LIBREFM_USERNAME` and `MUSICSTACK_LIBREFM_PASSWORD`: enable Libre.fm scrobbling when both are set
- `MUSICSTACK_HTTP_BASIC_USER` and `MUSICSTACK_HTTP_BASIC_PASSWORD_HASH`: optionally enable Caddy HTTP Basic Auth for the browser-facing site
- `MPD_CONNECT_HOST`: the MPD host or socket path myMPD should use; defaults to `/run/music-stack/mpd/socket`
- `USE_SNAPCAST`: enables or disables Snapcast and Snapweb routing
- `USE_MINIDLNA`: enables or disables MiniDLNA
- `USE_AVAHI`: enables or disables Avahi
- `USE_HOST_AVAHI`: when `true`, the container prefers host Avahi integration if the mounted host sockets are actually present; otherwise it falls back to its internal daemons
- `HOST_DBUS_DIR`: host directory mounted at `/var/run/dbus`; defaults to a harmless repo-local stub and should only be changed on Linux hosts that want real host D-Bus access
- `HOST_AVAHI_DIR`: host directory mounted at `/run/avahi-daemon`; defaults to a harmless repo-local stub and should only be changed on Linux hosts that want real host Avahi access
- `AVAHI_PUBLISHED_PORT`: host UDP port forwarded to Avahi's internal `5353/udp`
- `STREAM_OUT`: enables or disables `/mpd.mp3`

Additional service ports are explicitly enumerated in the env files:

- `MPD_CONTROL_PORT`
- `MPD_STREAM_PORT`
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

Runtime state lives under [`state/`](/home/steven/Documents/programming/#music/docker-music-streaming/state) on the host so rebuilding the image does not wipe learned or cached data.

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

Persistent app data, including MPD's database and sticker state, will be stored in [`state/`](/home/steven/Documents/programming/#music/docker-music-streaming/state) on the host.

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
- `host:MPD_STREAM_PORT`: direct MPD HTTP stream access for clients that expect MPD's native `httpd` output on port `8000`
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
- `MPD_STREAM_PORT/tcp`
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
- On Linux hosts, set `HOST_DBUS_DIR=/var/run/dbus` and `HOST_AVAHI_DIR=/run/avahi-daemon` if you want `USE_HOST_AVAHI=true` to share the real host D-Bus and Avahi sockets. The defaults are repo-local stub directories so macOS and Windows Docker hosts can start cleanly without those Linux-specific paths.
- The default deployment assumes another reverse proxy may sit in front of Caddy, so automatic certificate generation is off unless you explicitly enable direct HTTPS mode.
- Avahi and DLNA discovery tend to behave better on Linux Docker hosts than on macOS or Windows Docker backends.
- The bundled Snapweb assets are copied from [`build/snapweb/`](/home/steven/Documents/programming/docker-music-streaming/build/snapweb) during the image build.

## Appendix: macOS And Windows Cautions

This stack can run on Docker Desktop, and the current defaults now avoid a hard dependency on Linux host socket paths, but some features are still more Linux-host-oriented than macOS- or Windows-specific.

- The `app` service still mounts `/var/run/dbus` and `/run/avahi-daemon` inside the container, but the host-side sources now default to repo-local stub directories instead of Linux runtime paths. On Linux, point `HOST_DBUS_DIR` and `HOST_AVAHI_DIR` at the real host paths if you want host Avahi integration.
- `USE_HOST_AVAHI=true` only changes behavior when a usable host Avahi socket is actually present in the mounted directory. On macOS or Windows, the default stub mounts simply cause the container to fall back to its internal D-Bus and Avahi daemons.
- Avahi, Bonjour, mDNS, and DLNA discovery are the least portable parts of the stack. Even when the containers start, Docker Desktop's VM-backed networking can make multicast and broadcast discovery less reliable than on a native Linux Docker host.
- Direct TCP services are more likely to work than discovery-based ones. In practice, myMPD over HTTP, MPD on `MPD_CONTROL_PORT`, and the direct MPD stream on `MPD_STREAM_PORT` are better bets than relying on automatic network discovery.
- Large music libraries may scan more slowly on macOS or Windows because the music directory and persistent state are bind-mounted from the host. Docker Desktop routes those through its file-sharing layer, which is usually slower than native Linux filesystem access.
- If you set `MUSICSTACK_MUSIC_DIR` to an absolute host path, use a path format Docker Desktop accepts and make sure the parent location is shared with Docker. The default relative `./music` path is the safest starting point.
- Windows users should watch out for CRLF line endings in shell scripts. This repository does not currently force LF checkouts for the startup scripts, and a CRLF checkout can break container startup when `/bin/sh` tries to execute those mounted files.
- Public port publishing works normally on Docker Desktop, but host-LAN service advertisement is a separate issue. A working `http://host:EXTERIOR_PORT/` or `host:8000` stream does not imply that DLNA or Avahi clients elsewhere on the LAN will discover the service automatically.

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

## Securing The Web UI

If you want password protection for the browser-facing site without affecting
native MPD clients, put the protection at the HTTP layer, not in MPD itself.
That keeps `MPD_CONTROL_PORT` usable for normal MPD clients while protecting
myMPD, `/mpd.mp3`, and the optional Snapweb routes in the browser.

### Option 1: Caddy Basic Auth

This repository supports optional Caddy HTTP Basic Auth through these `.env`
variables:

- `MUSICSTACK_HTTP_BASIC_USER`
- `MUSICSTACK_HTTP_BASIC_PASSWORD_HASH`

If both are set, the generated Caddy config will protect the whole
browser-facing site.

Caddy requires a hashed password, not plaintext. You can generate a usable hash
with either:

```bash
docker run --rm caddy:2 caddy hash-password --plaintext 'your-password'
```

or a standard system tool such as `htpasswd`:

```bash
htpasswd -nB youruser | cut -d: -f2
```

If you want to avoid the interactive password prompt:

```bash
htpasswd -nbB youruser 'your-password' | cut -d: -f2
```

Then set, for example:

```dotenv
MUSICSTACK_HTTP_BASIC_USER=youruser
MUSICSTACK_HTTP_BASIC_PASSWORD_HASH=$2y$05$...
```

Programmatic access can then authenticate with normal HTTP Basic Auth headers,
for example with `curl -u youruser:your-password`.

### Option 2: Nginx Basic Auth

If nginx sits in front of Caddy, you can instead protect the site at nginx and
leave Caddy unaware of the HTTP auth layer.

Typical nginx location example:

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

You can generate the `.htpasswd` entry with:

```bash
htpasswd -nB youruser
```

In both approaches, the protection applies only to the HTTP entrypoint. Native
MPD protocol clients still authenticate against MPD itself using
`MUSICSTACK_MPD_PASSWORD`.

• If the stream is protected by HTTP Basic Auth from htpasswd, the reliable mpv
  form is to send the Authorization header explicitly.

  mpv --http-header-fields='Authorization: Basic BASE64_USERPASS'
  'https://music.example.com/mpd.mp3'

  Generate BASE64_USERPASS from username:password:

  printf '%s' 'username:password' | base64 -w0

  Example:

  mpv --http-header-fields='Authorization: Basic dXNlcm5hbWU6cGFzc3dvcmQ='
  'https://music.example.com/mpd.mp3'

  You can also try embedding credentials in the URL:

  mpv 'https://username:password@music.example.com/mpd.mp3'

  but the header method is usually safer, especially if the password has special
  characters.
  
## Appendix: Second Instance On The Same Machine

You can run a second copy of this stack on the same host and point it at the
same music library, but it must have its own Compose project name, its own
state volumes, and its own published ports.

Recommended approach:

1. Copy this repository to a second directory, or run the second stack with a
   distinct Compose project name such as:

```bash
docker compose -p musicstack2 up -d --build
```

2. Point `MUSICSTACK_MUSIC_DIR` at the same host music directory if you want
   both stacks to index the same library.

3. Change every published port in the second `.env` so it does not collide with
   the first stack:

- `EXTERIOR_PORT`
- `EXTERIOR_PORT_HTTPS` if you publish it
- `MPD_CONTROL_PORT`
- `MINIDLNA_PORT`
- `MINIDLNA_DISCOVERY_PORT`
- `SNAPCAST_STREAM_PORT`
- `SNAPCAST_CONTROL_PORT`
- `SNAPWEB_PORT`
- `AVAHI_PUBLISHED_PORT`

4. Use a different `MUSICSTACK_DOMAIN` if both stacks are meant to be reachable
   through a reverse proxy or public DNS.

Sharing the same music directory is fine. Each stack keeps its own MPD
database, stickers, myMPD state, MiniDLNA state, and Snapserver state in its
own named Docker volumes.

If you do not need discovery or streaming services on the second instance, it
is often cleaner to disable some of them there with `USE_SNAPCAST=false`,
`USE_MINIDLNA=false`, or `USE_AVAHI=false`.

## Appendix: Importing A Bare-Metal MPD Sticker Database

This stack keeps MPD state inside the app state volume. Inside the container,
MPD uses:

- `sticker_file "/var/lib/mpd/sticker.sql"`

That path is symlinked into the named volume mounted at `/var/lib/music-stack`,
so the persistent host-side target is the volume-backed file at:

- `/var/lib/music-stack/mpd/sticker.sql` inside the `app` container

If you want to import an old bare-metal MPD sticker database, copy your
existing `sticker.sql` into that path before first startup, or into the running
container afterward and then restart the app service.

One practical method after the stack exists is:

```bash
docker compose cp /path/to/old/sticker.sql app:/var/lib/music-stack/mpd/sticker.sql
docker compose restart app
```

If you are restoring into a brand-new stack, do it before generating new MPD
state so the imported sticker database becomes the active one immediately.

## Appendix: Importing Selected Stickers From A Remote MPD

This repository includes a host-run helper script at
[`tools/import_remote_stickers.py`](/home/steven/Documents/programming/#music/docker-music-streaming/tools/import_remote_stickers.py:1)
for copying selected stickers from an older MPD instance into the local Docker
MPD over the MPD protocol.

The script copies only these sticker names:

- `bpm`
- `lastPlayed`
- `lastSkipped`
- `playCount`
- `skipCount`

Remote `playcount` is normalized to local `playCount`. If both `playcount` and
`playCount` exist remotely, the larger value is used and written back only as
`playCount`.

Basic usage:

```bash
python3 tools/import_remote_stickers.py 'REMOTE_PASSWORD@remote-mpd-host'
```

Dry run:

```bash
python3 tools/import_remote_stickers.py 'REMOTE_PASSWORD@remote-mpd-host' --dry-run
```

The script reads local defaults from this repository's `.env` file next to
`compose.yaml`, not from your current working directory:

- `MUSICSTACK_MPD_PASSWORD`
- `MPD_CONTROL_PORT`

If needed, you can point it at a different env file with `--dotenv /path/to/.env`.

You can see all options with:

```bash
python3 tools/import_remote_stickers.py --help
```

This works by talking to both MPD servers directly. It does not edit
`sticker.sql` files in place, so the local Docker MPD should already be running
and reachable on `MPD_CONTROL_PORT`.

## Appendix: Bundled Music Attribution

The sample music files kept in [`music/`](/home/steven/Documents/programming/#music/docker-music-streaming/music) are attributed from [`1_reference/credit_music.txt`](/home/steven/Documents/programming/#music/docker-music-streaming/1_reference/credit_music.txt).

- `10-The_Theme.mp3`: "The Theme" by echoed. <http://echoedmusic.com/album/echoed-2>. CC BY-NC 3.0.
- `AlexBeroza_-_Free_Music_Free_Beer.mp3`: "Free Music & Free Beer" by Alex Beroza feat. Admiral Bob. <http://ccmixter.org/files/AlexBeroza/38167>. CC BY 3.0.
- `Citizen_X0_-_Ghosts_in_the_wind.mp3`: "Ghosts in the wind" by Abstract Audio feat. orang_redux_777. <http://ccmixter.org/files/Citizen_X0/29247>. CC BY 3.0.
- `djlang59_-_Drops_of_H2O_(_The_Filtered_Water_Treatment_).mp3`: "Drops of H2O ( The Filtered Water Treatment )" by J. Lang feat. Airtone. <http://ccmixter.org/files/djlang59/37792>. CC BY 3.0.
- `flatwound_-_The_Long_Goodbye.mp3`: "The Long Goodbye" by John Pazdan. <http://ccmixter.org/files/flatwound/14476>. CC BY 2.5.
- `gurdonark_-_Grasslands.mp3`: "Grasslands" by Gurdonark feat. Vo1k1. <http://ccmixter.org/files/gurdonark/39200>. CC BY 3.0.
- `gurdonark_-_Sawmill.mp3`: "Sawmill" by Gurdonark. <http://ccmixter.org/files/gurdonark/23358>. CC BY 3.0.
- `Javolenus_-_C95-RoutineMaintenanceMission.mp3`: "C95-RoutineMaintenanceMission" by Javolenus feat. nickleus. <http://ccmixter.org/files/Javolenus/37693>. CC BY 3.0.
- `jlbrock44_-_Theatrical_Trailer_(annabloom_vs._Jeris).mp3`: "Theatrical Trailer (annabloom vs. Jeris)" by spinningmerkaba feat. annabloom and Jeris. <http://ccmixter.org/files/jlbrock44/33300>. CC BY 3.0.
- `jlbrock44_-_Urbana-Metronica_(wooh-yeah_mix).mp3`: "Urbana-Metronica (wooh-yeah mix)" by spinningmerkaba feat. Morusque, Jeris, CSoul, and Alex Beroza. <http://ccmixter.org/files/jlbrock44/33345>. CC BY 3.0.
- `jlbrock44_-_Winter_Walk_(Silver_Trumpet_Mix).mp3`: "Winter Walk (Silver Trumpet Mix)" by spinningmerkaba feat. donkeyhorsemule. <http://ccmixter.org/files/jlbrock44/35050>. CC BY 3.0.
- `Karstenholymoly_-_Undercover.mp3`: "Undercover" by Karstenholymoly. <http://dig.ccmixter.org/files/Karstenholymoly/40639>. CC BY 3.0.
- `Lost Frontier.mp3`: "Lost Frontier" by Kevin MacLeod. <http://creativecommons.org/licenses/by/3.0/>. CC BY 3.0.
- `PerlssDj_-_Anaerobica.mp3`: "Anaerobica" by PerlssDj. <http://ccmixter.org/files/PerlssDj/12774>. CC Sampling+ 1.0.
- `psychadelik_pedestrian_-_Cry_Over_You_(black_moon_mix).mp3`: "Cry Over You (black moon mix)" by Psychadelik Pedestrian. <http://ccmixter.org/files/psychadelik_pedestrian/33020>. CC BY-NC 3.0.
- `scottaltham_-_Never_Heard_a_Rhyme_Like_This_Before.mp3`: "Never Heard a Rhyme Like This Before" by scottaltham. <http://ccmixter.org/files/scottaltham/18619>. CC BY 2.5.
- `_ghost_-_Reverie_(small_theme).mp3`: "Reverie (small theme)" by _ghost feat. Pitx. <http://ccmixter.org/files/_ghost/25389>. CC BY 3.0.
- `_ghost_-_Two_Swords.mp3`: "Two Swords" by _ghost feat. rocavaco and redhair. <http://ccmixter.org/files/_ghost/26146>. CC BY 3.0.
- `_ghost_-_Warm_Ink.mp3`: "Warm Ink" by _ghost. <http://ccmixter.org/files/_ghost/37481>. CC BY 3.0.
