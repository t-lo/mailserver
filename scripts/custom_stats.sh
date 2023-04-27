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

echo "Starting custom stats exporter."

while true; do

    t1="$(date +%s)"

    emit_mailbox_sizes | ${curl_pgw}
    /dns_sanity.sh prometheus | ${curl_pgw}

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

