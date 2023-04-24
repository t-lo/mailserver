FROM alpine

# Config env:
# ${DOMAIN}
# ${HOSTNAME} (w/o domain)
# ${ADMIN_EMAIL} (ideally NOT on this server)

# TODO: script for automating postfix vuser, valias, dovecot passwd

RUN apk update \
    && apk upgrade \
    && apk add postfix certbot opendkim opendmarc caddy \
               ca-certificates-bundle dovecot dovecot-pigeonhole-plugin \
               dovecot-lmtpd gettext openssl fail2ban pwgen bind-tools curl

COPY caddy/Caddyfile.http /etc/caddy/
COPY dovecot/dovecot.conf /etc/dovecot/
COPY dovecot/conf.d/* /etc/dovecot/conf.d/

COPY postfix/main.cf.tmpl /etc/postfix/
COPY postfix/master.cf /etc/postfix/
RUN touch /etc/postfix/vuser /etc/postfix/valias

RUN addgroup -g 2001 mailuser \
    && adduser -G mailuser -u 2001 -D -H mailuser

COPY --chmod=755 scripts/* /

entrypoint /entry.sh
