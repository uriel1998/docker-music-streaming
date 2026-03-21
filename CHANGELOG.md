# Changelog

This file summarizes notable project changes in a human-readable form.

## 2026-03-21

### Current Release Notes

Compared with the 2022 version, the current project has been refactored from an Apache/RompR-era stack into a myMPD-and-Caddy deployment with a clearer reverse-proxy-first default. The browser-facing surface is now routed through Caddy so `/` goes to myMPD, `/mpd.mp3` goes to the MPD HTTP stream, and `/snapweb` plus its related websocket paths go to Snapweb when Snapcast is enabled. The application image has been retargeted to Debian Trixie, myMPD is installed from the official upstream repository, configuration is driven through a normalized `.env` contract, and legacy artifacts that are no longer used by the active stack have been removed from the public repository. Avahi, MiniDLNA, and Snapcast are now toggleable, host Avahi integration is wired in by default on Linux-style hosts, and the README and inline comments have been updated to describe the current behavior rather than the older 2022 design.

### Changed

- Switched the active application image from the older Debian baseline to Debian Trixie.
- Moved myMPD installation to the official upstream JCorporation APT repository instead of relying on the distro package alone.
- Refactored the deployment to use Caddy as the browser-facing router for myMPD, the MPD stream, and Snapweb-related paths.
- Changed the default deployment model to assume the stack sits behind another reverse proxy, with Caddy serving plain HTTP on a user-defined port by default.
- Kept direct HTTPS mode available for the case where there is no other reverse proxy and Caddy should handle TLS itself.
- Made Snapcast, MiniDLNA, and Avahi runtime-toggleable through environment variables.
- Added host-Avahi integration by default through mounted D-Bus and Avahi sockets on Linux-style hosts.
- Enumerated the additional exposed native service ports in `.env.example` so the port contract is explicit.

### Fixed

- Fixed behind-proxy Caddy behavior so myMPD is served correctly even when requests do not arrive with the external domain as the `Host` header.
- Clarified and stabilized the shared browser-facing routing for `/`, `/mpd.mp3`, and `/snapweb`.

### Documentation

- Rewrote the README to describe the current stack, reverse-proxy default behavior, port-forwarding expectations, and example deployments.
- Added and cleaned up inline comments so they describe the current state of the project instead of older implementation paths.
- Removed stale references to `catt` after it was dropped from the active project.

## 2026-03-20

### Changed

- Normalized the environment file format to standard Docker Compose `KEY=value` syntax.
- Added a tracked `.env.example` so the deployment contract is documented without checking in the local `.env`.
- Added a new Compose-driven deployment layout with a dedicated Caddy service in front of the application container.
- Replaced the legacy Apache/RompR flow with a myMPD-based application image managed by Supervisor.
- Preserved host-editable configuration under `config/` and kept service state in named Docker volumes.
- Added the FreeDNS updater inside the application container using the requested cron schedule.

### Repository Cleanup

- Updated `.gitignore` for the current project layout and runtime artifacts.
- Removed unused Apache-era artifacts and other no-longer-active files from the public repository.

### Documentation

- Added a project changelog.
- Expanded the README, then restyled it into a more practical narrative format.
- Replaced the old verification section with concrete setup examples.

## 2022-10-13

### Legacy 2022 Release

The 2022 version reached a working state around an Apache/PHP-based stack with RompR, MPD, mpdscribble, Snapcast, Snapweb, and MiniDLNA. That version established the original bundled-service approach, the host-mounted config pattern, and the prebuilt Snapweb assets, but it still reflected the older control surface, older packaging choices, and the earlier Docker layout that the current project now keeps only as reference material.

### Established In 2022

- Bundled MPD, mpdscribble, Snapcast, Snapweb, and MiniDLNA into the project.
- Used Supervisor to manage multiple long-running services inside the container.
- Added host-mounted configs and sample media for getting started.
- Included prebuilt Snapweb assets because the packaged Snapserver build did not include them.
- Documented the original Apache/RompR-based deployment approach.
