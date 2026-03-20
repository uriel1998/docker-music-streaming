#!/bin/sh
set -eu

# Stay in the foreground so Supervisor can monitor the Avahi daemon directly.
exec avahi-daemon --no-chroot --debug
