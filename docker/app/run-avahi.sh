#!/bin/sh
set -eu

exec avahi-daemon --no-chroot --debug
