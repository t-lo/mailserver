#!/bin/bash

set -euo pipefail

shopt -s extglob

echo
echo "##### Mail server system up and running on ${HOSTNAME}."
echo

sleep 2
# Tail all logs (except caddy, too noisy) and handle syslog log rotation
(
    tail -f ${@} &

    while true; do
            inotifywait -e delete -e create -e delete_self -e move_self /host/var/log/syslog.log
            echo "############## Syslog log rotated; restarting tail ##############"
            kill %1
            wait
            touch /host/var/log/syslog.log
            tail -f /host/var/log/[!caddy]*.log &
    done
)
