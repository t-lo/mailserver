#!/bin/sh

docker run --rm -ti --entrypoint /dns_sanity.sh \
           --env-file settings.env \
           --name mailserver-sanitycheck \
           ghcr.io/t-lo/mailserver
