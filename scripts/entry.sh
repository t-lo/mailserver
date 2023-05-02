#!/bin/ash

set -euo pipefail

export ADMIN_EMAIL="${ADMIN_USER}@${DOMAIN}"

function init_srv_cfg() {
    local service="$1"

    if ! test -d "/host/etc/${service}" ;  then
        echo "##### ENTRY: No '${service}' config folder found in host directory; creating."
        cp -vR "/etc/${service}" /host/etc/
    else
        echo "##### ENTRY: '${service}': using config in /host/etc/${service}."
    fi

    rm -rf "/etc/${service}"
    ln -vs "/host/etc/${service}" "/etc/${service}"

}
# --

function init_fail2ban() {
    init_srv_cfg fail2ban

    # Make sure grafana.log exists even if we don't use monitoring
    # otherwise fail2ban refuses to start since a log file is missing for the grafana jail
    mkdir -p /host/var/log/grafana/
    touch /host/var/log/grafana/grafana.log
    chown -R 472:root /host/var/log/grafana/

    envsubst '$ADMIN_EMAIL $DKIM_KEY_SELECTOR' < /etc/fail2ban/jail.conf.tmpl > /etc/fail2ban/jail.conf
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

    if ! grep -qE "^${ADMIN_EMAIL}:" /etc/dovecot/passwd ; then
        echo "##### ENTRY: Creating postmaster / admin account '${ADMIN_EMAIL}'"
	/add_user.sh "${ADMIN_EMAIL}" "${ADMIN_USER_INITIAL_PASSWORD}"
    fi

    envsubst '$HOSTNAME' < /etc/dovecot/conf.d/10-ssl.conf.tmpl > /etc/dovecot/conf.d/10-ssl.conf

    /update_aliases.sh
}
# --

function start_custom_metrics() {
    setsid -c /postfix_exporter --postfix.logfile_path /host/var/log/syslog.log \
                1>/host/var/log/postfix_exporter.log 2>&1 &
    setsid -c /fail2ban-prometheus-exporter \
                1>/host/var/log/fail2ban-prometheus-exporter.log 2>&1 &
    setsid -c /custom_stats.sh \
                1>/host/var/log/custom_stats.log 2>&1 &
    envsubst '$HOSTNAME' < /etc/caddy/Caddyfile.https.tmpl > /etc/caddy/Caddyfile.https
    caddy stop
    caddy start --config /host/etc/caddy/Caddyfile.https
}
# --

function init_opendkim() {
    init_srv_cfg opendkim
    envsubst '$ADMIN_EMAIL $DKIM_KEY_SELECTOR' < /etc/opendkim/opendkim.conf.tmpl > /etc/opendkim/opendkim.conf

    if !    test -f "/etc/opendkim/keys/${DKIM_KEY_SELECTOR}.private" \
              -a -f "/etc/opendkim/keys/${DKIM_KEY_SELECTOR}.txt" ; then 
        echo "##### ENTRY: Generating DKIM key for ${HOSTNAME}, selector '${DKIM_KEY_SELECTOR}'."
        mkdir -p -m 700 /etc/opendkim/keys/
        opendkim-genkey -vv -b 2048 -d "${HOSTNAME}"  -D /etc/opendkim/keys/ -s "${DKIM_KEY_SELECTOR}"
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

    mkdir -p /host/run/opendkim
}
# --

function init_opendmarc() {
    init_srv_cfg opendmarc
    envsubst '$HOSTNAME' < /etc/opendmarc/opendmarc.conf.tmpl > /etc/opendmarc/opendmarc.conf
    mkdir -p /host/run/opendmarc
}
# --

#
#   M A I N
#

echo "#################################  Startup $(date -Iseconds) #####################################"
mkdir -p /host/var/log /host/srv/www/html /host/etc

syslogd -O /host/var/log/syslog.log

echo "##### ENTRY: Processing fail2ban."
init_fail2ban

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
opendkim -A
opendmarc -A -c /etc/opendmarc/opendmarc.conf
fail2ban-server

if test "${METRICS:-}" = "true" ; then
    echo "   ## ENTRY: Metrics / Monitoring services requested"
    echo "             Starting postfix_exporter/custom stats and restarting Caddy on HTTPS"
    start_custom_metrics
fi

echo
echo "##### Mail server system up and running on ${HOSTNAME}."
echo

sleep 2

# Caddy log is too noisy to tail
tail -f /host/var/log/syslog.log \
       	/host/var/log/custom_stats.log \
	/host/var/log/fail2ban-prometheus-exporter.log  \
	/host/var/log/postfix_exporter.log
