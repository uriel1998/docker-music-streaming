# Changelog

## 2026-03-20

### Step 1
- Reworked `.gitignore` around the actual project layout instead of hiding reference artifacts and instruction files.
- Kept `1_reference/` and `INSTRUCTIONS.txt` available as local migration source material while excluding them from the final project history.
- Added ignore coverage for local env files, runtime state, media, playlists, and common editor/build noise.
- Confirmed there were no currently tracked media or env files that needed to be removed from version control in this step.

### Step 2
- Normalized the environment keys to Docker Compose `.env` format using `KEY=value`.
- Added a tracked `.env.example` template so the deployment contract is committed without forcing a secret-bearing `.env` into version control.
- Chose explicit boolean and port defaults so Compose can interpolate them without extra transformation.

### Step 3
- Added `compose.yaml` with an env-driven two-service layout: the application image plus a Caddy edge service.
- Wired the public ports through `EXTERIOR_PORT` and `EXTERIOR_PORT_HTTPS`, while keeping the media/control ports directly available for MPD, DLNA, Snapcast, and mDNS.
- Added a Caddy startup script that generates the effective `Caddyfile` from `.env`, including conditional automatic HTTPS based on `GET_HTTPS_CERTIFICATE` and `BEHIND_PROXY`.
- Routed the primary web UI through Caddy and made MPD stream proxying conditional on `STREAM_OUT`.

### Step 4
- Added a new Debian-based application image that installs avahi, myMPD, MPD, minidlna, mpdscribble, snapserver, supervisor, and `catt`.
- Replaced the legacy Apache/RompR startup flow with supervisor-managed service scripts under `docker/app/`.
- Kept service configuration externalized by copying from `/config` at startup and persisting runtime state under named Docker volumes.
- Added the requested FreeDNS cron updater inside the application container.
- Updated the README to describe the new myMPD+Caddy deployment model and the `.env` contract.
