#!/bin/bash
#2018-01-29 
#use tar to backup the whole linux system ,and also recovery with tar 
#need to use in linux livecd system
#
#
##########################################################
PATH=/bin:/sbin:/usr/bin:/usr/sbin
export PATH 
DATE=`date +%F`
START_TIME=`date '+%Y-%m-%d %H:%M:%S'`
MNT_DIR='/mnt'
extend_opt=' '
# Check that we are root
(( EUID != 0 )) && exec sudo -- "$0" "$@"
echo "It is best to use this script in the LiveCD system."
echo "And it is only to use in msdos part table."
read -p "Please input the part of linux system . example : \" /dev/sda \" : " system_part
if [ ! -b $sel_disk ] ; then
        echo "The selected disk is not exist. " ; exit 1
fi  
read -p "Please input the directory 
that best choice of larger than 10G directory to save the backup file : " dir_bak   
if [  ! -d $dir_bak ] ; then
        echo "The selected directory is not exist. " 
        exit
fi  
    mount ${sel_disk} ${MNT_DIR} && mount ${sel_disk}1 ${MNT_DIR}/boot  \
    || echo "mount error! and exit..." ; exit 
    echo "Backup .Please wait..."
    sleep 2
    tar --xattrs -cvpzf ${dir_bak}/system_backup_${DATE}.tar.gz \
    --exclude=${MNT_DIR}/proc \
    --exclude=${MNT_DIR}/lost+found \
    --exclude=${MNT_DIR}/mnt \
    --exclude=${MNT_DIR}/sys \
    --exclude=${MNT_DIR}/media \
    --exclude=${MNT_DIR}/run \
    ${MNT_DIR}
    
END_TIME=`date '+%Y-%m-%d %H:%M:%S'`
echo "Backup successful!"
echo "Start time : ${START_TIME}"
echo "Complete time : ${END_TIME}"




