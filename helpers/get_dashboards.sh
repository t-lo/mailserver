#!/bin/ash
#
# Helper script to fetch Grafana dashboards in a format suitable for bootstrap initialisation.
# Run inside the mailserver container.

# Read-access token to pull dashboard JSON. Get this from Grafana GUI.
grafana_token=""

function download() {
    local id="$1"
    local dest_file="$2"
    curl --digest -u 'monitoring:v\GEnUV/M5T_$RBwYF%H' \
            -H "Authorization: Bearer $grafana_token" \
            "http://mailserver-monitoring-grafana:3000/api/dashboards/uid/${id}" \
           | jq '.dashboard' > "${dest_file}"
}
# --

download "psfx" "postfix.json"
download "dvct" "dovecot.json"
