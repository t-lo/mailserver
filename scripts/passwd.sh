#!/bin/ash

set -euo pipefail

if test $# -lt 2 ; then
    echo "Usage: $0 <user@domain> <password>"
    echo
    echo "       <user@domain> - user account to update password for."
    echo "       <password>    - user's new SMTP / IMAP password."
    echo
    exit
fi

user="$1"
pass="$2"

if ! grep -qE "^${user}:" /etc/dovecot/passwd; then
    echo "User '${user}' does not exist. Please create the user first."
    exit 1
fi

pass_sha="$(doveadm pw -p "${pass}" -u "${user}" -s SSHA256)"
sed -i "/^${user}:/d" /etc/dovecot/passwd
echo "${user}:${pass_sha}:2001:2001:/host/mail/inboxes/${user}::" >> /etc/dovecot/passwd

/update_aliases.sh

echo "Updated password for user '${user}'"
