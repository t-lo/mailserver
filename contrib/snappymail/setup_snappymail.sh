#!/bin/bash

script_path=$(basename "$0")

snappymail_datadir="/var/lib/snappymail/_data_/_default_"

function check_init_first_run() {
    if [[ -d  $snappymail_datadir ]] ; then
        echo "[SETUP] Directory '$snappymail_datadir' exists, skipping first start set-up."
        return
    fi

    echo "[SETUP] FIRST RUN detected, initialising Snappymail."
    echo "[SETUP] --------------------------------------------"
    echo "[SETUP] Starting snappymail first-time init"

    apk add envsubst

    /entrypoint.sh &

    # Wait for snappymail to create admin password; this is the last step
    #  of initialisation, so we're good to go after that.
    while [[ ! -f $snappymail_datadir/admin_password.txt ]]; do
        sleep 0.1
    done

    kill -TERM %1
    wait

    echo "[SETUP] patching application path"
    sed -i 's:^app_path = .*:app_path = "/webmail":' \
       "${snappymail_datadir}/configs/application.ini"

    echo "[SETUP] removing snappymail auto-generated localhost domains"
    rm -f "${snappymail_datadir}/domains/"*.json

    echo "[SETUP] updating domain ${DOMAIN}"
    envsubst <"/setup/domain.json.tmpl" \
        > ${snappymail_datadir}/domains/${DOMAIN}.json

    echo "[SETUP] Creating aliases for ${ADDITIONAL_DOMAINS}"
    for alias in ${ADDITIONAL_DOMAINS//,/ }; do
        echo "${DOMAIN}" > "${snappymail_datadir}/domains/${alias}.alias"
        echo "[SETUP]   - ${alias}.alias"
    done
}
# --

check_init_first_run

echo "[SETUP] All done, starting Snappymail"
exec /entrypoint.sh
