#!/bin/bash

PATH=/bin:/sbin:/usr/bin:/usr/sbin
export PATH 
START_TIME=`date '+%Y-%m-%d %H:%M:%S'`
#User has partitioned, formatted, and mounted partitions on /mnt
rsync -aviHAXKh --partial --delete / /mnt