#!/bin/bash
#2018年01月29日 
#use tar to backup the whole linux system ,and also recovery with tar 
#need to use in linux livecd system
#Partition Table: msdos
###
##########################################################
DATE=`data +%F`
SYS_NAME=`cat /etc/centos_release`
PATH=/bin:/sbin:/usr/bin:/usr/sbin
export PATH DATE SYS_NAME
read -p "Please input the part of linux system . example : /dev/sda" system_part

    mount /dev/sda2 /mnt
    mount /dev/sda1 /mnt/boot
    mount -o bind /dev /mnt/dev
    mount -o bind /sys  /mnt/sys
    mount -o bind /proc /mnt/proc
    chroot /mnt
    tar --xattrs -cvpzf /mnt/d/${SYS_NAME}_backup_${DATE}.tar.gz \
    --exclude=/proc \
    --exclude=/lost+found \
    --exclude=/mnt \
    --exclude=/sys \
    --exclude=/media \
    --exclude=/home \
    --exclude=/run \
    / 
exit



