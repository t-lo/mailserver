#!/bin/sh

set -euo pipefail

function wait_for_network() {
    local network="$1"
    echo -n "Waiting for '${network}' to come up ..."
    while ! docker network ls -f "name=^${network}$" | grep -qw "${network}" ; do
        echo -n "."
        sleep 1
    done
    echo "up."
}
# --

wait_for_network "$1"
