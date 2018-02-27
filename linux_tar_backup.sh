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
random=`cat /dev/urandom | od -x | tr -d ' ' | head -n 1 | cut -c 7-14`
run_dir=`pwd`
MNT_DIR='/mnt'
boot_lvmdisk=
boot_part=
export PATH sel_disk dir_bak type distro DATE random
# Check that we are root
(( EUID != 0 )) && exec sudo -- "$0" "$@"
echo "It is best to use this script in the LiveCD system."

function check_part {
	if [ -z $sel_disk ];then         
        read -p "Please input the part of the system \"/\" part :" sel_disk     		
		check_part
	else  
		if [ ! -b $sel_disk ];then
                 read -p "The selected disk is invalid. :"  sel_disk
                 check_part
		fi
	fi
	return
}

function chk_lvm {
	if [ -z $boot_lvmdisk ];then
		read -p "Weather the system \"/\" part is lvm?[y\n] " resplvm
		if [[ "${resplvm}" =~ ^(yes|y)$ ]];then
			boot_lvmdisk=lvm
		else
			boot_lvmdisk=disk
		fi	
	fi
	if [[ "$boot_lvmdisk" == "lvm" ];then
		if [ -z $boot_part ];then
			read -p "Please input the boot part:" boot_part
		fi
		if [ ! -b $boot_part ];then
				echo "The boot part is not exist and exit..."
				exit 1
		fi
	fi
}

function check_bakdir {
	if [ -z $dir_bak ];then         
        dir_bak=$run_dir
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
	mount ${sel_disk} ${MNT_DIR:="/mnt"}
	if [ -n ${boot_part} ];then 
		mount ${boot_part} ${MNT_DIR}/boot || exit 1
	else
		mount ${sel_disk}1 ${MNT_DIR}/boot || exit 1
	fi
	
	if [ $? != 0 ];then
		echo "Mount error and exit..."
		exit 1
	fi
	mkdir -p ${MNT_DIR}/{dev,proc,sys}
	mkdir -p ${MNT_DIR}/"${dir_bak}"
	mount -o bind /dev ${MNT_DIR}/dev
	mount -o bind /sys ${MNT_DIR}/sys
	mount -o bind /proc ${MNT_DIR}/proc
	mount -o bind ${dir_bak} ${MNT_DIR}/${dir_bak}
}

function tar_bak {
	echo "Backup .Please wait..."
	sleep 1
	chroot ${MNT_DIR} <<-EOF
	tar --xattrs -cvpjf ${dir_bak}/${distro}_${type}_backup_${DATE}_${random}.tar.bz2 \
    --exclude=/proc \
    --exclude=/lost+found \
    --exclude=/mnt \
    --exclude=/sys \
    --exclude=/dev \
    --exclude=/media \
    --exclude=/run \
    --exclude="${dir_bak}" \
    /
EOF
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
}

while getopts ":a:b:c:dl" opt; do
	case "$opt" in
		a)
			dir_bak=$OPTARG
			;;
		b)
			sel_disk=$OPTARG
			;;
		c)
			MNT_DIR=$OPTARG
			;;
		d)
			boot_lvmdisk=disk
			;;
		l)
			boot_lvmdisk=lvm
			;;
		'?')
			echo "Fatal error: invalid options..."
			exit 1
			;;
	esac
done
chk_lvm
check_part
check_bakdir
mnt_part
tar_bak