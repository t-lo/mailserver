#!/bin/bash

script_dir="$(cd $(dirname "$0"); pwd)"

function usage() {
    local container_id="$1"

    echo "Usage: $0 <command> [options]"
    echo "   Server status:"
    if [ -z "${container_id}" ] ; then
        echo "           Mailserver container is stopped."
    else
        echo "           Mailserver container is running at ID '${container_id}'".
    fi
    echo "   Commands:"
    echo "          add <user@domain> [<password>]    - Add user for domain to mailserver."
    echo "                                              A password may optionally be provided; a random"
    echo "                                              one will be generated and printed if none was provided."
    echo "          del <user@domain> [--purge-inbox] - Remove user from mailserver. Optionally delete all"
    echo "                                              of user's emails."
    echo "          passwd <user@domain> <new-pass>   - Update a user's password to <new-pass>."
    echo "          list                              - List users and perform basic sanity checks."
    echo "          update-aliases                    - Update aliases database (run this after editing"
    echo "                                              [workdir]/etc/postfix/valias)."
    echo "          help                              - Print help."
    echo

}
# --

function mailcontainer_id() {
    docker ps --filter "volume=/host" \
        | while read id name rest; do
            if [ "$id" = "CONTAINER" ]; then
                continue
            fi
            if docker inspect -f '{{ .Mounts }}' "$id" | grep -q "$(pwd)" ; then
                echo "$id"; break;
            fi;
    done
}
# --

function workdir_from_container_id() {
    local container_id="$1"
    
    basename "$(docker inspect -f '{{ .Mounts }}' "${container_id}" | grep '/host' | awk '{print $2}')"
}
# --

function list_users() {
    local container_id="$1"
    local workdir="$(workdir_from_container_id "${container_id}")"

    # Go through all virtual users
    local user=""
    local mdir=""
    printf "%40.40s | %10.10s | %s\n" "user" "mbox size" "sanity checks"
    printf "%40.40s + %10.10s + %s\n" "--------------------" "----------" "------------"
    cat "${workdir}/etc/postfix/vuser" | while read user mdir; do

        local sanity=""

        local domain="$(echo "${user}" | sed 's/.*@//g')"
        local mbox="${workdir}/mail/inboxes/${domain}/${user}/Maildir/"
        local mbox_size="<empty>"

        if [ -d "${mbox}" ] ; then
            mbox_size="$(du -sch "${mbox}" | grep total | awk '{print $1}')"
        fi

        if ! grep -qE "^${user}:" "${workdir}/etc/dovecot/passwd" ; then
            sanity="${sanity} [No password set in ${workdir}/etc/dovecot/passwd! User cannot login]"
        fi

        if [ -z "${sanity}" ] ; then
            sanity="OK"
        fi
        printf "%40.40s | %10.10s | %s\n" "${user}" "${mbox_size}" "${sanity}"
    done
}
# --

container="$(mailcontainer_id)"

if [ $# -lt 1 ] ; then
    set -- "help"
fi

case "$1" in
    add) shift; docker exec -ti "${container}" /add_user.sh "${@}" ;;
    del) shift; docker exec -ti "${container}" /del_user.sh "${@}" ;;
    passwd) shift; docker exec -ti "${container}" /passwd.sh "${@}" ;;
    update-aliases)
         shift; docker exec -ti "${container}" /update_aliases.sh;;  
    list) list_users "${container}";;
    help) usage "${container}" ; exit 0;;
    *) echo "Unknown command '$1'."; usage "${container}" ; exit 1;;
esac
