#!/bin/sh

script_dir="$(cd $(dirname "$0"); pwd)"

function mailcontainer_id() {
    docker ps --filter "volume=/host" \
        | while read id name rest; do
            if [ "$id" = "CONTAINER" ]; then
                continue
            fi
            if docker inspect -f '{{ .Mounts }}' "$id" | grep -q "$(pwd)" ; then
                echo "$id"; break;
            fi;
    done
}


container="$(mailcontainer_id)"

docker exec -ti "${container}" /add_user.sh "${@}"
