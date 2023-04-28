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

# https://en.wikipedia.org/wiki/DomainKeys_Identified_Mail
function check_dkim() {
    local domain="$1"
    local selector="$2"

    opendkim-testkey -vvvv -d "${domain}" -s "${selector}" 2>&1 | grep -q 'key OK'
}
# --

# https://en.wikipedia.org/wiki/DMARC"
function check_dmarc() {
    local domain="$1"

    # required by DMARC
    local p=false
    # optional but will increase chances of mails being accepted by other servers
    local sp=false
    local fo=false
    local rua=false
    local ruf=false

    local entry=""
    for entry in $(host -t txt "_dmarc.${domain}" \
                     | grep -E 'v=DMARC1 *' \
                     | sed -e 's/[^"]*"\(.*\)"/\1/' -e 's/;/ /g'); do
        local k="$(echo "$entry" | sed 's/=.*//')"
        local v="$(echo "$entry" | sed 's/.*=//')"

        case "$k" in
            p)  if test "$v" = "quarantine" -o "$v" = "reject"; then
                   p=true
                fi ;;
            sp) if test "$v" = "quarantine" -o "$v" = "reject"; then
                   sp=true
                fi ;;
            fo)  fo=true ;;
            rua) rua=true ;;
            ruf) ruf=true ;;
        esac
    done

    $p && $sp && $fo && $rua && $ruf
}
# --

function check_all_domains() {
    local my_ipv4="$1"
    local prometheus_mode="$2"
    local mx_sane=true
    local spf_sane=true
    local dkim_sane=true
    local dmarc_sane=true

    if $prometheus_mode ;  then

        echo "# HELP dns_sanity_domain_mx_record Does domain have a valid MX record pointing to mail server - 0: no, 1: yes "
        echo "# TYPE dns_sanity_domain_mx_record gauge"
        echo "# HELP dns_sanity_domain_spf_record Does domain have a valid SPF record pointing to mail server's IP - 0: no, 1: yes "
        echo "# TYPE dns_sanity_domain_spf_record gauge"
        echo "# HELP dns_sanity_domain_dkim_record Does domain have a valid DKIM record: no, 1: yes "
        echo "# TYPE dns_sanity_domain_dkim_record gauge"
        echo "# HELP dns_sanity_domain_dmarc_record Does domain have a valid DKIM record: no, 1: yes "
        echo "# TYPE dns_sanity_domain_dmarc_record gauge"
    else
        echo "++++++ DNS sanity check: checking mail domains settings."
        echo
    fi

    function check_and_report() {
        local prometheus_mode="$1"   ; shift
        local prometheus_metric="$1" ; shift
        local success_message="$1"   ; shift
        local fail_message="$1"      ; shift

        if $@ ; then if $prometheus_mode; then
                echo "$prometheus_metric" 1 ; else
                echo "$success_message"; fi
		return 0
        else if $prometheus_mode; then
                echo "$prometheus_metric" 0; else
                echo "$fail_message"; fi
		return 1
        fi
    }

    for d in "${DOMAIN}" $(echo "${ADDITIONAL_DOMAINS}" | sed 's/,/ /g'); do
        if ! check_and_report $prometheus_mode \
                "dns_sanity_domain_mx_record{domain=\"${d}\"}" \
                "     ✅ ${d} has MX entry pointing to '${HOSTNAME}'." \
                "     ❌ ${d}: ERROR: No MX entry pointing to '${HOSTNAME}'." \
                check_mx "${d}" "${HOSTNAME}" ; then
            mx_sane=false
        fi

        if ! check_and_report $prometheus_mode \
                 "dns_sanity_domain_spf_record{domain=\"${d}\"}" \
                 "     ✅ ${d} has valid SPF entry pointing to '${my_ipv4}'." \
                 "     ❌ ${d}: ERROR: No valid SPF entry pointing to '${my_ipv4}'." \
                 check_spf "${d}" "${my_ipv4}"; then
            spf_sane=false
        fi

        if ! check_and_report $prometheus_mode \
                 "dns_sanity_domain_dkim_record{domain=\"${d}\"}" \
                 "     ✅ ${d} has valid DKIM entry." \
                 "     ❌ ${d}: ERROR: No valid DKIM entry." \
                 check_dkim "${d}" "${DKIM_KEY_SELECTOR}"; then
            dkim_sane=false
        fi

        if ! check_and_report $prometheus_mode \
                 "dns_sanity_domain_dmarc_record{domain=\"${d}\"}" \
                 "     ✅ ${d} has valid DMARC entry." \
                 "     ❌ ${d}: ERROR: No valid DMARC entry." \
                 check_dmarc "${d}"; then
            dmarc_sane=false
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
        echo "       As a result, remote mail servery may reject emails of these domains' users."
        echo
        echo "       To mitigate please add a TXT SPF record like e.g."
        echo "         'v=spf1 a mx ip4:${my_ipv4} -all'"
        echo "       to the domains that failed the check. Refer to"
        echo "         https://en.wikipedia.org/wiki/Sender_Policy_Framework"
        echo "       for more information."
        echo "       --------------------------------------------------"
    fi

    if ! $dkim_sane ; then
        local dkim_key="$(tr -d '\n' </host/etc/opendkim/keys/${DKIM_KEY_SELECTOR}.txt | sed -e 's/.*(\(.*\)).*/\1/')"
        echo
        echo "       ------------ DKIM entry test failed ----------"
        echo "       One or more domains lack a DKIM record."
        echo "       As a result, remote mail servery may reject emails of these domains' users."
        echo
        echo "       To mitigate please add this TXT DKIM record:"
        echo "         '${dkim_key}'"
        echo "       for host"
        echo "         '${DKIM_KEY_SELECTOR}._domainkey'"
        echo "       to the domains that failed the check. Refer to"
        echo "         https://en.wikipedia.org/wiki/DomainKeys_Identified_Mail"
        echo "       for more information."
        echo "       --------------------------------------------------"
    fi

    if ! $dmarc_sane ; then
        echo
        echo "       ------------ DMARC entry test failed ----------"
        echo "       One or more domains lack a DMARC record."
        echo "       As a result, remote mail servery may reject emails of these domains' users."
        echo
        echo "       To mitigate please add this TXT DMARC record (replace <DOMAIN> with the domain name):"
        echo "         v=DMARC1;p=quarantine;sp=quarantine;pct=100;adkim=r;aspf=r;rua=mailto:abuse@<DOMAIN>;ruf=mailto:abuse@<DOMAIN>;ri=1800;fo=1"
        echo "       for host"
        echo "         '_dmarc'"
        echo "       to the domains that failed the check. Refer to"
        echo "         https://en.wikipedia.org/wiki/DMARC"
        echo "       for more information."
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
if $prometheus_mode; then
    echo "dns_sanity_mailserver_ip{ip=\"${my_ipv4}\"} 1"
    echo "# HELP dns_sanity_example_spf_record Example SPF record for copy+pasting into DNS set-up. Always 1."
    echo "# TYPE dns_sanity_example_spf_record gauge"
    echo "dns_sanity_example_spf_record{spf=\"v=spf1 a mx ip4:${my_ipv4} -all\"} 1"

    echo "# HELP dns_sanity_example_dkim_record Example DKIM record for copy+pasting into DNS set-up. Always 1."
    echo "# TYPE dns_sanity_example_dkim_record gauge"
    dkim_key="$(tr -d '\n' <//host/etc/opendkim/keys/${DKIM_KEY_SELECTOR}.txt | sed -e 's/.*(\(.*\)).*/\1/' -e 's/"/\\\\\\"/g')"

    echo "# HELP dns_sanity_example_dmarc_record Example DMARC record for copy+pasting into DNS set-up. Always 1."
    echo "# TYPE dns_sanity_example_dmarc_record gauge"
    for d in "${DOMAIN}" $(echo "${ADDITIONAL_DOMAINS}" | sed 's/,/ /g'); do
        echo "dns_sanity_example_dmarc_record{domain=\"${d}\",host=\"_dmarc\",dmarc=\"v=DMARC1;p=quarantine;sp=quarantine;pct=100;adkim=r;aspf=r;rua=mailto:abuse@${d};ruf=mailto:abuse@${d};fo=1\"} 1"
        echo "dns_sanity_example_dkim_record{domain=\"${d}\",host=\"${DKIM_KEY_SELECTOR}._domainkey\",dkim=\"${dkim_key}\"} 1"
    done

fi

check_server_a_ptr_records "${my_ipv4}" "${prometheus_mode}"
echo
check_all_domains "${my_ipv4}" "${prometheus_mode}"

