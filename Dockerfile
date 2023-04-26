# First, build the metrics exporter and the "prips" (print ip ranges) tool.
FROM alpine AS builder
ARG postfix_exporter_version=0.3.0
ARG prips_version=1.2.0

RUN apk update \
    && apk add go gcc make musl-dev

RUN echo "Downloading and building Postfix exporter version '$postfix_exporter_version'" \
    && wget https://github.com/kumina/postfix_exporter/archive/refs/tags/$postfix_exporter_version.tar.gz \
    && tar -xzvf $postfix_exporter_version.tar.gz

RUN cd /postfix_exporter-$postfix_exporter_version \
    && go get -d ./... \
    && go build -a -tags nosystemd \
    && strip postfix_exporter \
    && mv postfix_exporter /

RUN echo "Downloading and building prips version '$prips_version'" \
    && wget https://devel.ringlet.net/files/sys/prips/prips-$prips_version.tar.gz \
    && tar -xzvf prips-$prips_version.tar.gz

RUN cd /prips-$prips_version \
    && make \
    && strip prips \
    && mv prips /


FROM alpine

COPY --from=builder /postfix_exporter /prips /
RUN apk update \
    && apk upgrade \
    && apk add postfix certbot opendkim opendmarc caddy \
               ca-certificates-bundle dovecot dovecot-pigeonhole-plugin \
               dovecot-lmtpd gettext openssl fail2ban pwgen bind-tools curl jq

COPY caddy/Caddyfile.http caddy/Caddyfile.https.tmpl /etc/caddy/
COPY dovecot/dovecot.conf /etc/dovecot/
COPY dovecot/conf.d/* /etc/dovecot/conf.d/

COPY postfix/main.cf.tmpl /etc/postfix/
COPY postfix/master.cf /etc/postfix/
RUN touch /etc/postfix/vuser /etc/postfix/valias

RUN addgroup -g 2001 mailuser \
    && adduser -G mailuser -u 2001 -D -H mailuser

COPY --chmod=755 scripts/* /

entrypoint /entry.sh
