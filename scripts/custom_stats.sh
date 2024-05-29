#!/bin/ash
#
# Publish custom metrics to the pushgateway.
# (currently mailbox sizes)

push_interval_s=5

curl_pgw="curl -s --data-binary @- http://mailserver-prometheus-pushgateway:9091/metrics/job/custom_script"

# Inbox sizes per user, domain, and on overall
function emit_mailbox_sizes() {
    echo "#TYPE email_inbox_size gauge"
    du -d 2 -b /host/mail/inboxes/ \
         | awk -F/ '{ if ($6 == "")
                          $6="__total__";
                      print $1 " " $5 " " $6  }' \
         | while read size domain email; do
             echo "email_inbox_size{domain=\"$domain\",user=\"$email\"} $size"
         done
}
# --

function emit_postmaster_unread_emails() {
    local unread="$(ls /host/mail/inboxes/${DOMAIN}/${ADMIN_USER}@${DOMAIN}/Maildir/new/ 2>/dev/null | wc -l)"
    echo "#TYPE postmaster_unread_emails gauge"
    echo "postmaster_unread_emails{user=\"${ADMIN_USER}@${DOMAIN}\"} ${unread}"
}
# --

function emit_memory_usage() {

    free | awk '
        /^Mem:/{
            print "#TYPE system_memory_total gauge";
            print "system_memory_total " $2;
            print "#TYPE system_memory_used gauge";
            print "system_memory_used " $3;
            print "#TYPE system_memory_free gauge";
            print "system_memory_free " $4;
            print "#TYPE system_memory_shared gauge";
            print "system_memory_shared " $5;
            print "#TYPE system_memory_buffers_cached gauge";
            print "system_memory_buffers_cached " $6;
            print "#TYPE system_memory_available gauge";
            print "system_memory_available " $7; }
        /^Swap:/{
            print "#TYPE system_swap_total gauge";
            print "system_swap_total " $2;
            print "#TYPE system_swap_used gauge";
            print "system_swap_used " $3;
            print "#TYPE system_swap_free gauge";
            print "system_swap_free " $4; }'
}
# --

function emit_storage_usage() {

    df | awk '
        / \/host$/{
            print "#TYPE system_storage_total gauge";
            print "system_storage_total " $2;
            print "#TYPE system_storage_used gauge";
            print "system_storage_used " $3;
            print "#TYPE system_storage_available gauge";
            print "system_storage_available " $4; }'
}
# --

function emit_cpu_procs_stats() {

    cat /proc/loadavg | awk '
        {
            print "#TYPE system_loadavg_1m gauge\nsystem_loadavg_1m " $1;
            print "#TYPE system_loadavg_5m gauge\nsystem_loadavg_5m " $2;
            print "#TYPE system_loadavg_15m gauge\nsystem_loadavg_15m " $3;
            split($4,procs,"/");
            print "#TYPE system_running_procs gauge\nsystem_running_procs " procs[1];
            print "#TYPE system_num_procs gauge\nsystem_num_procs " procs[2]; }'
    echo "#TYPE system_num_cores gauge"
    echo -n "system_num_cores "
    grep -cE '^processor[[:space:]]*:' /proc/cpuinfo
}
# --

function emit_cert_end_dates() {
    for cert in /etc/letsencrypt/live/*/cert.pem; do
        local exp="$(openssl x509 -enddate -noout -in  "$cert" \
                     | sed -e 's/.*=//' -e 's/ GMT//' )"
        local exp_sec="$(date --date "${exp}" '+%s')"
        local exp_sec_left="$(( ${exp_sec} - $(date '+%s')))"
        local domain="$(basename "$(dirname "$cert")")"
        echo "#TYPE ssl_certificate_expiration_date_seconds gauge"
        echo "ssl_certificate_expiration_date_seconds{domain=\"${domain}\"} ${exp_sec}"
        echo "#TYPE ssl_certificate_expiration_seconds_validity_left gauge"
        echo "ssl_certificate_expiration_seconds_validity_left{domain=\"${domain}\"} ${exp_sec_left}"
    done
}
#--

echo "Starting custom stats exporter."

mkdir -p "/host/var/run"
dns_statefile="/host/var/run/dns_prometheus_state.txt"
rm -f "${dns_statefile}"
touch "${dns_statefile}"

while true; do

    t1="$(date +%s)"

    emit_cpu_procs_stats | ${curl_pgw}
    emit_mailbox_sizes | ${curl_pgw}
    emit_postmaster_unread_emails | ${curl_pgw}
    emit_memory_usage | ${curl_pgw}
    emit_storage_usage | ${curl_pgw}
    emit_cert_end_dates | ${curl_pgw}

    # DNS settings are less dynamic than the above stats, so we only
    # push if something changed.
    /dns_sanity.sh prometheus > "${dns_statefile}.new"

    orig="$(sha1sum "${dns_statefile}" | awk '{print $1}')"
    new="$(sha1sum "${dns_statefile}.new" | awk '{print $1}')"
    if [ "${orig}" != "${new}" ] ; then
        echo "Custom metrics: DNS information changed; pushing update"
        mv "${dns_statefile}.new" "${dns_statefile}"
        cat "${dns_statefile}" | ${curl_pgw}
    fi

    t2="$(date +%s)"

    if test -f /.stop_custom_stats ; then
        break
    fi

    sleep_time="$((push_interval_s - (t2-t1) ))"
    if test "$sleep_time" -gt 0; then
        sleep $sleep_time
    fi
done

echo "Stopping custom stats exporter."

