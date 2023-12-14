#!/bin/sh

# Make prometheus DB bind-mount directory write-able for in-container Prometheus user id
mkdir -p $(pwd)/_server_workspace_/prometheus-data
chown -R 65534:root $(pwd)/_server_workspace_/prometheus-data

# Start prometheus and pushgateway containers in the background
exec docker run --rm --network mailserver-monitoring-internal \
           --pull always \
           -v $(pwd)/prometheus/prometheus.yaml:/prometheus.yaml \
           -v $(pwd)/_server_workspace_/prometheus-data:/prometheus-data \
           --name mailserver-prometheus \
           prom/prometheus:latest \
                --config.file=/prometheus.yaml \
                --storage.tsdb.path=/prometheus-data \
                --storage.tsdb.retention.time=200d \
                --web.enable-lifecycle
