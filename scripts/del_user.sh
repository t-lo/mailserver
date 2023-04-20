#!/bin/ash

set -euo pipefail

purge_inbox=false
user=""

while test $# -gt 0; do
    case "$1" in
        --purge-inbox) purge_inbox=true; shift ;;
        *) user="$1"; shift;;
    esac
done

if test -z "${user}" ; then
    echo "Usage: $0 [--purge-inbox] <user@domain>"
    echo
    echo "       <user@domain> - user at domain to be removed. Mandatory."
    echo "       --purge-inbox - Delete the user's inbox (all their emails)."
    exit
fi

sed -i "/^${user}:/d" /etc/dovecot/passwd
sed -i "/^${user} /d" /etc/postfix/vuser

echo -n "Deleted '${user}'"

if $purge_inbox ;  then
    domain="$(echo "${user}" | sed 's/.*@//g')"
    rm -rf "/host/mail/inboxes/${domain}/${user}"
    echo " and purged mail/inboxes/${domain}/${user}."
else
    echo "."
fi

/update_aliases.sh
