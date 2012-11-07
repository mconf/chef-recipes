#!/bin/bash

MONITORING_SERVERS=( <%= node[:mconf][:monitoring_servers] %> )
SEND_NSCA_DIR=<%= node[:nsca][:dir] %>
SEND_NSCA_CFG_DIR=<%= node[:nsca][:config_dir] %>
TIMEOUT=5

while read data; do
    # enable this 'echo' to debug
    # echo "[`date -u +%Y-%m-%dT%T.%3NZ`] Sending data: $data"
    for server in ${MONITORING_SERVERS[*]}; do
        echo "$data" | $SEND_NSCA_DIR/send_nsca -H $server -c $SEND_NSCA_CFG_DIR/send_nsca.cfg -to $TIMEOUT
    done
done
# this is important to keep chef executing even if it can't send the information to all the servers
exit 0
