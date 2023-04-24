#!/bin/ash
#
# Validate mail server DNS settings.
#

function check_mx() {
    local domain="$1"
    local mailserver="$2"

    local ret=false

    local mx=""
    for mx in $(host -t mx "${domain}" | awk "/^${domain} mail is handled by/ {print \$NF}"); do
        if [ "${mx}" = "${mailserver}." ] ; then
            ret=true
            break
        fi
    done

    $ret
}
# --

function check_all_domains_mx() {
    local succ=true

    echo "++++++ DNS sanity check: checking mail domains' MX settings."
    echo
    for d in "${DOMAIN}" $(echo "${ADDITIONAL_DOMAINS}" | sed 's/,/ /g'); do
        if ! check_mx "${d}" "${HOSTNAME}"; then
            echo "    !!! ${d}: ERROR: No MX entry pointing to '${HOSTNAME}'."
            succ=false
        fi
    done

    if ! $succ ; then
        echo
        echo "       --------------------------------------------------"
        echo "       One or more domain MX sanity checks failed."
        echo "       Please make sure ALL domains served have an MX record for '${HOSTNAME}'."
        echo "       Currently '${HOSTNAME}' does not \"officially\" handle mail for the domains listed above."
        echo "       As a result, remote mail servery may reject emails of these domains' users."
        echo
        echo "       To mitigate please add a MX record to the domains above which points to server '${HOSTNAME}'."
        echo "       --------------------------------------------------"
    fi
}
# --

# TODO: this currently only checks IPv4
function check_server_a_ptr_records() {
    local succ=true

    echo "++++++ DNS sanity check: checking mail server's PTR / A settings."

    local my_ipv4="$(curl -s http://ip6.me/api/ | grep -E '^IPv4,' | awk -F, '{print $2}')"

    if [ -z "${my_ipv4}" ] ; then
        echo "        WARNING: Skipping mail server A / PTR record check as I am unable to determine my public IP"
        return
    fi

    local host_a="$(host -t a "${HOSTNAME}" | awk '{print $NF}')"
    if [ "${my_ipv4}" != "${host_a}" ] ; then
        echo
        echo "    !!! ERROR: A record of '${HOSTNAME}' points to the wrong IP!"
        echo "               This host has public IP '${my_ipv4}' but A record of"
        echo "               '${HOSTNAME}' points to '${host_a}'."
        echo
        echo "        To mitigate please create an A record for '${HOSTNAME}' that points to"
        echo "         '${my_ipv4}'."
        succ=false
    fi

    local host_ptr="$(host -t ptr "${my_ipv4}" | awk '{print $NF}')"
    if [ "${HOSTNAME}" != "${host_ptr}" ] ; then
        echo
        echo "    !!! ERROR: PTR record of server public ip '${my_ipv4}' points to the wrong host name!"
        echo "               The PTR record points to '${host_ptr}' but the server host name is"
        echo "               '${HOSTNAME}'."
        echo
        echo "        To mitigate please create a PTR record for '${my_ipv4}' to '${HOSTNAME}'."
        succ=false
    fi

    if $succ; then
        echo "       OK."
    fi
}


check_server_a_ptr_records
echo
check_all_domains_mx

