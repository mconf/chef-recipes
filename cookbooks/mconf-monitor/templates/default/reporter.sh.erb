#!/bin/bash

while read data; do
    # enable this 'echo' to debug
    # echo "[`date -u +%Y-%m-%dT%T.%3NZ`] Sending data: $data"
    <% if @nsca_server -%>
    	<% @nsca_server.each do |srv| -%>
    echo "$data" | <%= @nsca_dir %>/send_nsca -H <%= srv %> -c <%= @nsca_config_dir %>/send_nsca.cfg -to <%= @nsca_timeout %>
    	<% end -%>
	<% end -%>
done
# this is important to keep chef executing even if it can't send the information to all the servers
exit 0
