#!/bin/sh
set -eu

domain="${DOMAIN:?DOMAIN is required}"
secdomain="${SECDOMAIN:-}"
behind_proxy="${BEHIND_PROXY:-false}"
get_https_certificate="${GET_HTTPS_CERTIFICATE:-true}"
stream_out="${STREAM_OUT:-true}"

hosts="${domain}"
if [ -n "${secdomain}" ]; then
    hosts="${hosts} ${secdomain}"
fi

site_labels=""
for host in ${hosts}; do
    if [ -n "${site_labels}" ]; then
        site_labels="${site_labels}, "
    fi

    if [ "${get_https_certificate}" = "true" ] && [ "${behind_proxy}" != "true" ]; then
        site_labels="${site_labels}${host}"
    else
        site_labels="${site_labels}http://${host}"
    fi
done

cat > /etc/caddy/Caddyfile <<EOF
{
    auto_https disable_redirects
}

${site_labels} {
    encode zstd gzip
EOF

if [ "${stream_out}" = "true" ]; then
    cat >> /etc/caddy/Caddyfile <<'EOF'

    handle /mpd.mp3 {
        reverse_proxy app:8000
    }
EOF
fi

cat >> /etc/caddy/Caddyfile <<'EOF'

    handle {
        reverse_proxy app:8080
    }
}
EOF

if [ "${get_https_certificate}" = "true" ] && [ "${behind_proxy}" != "true" ]; then
    # Re-enable Caddy's normal automatic HTTPS behavior for public deployments.
    sed -i '1,3d' /etc/caddy/Caddyfile
fi

exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
