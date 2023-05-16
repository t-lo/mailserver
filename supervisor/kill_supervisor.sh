#!/bin/ash

# tell supervisord we are ...
echo "READY"

echo "################# Supervisor terminator script listening to events." >&2

while read line; do
    echo "################# Received Event: $line" >&2
    echo "################# Shutting down the supervisor." >&2
    kill -3 $(cat "/host/etc/supervisor/supervisord.pid")
done < /dev/stdin

echo "################# Supervisor terminator script stopping." >&2
