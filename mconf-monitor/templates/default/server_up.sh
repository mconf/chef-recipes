#!/bin/bash

function print_usage
{
	echo "Usage:"
	echo "    $0 <destination> <bigbluebutton|freeswitch>"
	exit 1
}

if [ $# -ne 2 ]
then
	print_usage
fi

if [ $2 != "bigbluebutton" ] && [ $2 != "freeswitch" ]
then
	print_usage
fi

if [ $2 == "bigbluebutton" ]
then
	HOST=`bbb-conf --salt | grep URL | tr -d ' ' | sed 's/URL://g'`
	SALT=`bbb-conf --salt | grep Salt | tr -d ' ' | sed 's/Salt://g'`
	MESSAGE="$2 $HOST $SALT"
else
	HOST=`ifconfig | grep 'inet addr:' | grep -v '127.0.0.1' | cut -d: -f2 | awk '{print $1}'`
	MESSAGE="$2 $HOST"
fi
DESTINATION=$1
SEND_NSCA_DIR=/usr/local/nagios/bin
SEND_NSCA_CFG_DIR=/usr/local/nagios/etc
SERVICE="Server UP"
STATE=3

/usr/bin/printf "%s\t%s\t%s\t%s\n" "localhost" "$SERVICE" "$STATE" "$MESSAGE" | $SEND_NSCA_DIR/send_nsca -H $DESTINATION -c $SEND_NSCA_CFG_DIR/send_nsca.cfg

