#!/bin/ash

set -euo pipefail

newaliases
postmap lmdb:/etc/postfix/vuser
postmap lmdb:/etc/postfix/valias

