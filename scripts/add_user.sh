#!/bin/ash

set -euo pipefail

if test $# -lt 1 ; then
    echo "Usage: $0 <user@domain> [<password>]"
    echo
    echo "       <user@domain> - user for domain to be added. Mandatory."
    echo "                       <domain> must be one of the domains served:"
    echo "                       either the main ${DOMAIN}, or one of the virtual"
    echo "                       domains ('${ADDITIONAL_DOMAINS}') (if set)."
    echo "       <password>    - user's SMTP / IMAP password. Optional."
    echo "                       Will be generated and printed if not provided."
    exit
fi

user="$1"
pass="${2:-}"

print_pass=false
if test -z "${pass}" ; then
   pass="$(pwgen -ys 20 1)"
   print_pass=true
fi

pass_sha="$(doveadm pw -p "${pass}" -u "${user}" -s SSHA256)"
echo "${user}:${pass_sha}:2001:2001:/host/mail/inboxes/${user}::" >> /etc/dovecot/passwd
echo "${user} ${HOSTNAME}/user/Maildir/" >> /etc/postfix/vuser

/update_aliases.sh

echo -n "Created user '${user}'"
if $print_pass ; then
    echo ", generated password is:'${pass}'."
else
    echo " with password provided."
fi
