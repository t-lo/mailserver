#!/bin/sh

cd "$(dirname "$0")"

mailserver_container="mailserver"

echo -n "Waiting for '$mailserver_container' container to come up ..."
while ! docker ps -f "name=^${mailserver_container}$" | grep -qw "${mailserver_container}" ; do
    echo -n "."
    sleep 1
done

# Create internal network and connect to mailserver container
docker network rm mailserver-monitoring-internal >/dev/null 2>&1 || true
docker network create --internal --subnet 10.0.0.0/24 mailserver-monitoring-internal
docker network connect mailserver-monitoring-internal mailserver

trap 'docker network disconnect mailserver-monitoring-internal mailserver; docker network rm mailserver-monitoring-internal' EXIT

# Make prometheus DB bind-mount directory write-able for in-container Prometheus user id
mkdir -p $(pwd)/_server_workspace_/prometheus-data \
         $(pwd)/_server_workspace_/prometheus-pushgateway
chown -R 65534:root $(pwd)/_server_workspace_/prometheus-data \
                    $(pwd)/_server_workspace_/prometheus-pushgateway

#  Grafana user id 472
mkdir -p _server_workspace_/var/log/grafana/
chown -R 472:root _server_workspace_/var/log/grafana/

# Start prometheus and pushgateway containers in the background
docker run --rm --network mailserver-monitoring-internal \
           -v $(pwd)/prometheus/prometheus.yaml:/prometheus.yaml \
           -v $(pwd)/_server_workspace_/prometheus-data:/prometheus-data \
           --name mailserver-prometheus \
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

docker run --rm -i --network mailserver-monitoring-internal \
            --env-file settings.env \
	    --env GF_LOG_MODE="console file" \
            -v $(pwd)/grafana/dashboards:/etc/grafana/provisioning/dashboards \
            -v $(pwd)/grafana/datasources:/etc/grafana/provisioning/datasources \
            -v $(pwd)/_server_workspace_/var/log/grafana:/var/log/grafana \
            --name mailserver-monitoring-grafana \
            grafana/grafana:latest 2>&1 | sed 's/^/GRAFANA: /'

wait
