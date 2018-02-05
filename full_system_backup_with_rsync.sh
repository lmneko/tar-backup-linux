#!/bin/bash
#2018-02-03 
PATH=/bin:/sbin:/usr/bin:/usr/sbin
export PATH 
START_TIME=`date '+%Y-%m-%d %H:%M:%S'`
echo "Mush run in the livecd system."

rsync -aviHAXKh --partial --delete / /mnt