#!/bin/bash
#use tar to backup the whole linux system ,and also recovery with tar 
#need to use in linux livecd system

PATH=/bin:/sbin:/usr/bin:/usr/sbin
distro=centos7_2
type=full
DATE=`date +%F`
START_TIME=`date '+%Y-%m-%d %H:%M:%S'`
random=`cat /dev/urandom | od -x | tr -d ' ' | head -n 1 | cut -c 7-14`
run_dir=`pwd`
MNT_DIR='/target'
boot_lvmdisk=
boot_part=
tar_exclude=
scriptname=$(basename "$0")
export PATH sel_disk dir_bak type distro DATE random
# Check that we are root
((EUID!=0)) && exec sudo -- "$0" "$@"

function usage {
	cat << EOF
	Script to use tar to backup the Centos system
	Please run this scropt in LiveCD system
	Assumptions:
	Dont mount any partion on "$MNT_DIR",the "$MNT_DIR" will be used to mount backup partion
		
	Usage: $scriptname [options] device [part-type] -ld
	-a                              Arch diretctory to save backup file default=${run_dir}
	-e                              --exclude tar options
	-s                              Select the backup part (e.g. /dev/sda)
	-b                              Select the boot part 
	-m                              backup part mount dir
	part-type                       The root partition device type for 
	                                the backup file [lvm|disk]
	-l                              lvm
	-d                              disk
	-h                              Show help message
	Example ./${scriptname} -a /media -b /dev/sda1 -s /dev/centos/root -l
EOF
}

function check_part {
	if [ -z $sel_disk ];then         
        read -p "Please input the part of the system \"/\" part :" sel_disk     		
		check_part
	else  
		if [ ! -b $sel_disk ];then
                 echo "The selected disk is invalid."
                 exit 1
		fi
	fi
	return
}

function chk_lvm {
	if [ -z $boot_lvmdisk ];then
		read -p "Weather the system \"/\" part is lvm?[y\n] " resplvm
		if [[ "${resplvm}" =~ ^(yes|y)$ ]];then
			boot_lvmdisk=lvm
		elif [[ "${resplvm}" =~ ^(no|n)$ ]];then
				boot_lvmdisk=disk
		else
			exit 1
		fi	
	fi
	if [ -z $boot_part ];then
		read -p "Please input the boot part:" boot_part
		chk_lvm
	else
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
                echo "The selected directory is not exist."
                exit 1
        fi  
	fi
	dir_bak=${dir_bak%*/}
}

function mnt_part {
	mkdir $MNT_DIR 2>/dev/null
	mount ${sel_disk} ${MNT_DIR}
	mkdir $MNT_DIR/boot 2>/dev/null
	if [ -n ${boot_part} ];then 
		mount ${boot_part} ${MNT_DIR}/boot || exit 1
	else
		echo "Boot part do not select and exit..."
		exit 1
	fi
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
	tar --xattrs -cvpjf ${dir_bak}/${distro}_${boot_lvmdisk}_backup_${DATE}_${random}.tar.bz2 \
    --exclude=/proc \
    --exclude=/lost+found \
    --exclude=/mnt \
    --exclude=/sys \
    --exclude=/dev \
    --exclude=/media \
    --exclude=/run \
    --exclude="${dir_bak}" \
    "$tar_exclude" \
    /
EOF
	if [ $? != 0 ];then
		exit 1
	fi
	echo "Backup successful!"

	echo "Generating MD5 into OS_backup_${DATE}.MD5"
	md5sum  ${dir_bak}/${distro}_${boot_lvmdisk}_backup_${DATE}_${random}.tar.bz2 \
	>> ${dir_bak}/OS_backup${DATE}.MD5
	END_TIME=`date '+%Y-%m-%d %H:%M:%S'`
	echo "Start time : ${START_TIME}"
	echo "Complete time : ${END_TIME}"
}

while getopts ":a:b:e:m:s:c:dlh" opt; do
	case "$opt" in
		a)
			dir_bak=$OPTARG
			;;
		b)
			boot_part=$OPTARG
			;;
		e)
			tar_exclude="--exclude=$OPTARG"
			;;
		m)
			MNT_DIR=$OPTARG
			;;
		s)
			sel_disk=$OPTARG
			;;
		d)
			boot_lvmdisk=disk
			;;
		l)
			boot_lvmdisk=lvm
			;;
		h)
			usage
			exit
			;;
		'?')
			echo "Fatal error: invalid options..."
			usage
			exit 1
			;;
	esac
done
chk_lvm
check_part
check_bakdir
mnt_part
tar_bak
