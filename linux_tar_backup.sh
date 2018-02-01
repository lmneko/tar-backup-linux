#!/bin/bash
#2018年01月29日 
#use tar to backup the whole linux system ,and also recovery with tar 
#need to use in linux livecd system
#
#
##########################################################
PATH=/bin:/sbin:/usr/bin:/usr/sbin
export PATH 
DATE=`data +%F`
START_TIME=`date '+%Y-%m-%d %H:%M:%S'`
echo "It is best to use this script in the LiveCD system."
echo "And it is only to use in msdos part table."
read -p "Please input the part of linux system . example : \" /dev/sda \" : " system_part
if [ ! -b $sel_disk ] ; then
        echo "The selected disk is not exist. " ; exit 1
fi  
read -p "Please input the directory to save backup file : " dir_bak   
if [ ! -d $dir_bak ] ; then
        echo "The selected directory is not exist. " ; exit 1
fi  
    mount ${sel_disk} /mnt
    mount ${sel_disk}1 /mnt/boot
    mount -o bind /dev /mnt/dev
    mount -o bind /sys  /mnt/sys
    mount -o bind /proc /mnt/proc
    chroot /mnt
    tar --xattrs -cvpzf ${dir_bak}/system_backup_${DATE}.tar.gz \
    --exclude=/proc \
    --exclude=/lost+found \
    --exclude=/mnt \
    --exclude=/sys \
    --exclude=/media \
#    --exclude=/home \
    --exclude=/run \
    / 
    exit
COM_TIME=`date '+%Y-%m-%d %H:%M:%S'`
echo "Backup successful!"
echo "Start time : ${START_TIME}"
echo "Complete time : ${COM_TIME}"




