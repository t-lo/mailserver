#!/bin/sh

# Make prometheus DB bind-mount directory write-able for in-container Prometheus user id
mkdir -p $(pwd)/_server_workspace_/prometheus-pushgateway
chown -R 65534:root $(pwd)/_server_workspace_/prometheus-pushgateway

exec docker run --rm --network mailserver-monitoring-internal \
           --pull always \
           -v $(pwd)/_server_workspace_/prometheus-pushgateway/:/persist \
           --name mailserver-prometheus-pushgateway \
           prom/pushgateway:latest \
                --persistence.file=/persist/data.dat
