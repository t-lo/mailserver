#!/bin/sh

#  Grafana user id 472
mkdir -p _server_workspace_/var/log/grafana/ _server_workspace_/var/lib/grafana/
chown -R 472:root _server_workspace_/var/log/grafana/ _server_workspace_/var/lib/grafana/

exec docker run --rm -i --network mailserver-monitoring-internal \
           --pull always \
            --env-file settings.env \
            --env GF_LOG_MODE="console file" \
            -v $(pwd)/grafana/dashboards:/etc/grafana/provisioning/dashboards \
            -v $(pwd)/grafana/datasources:/etc/grafana/provisioning/datasources \
            -v $(pwd)/_server_workspace_/var/log/grafana:/var/log/grafana \
            -v $(pwd)/_server_workspace_/var/lib/grafana:/var/lib/grafana \
            --name mailserver-monitoring-grafana \
            grafana/grafana:latest
