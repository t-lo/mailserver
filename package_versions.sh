#!/bin/bash
#
# List versions of relevant packages in mailserver container.
#

set -euo pipefail

container="${1:-ghcr.io/t-lo/mailserver:latest}"
packages_file="${2:-release_package_versions.list}"

while read -u 9 line; do
    name="${line%,*}"
    cmd="${line#*,}"
    echo -n "* ${name}: "
    docker run --entrypoint /bin/bash --rm -i "${container}" -l -c "${cmd}"
done 9<"${packages_file}"

echo -n "* Postfix prometheus exporter: "
sed -n 's/.*postfix_exporter_version=//p' Dockerfile

echo -n "* Fail2Ban prometheus exporter: "
sed -n 's/.*fail2ban_exporter_version=//p' Dockerfile
