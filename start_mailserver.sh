#!/bin/sh

cd "$(dirname "$0")"

exec docker run --rm -ti -p 11111:80 -p 12345:443 \
                         -p 25:25 -p 465:465 \
                         -p 143:143 -p 993:993 \
                         -v $(pwd)/_server_workspace_:/host --env-file settings.env \
                         --name mailserver \
                         ghcr.io/t-lo/mailserver
