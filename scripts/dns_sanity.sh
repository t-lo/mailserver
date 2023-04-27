#!/bin/ash
#
# Validate mail server DNS settings.
#

set -euo pipefail

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
    local prometheus_mode="$2"
    local mx_sane=true
    local spf_sane=true

    if $prometheus_mode ;  then
        echo "# HELP dns_sanity_domain_mx_record Does domain have a valid MX record pointing to mail server - 0: no, 1: yes "
        echo "# TYPE dns_sanity_domain_mx_record gauge"
        echo "# HELP dns_sanity_domain_spf_record Does domain have a valid SPF record pointing to mail server's IP - 0: no, 1: yes "
        echo "# TYPE dns_sanity_domain_spf_record gauge"
    else
        echo "++++++ DNS sanity check: checking mail domains settings."
        echo
    fi

    for d in "${DOMAIN}" $(echo "${ADDITIONAL_DOMAINS}" | sed 's/,/ /g'); do
        if check_mx "${d}" "${HOSTNAME}"; then
            if $prometheus_mode ;  then
                echo "dns_sanity_domain_mx_record{domain=\"${d}\"} 1"
            else
                echo "     ✅ ${d} has MX entry pointing to '${HOSTNAME}'."
            fi
        else
            if $prometheus_mode ;  then
                echo "dns_sanity_domain_mx_record{domain=\"${d}\"} 0"
            else
                echo "     ❌ ${d}: ERROR: No MX entry pointing to '${HOSTNAME}'."
            fi
            mx_sane=false
        fi

        if check_spf "${d}" "${my_ipv4}"; then
            if $prometheus_mode ;  then
                echo "dns_sanity_domain_spf_record{domain=\"${d}\"} 1"
            else
                echo "     ✅ ${d} has valid SPF entry pointing to '${my_ipv4}'."
            fi
        else
            if $prometheus_mode ;  then
                echo "dns_sanity_domain_spf_record{domain=\"${d}\"} 0"
            else
                echo "     ❌ ${d}: ERROR: No valid SPF entry pointing to '${my_ipv4}'."
            fi
            spf_sane=false
        fi
    done

    if $prometheus_mode; then
        return
    fi

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

function check_server_a_ptr_records() {
    local my_ipv4="$1"
    local prometheus_mode="$2"
    local succ=true

    if $prometheus_mode ;  then
        echo "# HELP dns_sanity_server_a_record Does mail server have a valid A record - 0: no, 1: yes "
        echo "# TYPE dns_sanity_server_a_record gauge"
    else
        echo "++++++ DNS sanity check: checking mail server's PTR / A settings."
    fi

    local host_a="$(host -t a "${HOSTNAME}" | awk '{print $NF}')"
    if [ "${my_ipv4}" = "${host_a}" ] ; then
        if $prometheus_mode ;  then
            echo "dns_sanity_server_a_record{hostname=\"${HOSTNAME}\"} 1"
        else
            echo "     ✅ DNS record for '${HOSTNAME}' points to our public ip '${my_ipv4}'."
        fi
    else
        if $prometheus_mode ;  then
            echo "dns_sanity_server_a_record{hostname=\"${HOSTNAME}\"} 0"
        else
            echo
            echo "     ❌ ERROR: A record of '${HOSTNAME}' points to the wrong IP!"
            echo "               This host has public IP '${my_ipv4}' but A record of"
            echo "               '${HOSTNAME}' points to '${host_a}'."
            echo
            echo "        To mitigate please create an A record for '${HOSTNAME}' that points to"
            echo "         '${my_ipv4}'."
        fi
    fi

    if $prometheus_mode ;  then
        echo "# HELP dns_sanity_server_ptr_record Does mail server IP have a valid PTR record pointing to mail server's hostname - 0: no, 1: yes "
        echo "# TYPE dns_sanity_server_ptr_record gauge"
    fi
    local host_ptr="$(host -t ptr "${my_ipv4}" | awk '{print $NF}')"
    if [ "${HOSTNAME}." = "${host_ptr}" ] ; then
        if $prometheus_mode ;  then
            echo "dns_sanity_server_ptr_record{ip=\"${my_ipv4}\"} 1"
        else
            echo "     ✅ Reverse DNS PTR for IP '${my_ipv4}' points to '${HOSTNAME}'."
        fi
    else
        if $prometheus_mode ;  then
            echo "dns_sanity_server_ptr_record{ip=\"${my_ipv4}\"} 0"
        else
            echo
            echo "     ❌ ERROR: PTR record of server public ip '${my_ipv4}' points to the wrong host name!"
            echo "               The PTR record points to '${host_ptr}' but the server host name is"
            echo "               '${HOSTNAME}'."
            echo
            echo "        To mitigate please create a PTR record for '${my_ipv4}' to '${HOSTNAME}'."
        fi
    fi
}

prometheus_mode=false
if [ "${1:-}" = "prometheus" ] ; then
    # Prom
    prometheus_mode=true
    echo "# HELP dns_sanity_mailserver_ip Public IP address of the mail server (as a label). 0: IP error, 1: IP found "
    echo "# TYPE dns_sanity_mailserver_ip gauge"
fi

# TODO: the script currently only checks IPv4
my_ipv4="$(curl -s http://ip6.me/api/ | grep -E '^IPv4,' | awk -F, '{print $2}')"

if [ -z "${my_ipv4}" ] ; then
    if $prometheus_mode; then
        echo "dns_sanity_mailserver_ip 0"
    else
        echo "  ERROR: Unable to determine server's public IP."
    fi
    exit
fi
echo "dns_sanity_mailserver_ip{ip=\"${my_ipv4}\"} 1"

check_server_a_ptr_records "${my_ipv4}" "${prometheus_mode}"
echo
check_all_domains "${my_ipv4}" "${prometheus_mode}"

