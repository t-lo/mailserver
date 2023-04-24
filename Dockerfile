# First, build the metrics exporter.
# We ship it even if the monitoring back-end is not being used.
FROM alpine AS builder
ARG version=0.3.0

RUN apk update \
    && apk add go

RUN echo "Downloading '$version'" \
    && wget https://github.com/kumina/postfix_exporter/archive/refs/tags/$version.tar.gz \
    && tar -xzvf $version.tar.gz

RUN cd /postfix_exporter-$version \
    && go get -d ./... \
    && go build -a -tags nosystemd \
    && strip postfix_exporter \
    && mv postfix_exporter /


FROM alpine

COPY --from=builder /postfix_exporter /
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
