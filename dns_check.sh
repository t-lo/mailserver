#!/bin/sh

docker run --rm -ti --entrypoint /dns_sanity.sh \
           --env-file settings.env \
	   -v $(pwd)/_server_workspace_:/host --env-file settings.env \
           --name mailserver-sanitycheck \
           ghcr.io/t-lo/mailserver
