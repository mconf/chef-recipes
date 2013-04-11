#!/bin/bash

cookbooks=( "bigbluebutton" "live-notes-server" "mconf-live" "mconf-monitor" "mconf-node" "nsca" "psutil" )
for c in ${cookbooks[@]}; do
	foodcritic ../cookbooks/$c
done
