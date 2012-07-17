#!/bin/bash

BASEDIR=$(dirname $0)
cd $BASEDIR

BEFORE=`git log | head -n 1`
git pull origin master > /dev/null 2>&1
if [ $? -ne 0 ]
then
    echo "Invalid git repository"
    exit 1
fi
AFTER=`git log | head -n 1`

if [ "$BEFORE" == "$AFTER" ]
then
    echo "Already up-to-date"
else
    echo "Updating..."
    performance_report.py restart
fi
