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
# --

function check_letsencrypt() {
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
}
# --

function init_postfix() {
    init_srv_cfg postfix
    envsubst '$DOMAIN $HOSTNAME $ADDITIONAL_DOMAINS' < /etc/postfix/main.cf.tmpl > /etc/postfix/main.cf
}
# --

function init_dovecot() {
    init_srv_cfg dovecot

    mkdir -p /host/mail/inboxes/
    chown mailuser:mailuser /host/mail/inboxes/

    if ! test -f /etc/dovecot/dh.pem ;  then
        echo "##### ENTRY: Generating DH parameters. Go fetch a tea?"
        openssl dhparam -out /etc/dovecot/dh.pem 4096
    fi

    envsubst '$HOSTNAME' < /etc/dovecot/conf.d/10-ssl.conf.tmpl > /etc/dovecot/conf.d/10-ssl.conf

    /update_aliases.sh
}
# --

function start_custom_metrics() {
    setsid -c /postfix_exporter --postfix.logfile_path /host/var/log/postfix.log \
                1>/host/var/log/postfix_exporter.log 2>&1 &
    setsid -c /custom_stats.sh --postfix.logfile_path /host/var/log/postfix.log \
                1>/host/var/log/custom_stats.log 2>&1 &
    envsubst '$HOSTNAME' < /etc/caddy/Caddyfile.https.tmpl > /etc/caddy/Caddyfile.https
    caddy stop
    caddy start --config /host/etc/caddy/Caddyfile.https
}
# --

function init_opendkim() {
    init_srv_cfg opendkim
    envsubst '$ADMIN_EMAIL' < /etc/opendkim/opendkim.conf.tmpl > /etc/opendkim/opendkim.conf

    if !    test -f "/etc/opendkim/keys/${DKIM_KEY_SELECTOR}.private" \
              -a -f "/etc/opendkim/keys/${DKIM_KEY_SELECTOR}.txt" ; then 
        echo "##### ENTRY: Generating DKIM key for ${HOSTNAME}, selector '${DKIM_KEY_SELECTOR}'."
        mkdir -p -m 700 /etc/opendkim/keys/
        opendkim-genkey -vv -b 4096 -d "${HOSTNAME}"  -D /etc/opendkim/keys/ -s "${DKIM_KEY_SELECTOR}"
    fi

    echo "##### ENTRY: Generating openDKIM domains verification and signing tables."
    rm -f /etc/opendkim/keytable /etc/opendkim/signingtable
    local privkey="/etc/opendkim/keys/${DKIM_KEY_SELECTOR}.private"
    for d in ${DOMAIN} $(echo "${ADDITIONAL_DOMAINS}" | sed 's/,/ /g'); do
        echo "${DKIM_KEY_SELECTOR}._domainkey.${d} ${d}:${DKIM_KEY_SELECTOR}:${privkey}" \
            >> /etc/opendkim/keytable
        echo "*@${d} ${DKIM_KEY_SELECTOR}._domainkey.${d}" \
            >> /etc/opendkim/signingtable
    done

}
# --

function init_opendmarc() {
    init_srv_cfg opendmarc
    
}
#
#   M A I N
#

echo "#################################  Startup $(date -Iseconds) #####################################"
mkdir -p /host/var/log /host/srv/www/html /host/etc

syslogd -O /host/var/log/syslog

echo "##### ENTRY: starting caddy."
init_srv_cfg caddy
caddy start --config /host/etc/caddy/Caddyfile.http

echo "##### ENTRY: Processing letsencrypt."
check_letsencrypt

echo "##### ENTRY: Processing opendkim."
init_opendkim

echo "##### ENTRY: Processing opendmarc."
init_opendmarc

echo "##### ENTRY: Processing postfix."
init_postfix

echo "##### ENTRY: Processing dovecot."
init_dovecot

echo "##### ENTRY: Starting services"
postfix start
dovecot
opendkim

if test "${METRICS:-}" = "true" ; then
    echo "   ## ENTRY: Metrics / Monitoring services requested"
    echo "             Starting postfix_exporter/custom stats and restarting Caddy on HTTPS"
    start_custom_metrics
fi

echo
echo "##### Mail server system up and running on ${HOSTNAME}."
echo

sleep 5

tail -f /host/var/log/*
