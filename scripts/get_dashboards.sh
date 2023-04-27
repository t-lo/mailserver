#!/bin/ash
#
# Helper script to fetch Grafana dashboards in a format suitable for bootstrap initialisation.
# Run inside the mailserver container.

# Read-access token to pull dashboard JSON. Get this from Grafana GUI.
grafana_token=""

url="$(eval echo "${GF_SERVER_ROOT_URL}org/apikeys")"
if test -z "${grafana_token}" ; then
    echo "No Grafana access token set. Go to ${url}, generate a key, then edit $0 to set the key."
    exit
fi

function download() {
    local id="$1"
    local dest_file="$2"
    curl --digest -u 'monitoring:v\GEnUV/M5T_$RBwYF%H' \
            -H "Authorization: Bearer $grafana_token" \
            "http://mailserver-monitoring-grafana:3000/api/dashboards/uid/${id}" \
           | jq '.dashboard' > "${dest_file}"
}
# --

download "psfx" "/host/postfix.json"
download "dvct" "/host/dovecot.json"
download "dnsy" "/host/dns-sanity.json"
