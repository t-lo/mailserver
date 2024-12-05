#!/bin/bash

SNAPPY_VERSION=v2.38.2

exec docker run --rm -i \
	--env-file settings.env \
	-v $(pwd)/_server_workspace_/snappymail:/var/lib/snappymail \
	-v $(pwd)/contrib/snappymail/:/setup \
	--entrypoint /setup/setup_snappymail.sh \
	--name mailserver-webmail \
	--network mailserver-network \
	djmaze/snappymail:${SNAPPY_VERSION}
