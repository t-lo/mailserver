#!/bin/sh

http="${1:-80}"
https="${2:-443}"

version=""
if [ -f "VERSION" ] ; then
    version=":$(cat VERSION)"
fi

exec docker run --rm -i \
                --publish 0.0.0.0:$http:80 \
                --publish 0.0.0.0:$https:443 \
                --publish 0.0.0.0:25:25 \
                --publish 0.0.0.0:465:465 \
                --publish 0.0.0.0:143:143 \
                --publish 0.0.0.0:993:993 \
                --publish 0.0.0.0:4190:4190 \
                -v $(pwd)/_server_workspace_:/host --env-file settings.env \
	        --network mailserver-network \
                --cap-add CAP_DAC_READ_SEARCH \
                --cap-add CAP_NET_ADMIN \
                --cap-add CAP_NET_RAW \
                --name mailserver \
                      "ghcr.io/t-lo/mailserver${version}"
