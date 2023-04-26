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

# https://en.wikipedia.org/wiki/Sender_Policy_Framework
# example SPF TXT record: "v=spf1 ip4:192.0.2.0/24 ip4:198.51.100.123 a -all"
function check_spf() {
    local domain="$1"
    local my_ipv4="$2"

    local has_mx=false
    local has_a=false
    local ip_match=false

    local entry=""
    for entry in $(host -t txt "${domain}" | grep -w 'v=spf1'); do
        if ! $has_mx && test "$entry" = "mx"; then
            has_mx=true
            continue
        fi

        if ! $has_a && test "$entry" = "a"; then
            has_a=true
            continue
        fi

        if ! echo "${entry}" | grep -qE '^ip4:' ; then
            continue
        fi

        local ip="$(echo "$entry" | sed 's/.*ip4:\([0-9./]*\).*/\1/' )"
        # If ip is not a cidr make it a /32 network so 'prips' can do its job
        if ! echo "$ip" | grep -qE '/[0-9]*$' ; then
            ip="${ip}/32"
        fi
        if /prips "${ip}" | grep -q "${my_ipv4}" ;  then
            ip_match=true
        fi
    done

    $has_mx && $has_a && $ip_match
}
# --

function check_all_domains() {
    local my_ipv4="$1"
    local mx_sane=true
    local spf_sane=false

    echo "++++++ DNS sanity check: checking mail domains settings."
    echo
    for d in "${DOMAIN}" $(echo "${ADDITIONAL_DOMAINS}" | sed 's/,/ /g'); do
        if check_mx "${d}" "${HOSTNAME}"; then
            echo "     ✅ ${d} has MX entry pointing to '${HOSTNAME}'."
        else
            echo "     ❌ ${d}: ERROR: No MX entry pointing to '${HOSTNAME}'."
            mx_sane=false
        fi

        if check_spf "${d}" "${my_ipv4}"; then
            echo "     ✅ ${d} has valid SPF entry pointing to '${my_ipv4}'."
        else
            echo "     ❌ ${d}: ERROR: No valid SPF entry pointing to '${my_ipv4}'."
            spf_sane=false
        fi
    done

    if ! $mx_sane ; then
        echo
        echo "       -------------- DNS MX entry test failed ----------"
        echo "       One or more domain MX sanity checks failed."
        echo "       Please make sure ALL domains served have an MX record for '${HOSTNAME}'."
        echo "       Currently '${HOSTNAME}' does not \"officially\" handle mail for the domains listed above."
        echo "       As a result, remote mail servery may reject emails of these domains' users."
        echo
        echo "       To mitigate please add a MX record to the domains above which points to server '${HOSTNAME}'."
        echo "       --------------------------------------------------"
    fi

    if ! $spf_sane ; then
        echo
        echo "       ------------ DNS SPF entry test failed ----------"
        echo "       One or more domain SPF sanity checks failed."
        echo "       Please make sure ALL domains served have a TXT SPF record with MX '${my_ipv4}'."
        echo "       As a result, remote mail servery may reject emails of these domains' users."
        echo
        echo "       To mitigate please add a TXT SPF record like e.g."
        echo "         'v=spf1 a mx ip4:${my_ipv4} -all'"
        echo "       to the domains that failed the check. Refer to"
        echo "         https://en.wikipedia.org/wiki/Sender_Policy_Framework"
        echo "       for more information."
        echo "       --------------------------------------------------"
    fi
}
# --

# TODO: this currently only checks IPv4
function check_server_a_ptr_records() {
    local my_ipv4="$1"
    local succ=true

    echo "++++++ DNS sanity check: checking mail server's PTR / A settings."

    local host_a="$(host -t a "${HOSTNAME}" | awk '{print $NF}')"
    if [ "${my_ipv4}" = "${host_a}" ] ; then
        echo "     ✅ DNS record for '${HOSTNAME}' points to our public ip '${my_ipv4}'."
    else
        echo
        echo "     ❌ ERROR: A record of '${HOSTNAME}' points to the wrong IP!"
        echo "               This host has public IP '${my_ipv4}' but A record of"
        echo "               '${HOSTNAME}' points to '${host_a}'."
        echo
        echo "        To mitigate please create an A record for '${HOSTNAME}' that points to"
        echo "         '${my_ipv4}'."
    fi

    local host_ptr="$(host -t ptr "${my_ipv4}" | awk '{print $NF}')"
    if [ "${HOSTNAME}." = "${host_ptr}" ] ; then
        echo "     ✅ Reverse DNS PTR for IP '${my_ipv4}' points to '${HOSTNAME}'."
    else
        echo
        echo "     ❌ ERROR: PTR record of server public ip '${my_ipv4}' points to the wrong host name!"
        echo "               The PTR record points to '${host_ptr}' but the server host name is"
        echo "               '${HOSTNAME}'."
        echo
        echo "        To mitigate please create a PTR record for '${my_ipv4}' to '${HOSTNAME}'."
    fi
}


my_ipv4="$(curl -s http://ip6.me/api/ | grep -E '^IPv4,' | awk -F, '{print $2}')"

if [ -z "${my_ipv4}" ] ; then
    echo "  ERROR: Unable to determine server's public IP."
    exit
fi

check_server_a_ptr_records "${my_ipv4}"
echo
check_all_domains "${my_ipv4}"

