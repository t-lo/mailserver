# First, build the metrics exporter and the "prips" (print ip ranges) tool.
FROM alpine:latest AS builder
ARG postfix_exporter_version=0.3.0
ARG fail2ban_exporter_version=0.10.1
ARG prips_version=1.2.0

RUN apk update \
    && apk add go gcc make musl-dev

RUN echo "Downloading and building Postfix exporter version '$postfix_exporter_version'" \
    && wget "https://github.com/kumina/postfix_exporter/archive/refs/tags/$postfix_exporter_version.tar.gz" \
    && tar -xzvf "$postfix_exporter_version.tar.gz"

RUN cd "/postfix_exporter-$postfix_exporter_version" \
    && go get -d ./... \
    && go build -a -tags nosystemd \
    && strip postfix_exporter \
    && mv postfix_exporter /

RUN echo "Downloading and building fail2ban exporter version '$fail2ban_exporter_version'" \
    && wget "https://gitlab.com/hectorjsmith/fail2ban-prometheus-exporter/-/archive/v${fail2ban_exporter_version}/fail2ban-prometheus-exporter-v${fail2ban_exporter_version}.tar.gz" \
    && tar -xzvf "fail2ban-prometheus-exporter-v${fail2ban_exporter_version}.tar.gz"

RUN cd "/fail2ban-prometheus-exporter-v${fail2ban_exporter_version}" \
    && go mod download \
    && go build \
    && strip fail2ban-prometheus-exporter \
    && mv fail2ban-prometheus-exporter /

RUN echo "Downloading and building prips version '$prips_version'" \
    && wget "https://devel.ringlet.net/files/sys/prips/prips-$prips_version.tar.gz" \
    && tar -xzvf "prips-$prips_version.tar.gz"

RUN cd "/prips-$prips_version" \
    && make \
    && strip prips \
    && mv prips /


FROM alpine:latest

COPY --from=builder /postfix_exporter /fail2ban-prometheus-exporter /prips /
RUN apk update \
    && apk upgrade \
    && apk add postfix postfix-pcre certbot opendkim opendkim-utils opendmarc caddy \
               ca-certificates-bundle dovecot dovecot-pigeonhole-plugin \
               dovecot-lmtpd gettext openssl fail2ban pwgen bind-tools \
               curl jq inotify-tools supervisor bash

COPY caddy/ /etc/caddy/
COPY fail2ban/ /etc/fail2ban/
COPY dovecot/ /etc/dovecot/
COPY opendkim/ /etc/opendkim/
COPY opendmarc/ /etc/opendmarc/
COPY postfix/ /etc/postfix/
COPY supervisor/ /etc/supervisor/
RUN touch /etc/postfix/vuser /etc/postfix/valias

RUN addgroup -g 2001 mailuser \
    && adduser -G mailuser -u 2001 -D -H mailuser

COPY scripts/ /
RUN chmod 755 /*.sh

# Hack alert: Alpine 3.17 still uses legacy IPTables (though it also ships nftables).
# So we make the nftables multi-binary pretend it's the legacy one (so all the softlinks remain functional).
# IPTables is used by Fail2Ban.
RUN mv /sbin/xtables-legacy-multi /sbin/xtables-legacy-multi.orig \
    && ln -s /sbin/xtables-nft-multi /sbin/xtables-legacy-multi

entrypoint /entry.sh
