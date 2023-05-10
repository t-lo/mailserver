#!/bin/sh

cd "$(dirname "$0")"

mailserver_container="mailserver"

touch _server_workspace_/mailman/core/var/data/postfix_domains
touch _server_workspace_/mailman/core/var/data/postfix_lmtp
touch _server_workspace_/mailman/core/var/data/postfix_vmap

chown -R 100:65533 _server_workspace_/mailman/core/var/data/

echo -n "Waiting for '$mailserver_container' container to come up ..."
while ! docker ps -f "name=^${mailserver_container}$" | grep -qw "${mailserver_container}" ; do
    echo -n "."
    sleep 1
done

docker-compose -f mailman.yaml up
