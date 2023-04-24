#!/bin/sh

cd "$(dirname "$0")"

# Create internal network and connect to mailserver container
docker network rm mailserver-monitoring-internal || true
docker network create --internal --subnet 10.0.0.0/24 mailserver-monitoring-internal
docker network connect mailserver-monitoring-internal mailserver

trap 'docker network disconnect mailserver-monitoring-internal mailserver; docker network rm mailserver-monitoring-internal' EXIT

# Start prometheus and Grafana container in the background
docker run --rm --network mailserver-monitoring-internal \
           -v $(pwd)/prometheus/prometheus.yaml:/prometheus.yaml \
           --name mailserver-prometheus\
           prom/prometheus:latest \
                --config.file=/prometheus.yaml \
                --web.enable-lifecycle 2>&1 | sed 's/^/PROMETHEUS: /' &

docker run --rm --network mailserver-monitoring-internal \
            --env-file settings.env \
            --name mailserver-monitoring-grafana \
            grafana/grafana:latest 2>&1 | sed 's/^/GRAFANA: /'

wait
