#!/bin/bash
#2018-01-29 
#use tar to backup the whole linux system ,and also recovery with tar 
#need to use in linux livecd system
##########################################################
PATH=/bin:/sbin:/usr/bin:/usr/sbin
distro=centos7
type=full
DATE=`date +%F`
START_TIME=`date '+%Y-%m-%d %H:%M:%S'`
random=`cat /dev/urandom | od -x | re -d ' ' | head -n 1 | cut -c 7-14`
MNT_DIR='/mnt'
boot_part=
export PATH sel_disk dir_bak type distro DATE random
# Check that we are root
(( EUID != 0 )) && exec sudo -- "$0" "$@"
echo "It is best to use this script in the LiveCD system."

function check_part {
  if [ -z $sel_disk ];then         
        read -p "Please input the part of linux system. example : \"/dev/sda\" : " sel_disk      		
		check_part
  else  if [ ! -b $sel_disk ];then
                 read -p "The selected disk is invalid. :"  sel_disk
                 check_part
      fi
  fi
  read -p "Weather the linux system part is lvm part?[y\n] " resplvm
  if [[ "${resplvm}" =~ ^(yes|y)$ ]];then 
	read -p "Please input the boot part:" boot_part
	if [ ! -b $boot_part ];then
		echo "Not exist part and exit..."
		exit 1
	fi
  fi
  return
}

function check_bakdir {
  if [ -z $dir_bak ];then         
        read -p "Please input the directory to save the backup file : " dir_bak 
        check_bakdir  
  else   
	if [  ! -d $dir_bak ] ; then
                read -p "The selected directory is not exist. :" dir_bak
                check_bakdir
    fi  
  fi
  dir_bak=${dir_bak%*/}
}

function mnt_part {
	mount ${sel_disk} ${MNT_DIR:-'/mnt'}
	if [ -n ${boot_part} ];then 
		mount ${boot_part} ${MNT_DIR}/boot || exit 2 ; echo "Mount boot part error."
	else
		mount ${sel_disk}1 ${MNT_DIR}/boot 
	fi
	if [ $? != 0 ];then
		echo "Mount error and exit..."
		exit 1
	fi
	mkdir -p /mnt/{dev,proc,sys}
	mkdir -p /mnt/"${dir_bak}"
	mount -o bind /dev /mnt/dev
	mount -o bind /sys /mnt/sys
	mount -o bind /proc /mnt/proc
	mount -o bind ${dir_bak} /mnt/${dir_bak}
}
check_part
check_bakdir
mnt_part

chroot ${MNT_DIR}
echo "Backup .Please wait..."
sleep 1
tar --xattrs -cvpjf ${dir_bak}/${distro}_${type}_backup_${DATE}_${random}.tar.bz2 \
    --exclude=/proc \
    --exclude=/lost+found \
    --exclude=/mnt \
    --exclude=/sys \
    --exclude=/media \
    --exclude=/run \
	--exclude="${dir_bak}" \
    /
if [ $? != 0 ];then
	exit 1
fi
exit
echo "Backup successful!"

echo "Generating MD5 into OS_backup_${DATE}.MD5"
md5sum  ${dir_bak}/${distro}_${type}_backup_${DATE}_${random}.tar.bz2 \
>> ${dir_bak}/OS_backup${DATE}.MD5
END_TIME=`date '+%Y-%m-%d %H:%M:%S'`
echo "Start time : ${START_TIME}"
echo "Complete time : ${END_TIME}"




