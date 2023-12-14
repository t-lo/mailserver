#!/bin/sh

http="${1:-80}"
https="${2:-443}"

version=""
if [ -f "VERSION" ] ; then
    version=":$(cat VERSION)"
fi

exec docker run --rm -i -p $http:80 -p $https:443 \
               -p 25:25 -p 465:465 \
               -p 143:143 -p 993:993 \
               -p 4190:4190 \
               -v $(pwd)/_server_workspace_:/host --env-file settings.env \
	       --network mailserver-network \
               --cap-add CAP_DAC_READ_SEARCH \
               --cap-add CAP_NET_ADMIN \
               --cap-add CAP_NET_RAW \
               --name mailserver \
                      "ghcr.io/t-lo/mailserver${version}"
