#!/bin/bash

function print_usage
{
    echo "Usage:"
    echo "    $0 <nagios_address> <interval>"
    exit 1
}

if [ $# -ne 2 ]
then
    print_usage
fi

NAGIOS_ADDRESS=$1
INTERVAL=$2

PATH=$PATH:/usr/local/bin/
UPDATE_MONITOR=0
FILE_NEW="/tmp/check_bbb_salt_new.tmp"
FILE_OLD="/tmp/check_bbb_salt_old.tmp"

if [ -f $FILE_OLD ]
then
    echo "Last saved configuration:"
    cat $FILE_OLD
    echo "Temporary file exists"
    touch $FILE_NEW
    bbb-conf --salt > $FILE_NEW
    if [ `diff $FILE_OLD $FILE_NEW | wc -l` -ne 0 ]
    then
        echo "Found different information"
        UPDATE_MONITOR=1
        mv $FILE_NEW $FILE_OLD
    else
        echo "Didn't find different information"
    fi
else
    echo "Temporary file doesn't exist"
    bbb-conf --salt > $FILE_OLD
    UPDATE_MONITOR=1
fi
echo "Current configuration:"
cat $FILE_OLD

HOST=`cat $FILE_OLD | grep 'URL' | tr -d ' ' | sed 's:URL\:http\://\([^:/]*\).*:\1:g'`

if [ $UPDATE_MONITOR -eq 1 ]
then
    echo "Sending notification"
    ~/tools/nagios-etc/cli/server_up.sh $NAGIOS_ADDRESS bigbluebutton
    chmod +x ~/tools/installation-scripts/bbb-deploy/start-monitor.sh
    ~/tools/installation-scripts/bbb-deploy/start-monitor.sh $NAGIOS_ADDRESS $HOST $INTERVAL
else
    echo "Not sending notification"
fi
