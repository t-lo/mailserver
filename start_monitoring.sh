#!/bin/sh

cd "$(dirname "$0")"

# Create internal network and connect to mailserver container
docker network rm mailserver-monitoring-internal || true
docker network create --internal --subnet 10.0.0.0/24 mailserver-monitoring-internal
docker network connect mailserver-monitoring-internal mailserver

trap 'docker network disconnect mailserver-monitoring-internal mailserver; docker network rm mailserver-monitoring-internal' EXIT

# Make prometheus DB bind-mount directory write-able for in-container Prometheus user id
mkdir -p $(pwd)/_server_workspace_/prometheus-data
chown -R 65534:root $(pwd)/_server_workspace_/prometheus-data

# Start prometheus and pushgateway containers in the background
docker run --rm --network mailserver-monitoring-internal \
           -v $(pwd)/prometheus/prometheus.yaml:/prometheus.yaml \
           -v $(pwd)/_server_workspace_/prometheus-data:/prometheus-data \
           --name mailserver-prometheus\
           prom/prometheus:latest \
                --config.file=/prometheus.yaml \
                --storage.tsdb.path=/prometheus-data \
                --storage.tsdb.retention.time=6m \
                --web.enable-lifecycle 2>&1 | sed 's/^/PROMETHEUS: /' &

docker run --rm --network mailserver-monitoring-internal \
           -v $(pwd)/_server_workspace_/prometheus-pushgateway/:/persist \
           --name mailserver-prometheus-pushgateway \
           prom/pushgateway:latest \
                --persistence.file=/persist/data.dat 2>&1 | sed 's/^/PUSHGW: /' &

docker run --rm --network mailserver-monitoring-internal \
            --env-file settings.env \
            -v $(pwd)/grafana/dashboards:/etc/grafana/provisioning/dashboards \
            -v $(pwd)/grafana/datasources:/etc/grafana/provisioning/datasources \
            --name mailserver-monitoring-grafana \
            grafana/grafana:latest 2>&1 | sed 's/^/GRAFANA: /'

wait
