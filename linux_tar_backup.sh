#!/bin/bash
#2018-01-29 
#use tar to backup the whole linux system ,and also recovery with tar 
#need to use in linux livecd system
##########################################################
PATH=/bin:/sbin:/usr/bin:/usr/sbin
export PATH 
distro=centos7
type=full
DATE=`date +%F`
START_TIME=`date '+%Y-%m-%d %H:%M:%S'`
MNT_DIR='/media'
# Check that we are root
(( EUID != 0 )) && exec sudo -- "$0" "$@"
echo "It is best to use this script in the LiveCD system."
echo "And it is only to use in msdos part table."
sleep 2s
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
        read -p "Please input the directory that best choice of 
        larger than 10G directory to save the backup file : " dir_bak 
        check_bakdir  
  else   if [  ! -d $dir_bak ] ; then
                read -p "The selected directory is not exist. :" dir_bak
                check_bakdir
        fi  
        return
  fi
}
 check_part
 check_bakdir

mount ${sel_disk} ${MNT_DIR:='/mnt'} && mount ${sel_disk}1 ${MNT_DIR}/boot  \
|| echo "mount error! and exit..." ;exit
cd ${MNT_DIR}
    echo "Backup .Please wait..."
    sleep 2s
    tar --xattrs -cvpzf ${dir_bak%*/}/${distro}_${type}_backup_${DATE}.tar.gz \
    --exclude=./proc \
    --exclude=./lost+found \
    --exclude=./mnt \
    --exclude=./sys \
    --exclude=./media \
    --exclude=./run \
    ./
    echo "Backup successful!"
    return

echo "Generating MD5 into backup_${DATE}.MD5"
md5sum >> ${distro}_${type}_backup_${DATE}.MD5
END_TIME=`date '+%Y-%m-%d %H:%M:%S'`
echo "Start time : ${START_TIME}"
echo "Complete time : ${END_TIME}"




