#!/bin/bash

set -euo pipefail

function wait_for_container() {
    local container="$1"
    echo -n "Waiting for '$container' container to come up ..."
    while ! docker ps -f "name=^${container}$" | grep -qw "${container}" ; do
        echo -n "."
        sleep 1
    done
    echo "up."
}

wait_for_container "$1"
