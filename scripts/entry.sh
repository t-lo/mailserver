#!/bin/ash

set -euo pipefail

function init_srv_cfg() {
    local service="$1"

    if ! test -d "/host/etc/${service}" ;  then
        echo "##### ENTRY: No '${service}' config folder found in host directory; creating."
        cp -vR "/etc/${service}" /host/etc/
    else
        echo "##### ENTRY: '${service}': using config in /host/etc/${service}."
    fi

    rm -rf "/etc/${service}"
    ln -s "/host/etc/${service}" "/etc/${service}"

}

mkdir -p /host/var/log /host/srv/www/html /host/etc

echo "##### ENTRY: starting caddy and checking certificates"
init_srv_cfg caddy
caddy start --config /host/etc/caddy/Caddyfile.http

if ! test -d /host/etc/letsencrypt/live ;  then
    echo "##### ENTRY: No certificates folder found in host directory; requesting certs for '${HOSTNAME}'."
    certbot certonly --non-interactive --webroot --webroot-path /host/srv/www/html \
         --agree-tos --email "${ADMIN_EMAIL}" \
        -d "${HOSTNAME}"
else
    echo "##### ENTRY: checking for certificate renewals"
    certbot renew --non-interactive --webroot --webroot-path /host/srv/www/html
fi
init_srv_cfg letsencrypt

echo "##### ENTRY: Processing postfix."
init_srv_cfg postfix
/update_aliases.sh

echo "##### ENTRY: Processing dovecot."
init_srv_cfg dovecot
mkdir -p /host/mail/inboxes/
chown mailuser:mailuser /host/mail/inboxes/
if ! test -f /etc/dovecot/dh.pem ;  then
    echo "##### ENTRY: Generating DH parameters. Go fetch a tea?"
    openssl dhparam -out /etc/dovecot/dh.pem 4096
fi

echo "##### ENTRY: Rendering configs"
envsubst '$DOMAIN $HOSTNAME $ADDITIONAL_DOMAINS' < /etc/postfix/main.cf.tmpl > /etc/postfix/main.cf
envsubst '$HOSTNAME' < /etc/dovecot/conf.d/10-ssl.conf.tmpl > /etc/dovecot/conf.d/10-ssl.conf

echo "##### ENTRY: Starting services"
postfix start
dovecot

if test "${METRICS:-}" = "true" ; then
    echo "   ## ENTRY: Metrics / Monitoring services requested"
    echo "             Starting postfix_exporter/custom stats and restarting Caddy on HTTPS"
    setsid -c /postfix_exporter --postfix.logfile_path /host/var/log/postfix.log \
                1>/host/var/log/postfix_exporter.log 2>&1 &
    setsid -c /custom_stats.sh --postfix.logfile_path /host/var/log/postfix.log \
                1>/host/var/log/custom_stats.log 2>&1 &
    envsubst '$HOSTNAME' < /etc/caddy/Caddyfile.https.tmpl > /etc/caddy/Caddyfile.https
    caddy stop
    caddy start --config /host/etc/caddy/Caddyfile.https
fi

echo
echo "##### Mail server system up and running on ${HOSTNAME}."
echo

tail -f /host/var/log/*
