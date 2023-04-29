#!/bin/sh

cd "$(dirname "$0")"

http="${1:-80}"
https="${2:-443}"

# We use Strato's DNS server by default because some default DNS servers
#   fragment responses, which breaks opendkim.
exec docker run --rm  -p $http:80 -p $https:443 \
                         --dns  85.215.235.63  \
                         -p 25:25 -p 465:465 \
                         -p 143:143 -p 993:993 \
                         -v $(pwd)/_server_workspace_:/host --env-file settings.env \
			 --cap-add CAP_AUDIT_READ \
			 --cap-add CAP_DAC_READ_SEARCH \
			 --cap-add CAP_NET_ADMIN \
			 --cap-add CAP_NET_RAW \
                         --name mailserver \
                         ghcr.io/t-lo/mailserver
