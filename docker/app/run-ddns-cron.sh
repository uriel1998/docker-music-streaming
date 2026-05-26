#!/bin/sh
set -eu

update_url="${UPDATE_URL:-}"

# Idle cleanly when dynamic DNS updates are not configured.
if [ -z "${update_url}" ]; then
    exec sleep infinity
fi

safe_domain="$(printf '%s' "${MUSICSTACK_DOMAIN:-freedns}" | tr '/:.?=&' '_')"
log_file="/tmp/freedns_${safe_domain}.log"

# Install the requested FreeDNS schedule verbatim so the updater keeps working
# after container restarts without requiring host cron configuration.
cat > /etc/cron.d/freedns-update <<EOF
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
2,7,12,17,22,27,32,37,42,47,52,57 * * * * root sleep 35 ; wget --no-check-certificate -O - ${update_url} >> ${log_file} 2>&1 &
EOF

chmod 0644 /etc/cron.d/freedns-update
touch "${log_file}"

# `cron -f` remains in the foreground for Supervisor.
exec cron -f
