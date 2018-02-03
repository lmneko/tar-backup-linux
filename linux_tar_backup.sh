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
sleep 2s
function usage {
        echo "tar_backup -s [source back disk] -d [backup file]  -n [back file name]   [tar --exclude options]"
}

function check_part {
if [ -z $sel_disk ];then         
        read -p "Please input the part of linux system. example : \"/dev/sda\" : " sel_disk
        check_part
else  if [ ! -b $sel_disk ];then
                 read -p "The selected disk is invalid. :"  sel_disk
                 check_part
        fi
        return
fi
}

function check_bakdir {
if [ -z $dir_bak];then         
        read -p "Please input the directory 
        that best choice of larger than 10G directory to save the backup file : " dir_bak 
        check_bakdir  
else   if [  ! -d $dir_bak ] ; then
                read -p "The selected directory is not exist. :" dir_bak
                check_bakdir
        fi  
        return
fi
}

function mount_disk {
    mount ${sel_disk} ${MNT_DIR:='/mnt'} && mount ${sel_disk}1 ${MNT_DIR}/boot  \
    || echo "mount error! and exit..." 
    return
}

function tar_restore_file {
    echo "Backup .Please wait..."
    sleep 2s
    tar --xattrs -cvpzf ${dir_bak}/system_backup_${lvm_hd}_${DATE}.tar.gz \
    --exclude=${MNT_DIR}/proc \
    --exclude=${MNT_DIR}/lost+found \
    --exclude=${MNT_DIR}/mnt \
    --exclude=${MNT_DIR}/sys \
    --exclude=${MNT_DIR}/media \
    --exclude=${MNT_DIR}/run \
    ${MNT_DIR}
    echo "Backup successful!"
    return
 } 
 check_part
 check_bakdir
 mount_disk
 tar_restore_file  
END_TIME=`date '+%Y-%m-%d %H:%M:%S'`
echo "Start time : ${START_TIME}"
echo "Complete time : ${END_TIME}"




