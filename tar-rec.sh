#!/bin/bash
#2018-02-02
PATH=/bin:/sbin:/usr/bin:/usr/sbin
START_TIME=`date "+%Y-%m-%d %H:%M:%S"`
BOOT_SIZE=1000
SWAP_SIZE=8000   #size MB
boot_biosefi=bios
boot_lvmdisk=lvm
ROOT_START=$((${BOOT_SIZE}+${SWAP_SIZE}+2))
scriptname=$(basename "$0")
export PATH sel_disk START_TIME
((EUID!=0)) && exec sudo -- "$0" "$@"

function usage {
	cat << EOF
	Script to recovery the Centos  from tar backup file
	Please run this scropt in LiveCD system
	Usage: $scriptname [part-size] SIZE [options] device [part-type] [lvm|disk]
	
	-b                              Select the backup file to recovery
	device                          Device to restore (e.g. /dev/sda)
	  -p                            Select device
	part-type                       The root partition device type for the backup file [lvm|disk]
	  -l                            lvm
	  -d                            disk
	part-size                       Default unit is MB
	  -B                            The boot part size. default=1000
	  -S                            The swap part size. default=8000
	-h                              Show help message
	
EOF
}

function check_part {
	if [ -z $sel_disk ];then
		read -p "Select a empty disk to recovery. :" sel_disk
		check_part
	else if [ ! -b $sel_disk ];then
			read -p "The selected disk is invalid. :" sel_disk
			check_part
		fi
	fi
}

function chk_bakfile {
	if [ -z ${backup_file} ];then
		read -p "Select the *.tar.bz2 backup file to restore: " backup_file
		chk_bakfile
	else if [ ! -f ${backup_file} ];then
			read -p  "backup file is not exist:" backup_file
			chk_bakfile
		 fi
	fi
}

function chk_md5 {
	cd ${backup_file%/*} 2>>/dev/null
	read -p "${backup_file##*/} has been selected. Weather verify MD5? [y/n]" response
	 if [[ "${response}" =~ ^(yes|y)$ ]];then
		if [ -f ./OS_backup*.MD5 ];then
			bkf_md5=`md5sum ${backup_file} | cut -d " " -f1`
			md5_bakfile=`cat OS_backup*.MD5 | cut -d " " -f1`
			[ "$bkf_md5" == "$md5_bakfile" ] && echo "MD5 check successful!" \
			|| echo "MD5 check fail! and exit..." 
		else 
			echo "MD5 file is not exist. "
			exit 1
		fi
	  fi
}

function chk_lvmdisk {
	if [[ $boot_lvmdisk =~ ^(lvm|disk)$ ]];then
		return
	else 
		exit 1
	fi
}

function mk_part {
    check_part
    sfdisk -d ${sel_disk} > ${sel_disk##*/}_partion_table.bak && \
    echo "Partion table has been backed up to the file ${sel_disk##*/}_partion_table.bak" #bckup partion table
    mkpart primary  2 $(($BOOT_SIZE+2)) \
    mkpart primary $(($BOOT_SIZE+2))  ${ROOT_START}  \
    mkpart primary ${ROOT_START} 100% \
    toggle 1 boot
	if [ $? == 0 ];then
		partprobe
		echo "Making disk \"${sel_disk}\" partion is successful"
		parted -s ${sel_disk} p | tail -n 5 | grep -v "^$"
	else 
		echo "Partion disk ${sel_disk} error. Restore the partion table..."
		sfdisk ${sel_disk} < ${sel_disk##*/}_partion_table.bak
		exit 1
	fi
}

function mkfs_mount {
    mk_part
    mkdir -p /mnt/boot
    mkfs.ext4 ${sel_disk}3 && mount ${sel_disk}3 /mnt || exit 1	
    mkfs.ext4 ${sel_disk}1 && mount ${sel_disk}1 /mnt/boot || exit 1
    mkswap ${sel_disk}2 && swapon ${sel_disk}2 || exit 1
}

function mkpart_lvm {
	check_part
	sfdisk -d ${sel_disk} > ${sel_disk##*/}_partion_table.bak && \
	echo "Partion table has been backed up to the file ${sel_disk##*/}_partion_table.bak" #bckup partion table
	parted ${sel_disk} -s -a optimal mklabel msdos \
	mkpart primary 2 $(($BOOT_SIZE+2)) \
	mkpart primary $((BOOT_SIZE+2)) 100% \
	toggle 1 boot \
	toggle 2 lvm
	if [ $? == 0 ];then
		partprobe
		echo "Making disk \"${sel_disk}\" partion is successful"
		parted -s ${sel_disk} p | tail -n 5 | grep -v "^$"
		sleep 1
	else 
		echo "Partion disk ${sel_disk} error. Restore the partion table..."
		sfdisk ${sel_disk} < ${sel_disk##*/}_partion_table.bak
		exit 1
	fi
}

#When using the BIOS boot, install grub2 on the GPT partition table
###################################################################
# function mkgpt_in_biosmod {
	# ROOT_START=$(($BOOT_SIZE+$SWAP_SIZE+4))
	# parted ${sel_disk} -s -a optimal mklabel gpt \
	# mkpart primary  2 4 \
	# mkpart primary  4 $(($BOOT_SIZE+4)) \
	# mkpart primary $(($BOOT_SIZE+4)) 100%  \
	# set 1 bios_grub on \
	# toggle 2 boot \
	# ||  exit 1
# }

function cre_lvmp {
	mkpart_lvm
	echo "Create lvm part..."
	sleep 1
	pvcreate ${sel_disk}2
	vgcreate centos ${sel_disk}2
	lvcreate -L ${SWAP_SIZE}m -n /dev/centos/swap
	lvcreate -l 100%FREE -n /dev/centos/root
	mkdir -p /mnt/boot
	mkfs.xfs /dev/centos/root && mount /dev/centos/root /mnt/ || exit 1
	mkfs.xfs ${sel_disk}1 && mount ${sel_disk}1 /mnt/boot || exit 1
	mkswap /dev/centos/swap && swapon /dev/centos/swap || exit 1
}

function tar_res {
    chk_bakfile
	chk_lvmdisk
	if [[ $boot_lvmdisk -eq "lvm" ]];then
		cre_lvmp
	else 
		if [[ $boot_lvmdisk -eq "disk" ]];then
			mkfs_mount
		fi
	fi
	echo "Restore files from the backup file. Please wait..."
	tar --xattrs -xpf $backup_file -C /mnt  --checkpoint=100 --checkpoint-action=dot --totals \
	&& echo "Restore completed." \
	|| exit 1
}

function insgrub_genfstab {
	echo "Install grub2 and gen \"/etc/fstab\"..."
	sleep 1
	mkdir -p /mnt/{dev,proc,sys}
	mount -o bind /dev /mnt/dev
	mount -o bind /sys /mnt/sys
	mount -o bind /proc /mnt/proc
	chroot /mnt <<-EOF
	#grub2-install --target=i386-pc --recheck --boot-dirctory=/boot ${sel_disk} && \
	grub2-install --target=i386-pc --recheck ${sel_disk} && \
	grub2-mkconfig -o /boot/grub2/grub.cfg
	mv /etc/fstab /etc/fstab.bak
	EOF

	chk_lvmdisk
	echo "Update \"/etc/fstab\"..."
	boot_uuid=`blkid | grep ${sel_disk}1 | cut -d\" -f2` || exit 1
	boot_fstype=`blkid | grep ${sel_disk}1 | cut -d\" -f4`
	export boot_uuid boot_fstype
	if [[ $boot_lvmdisk -eq "lvm" ]];then
		chroot /mnt <<-EOF
		root_uuid=`blkid | grep "/dev/mapper/centos-root" | cut -d\" -f2`
		root_fstype=`blkid | grep "/dev/mapper/centos-root" | cut -d\" -f4`
		swap_uuid=`blkid | grep "/dev/mapper/centos-swap" | cut -d\" -f2`					
		echo "${sel_disk}1" >> /etc/fstab
		echo "UUID=$boot_uuid    /boot    $boot_fstype    defaults    0 0" >> /etc/fstab
		echo "#/dev/mapper/centos-root" >> /etc/fstab
		echo "UUID=$root_uuid    /    $root_fstype    defaults    0 0" >> /etc/fstab
		echo "#/dev/mapper/centos-swap" >> /etc/fstab
		echo "UUID=$swap_uuid    swap    swap    defaults    0 0" >> /etc/fstab
		EOF
	else
		if [[ $boot_lvmdisk -eq "disk" ]];then
			chroot /mnt <<-EOF
			root_uuid=`blkid | grep ${sel_disk}3 | cut -d\" -f2`
			root_fstype=`blkid | grep ${sel_disk}3 | cut -d\" -f4`
			swap_uuid=`blkid | grep ${sel_disk}2 | cut -d\" -f2`
			echo "${sel_disk}1" >> /etc/fstab
			echo "UUID=$boot_uuid    /boot    $boot_fstype    defaults    1 2" >> /etc/fstab
			echo "#${sel_disk}3" >> /etc/fstab
			echo "UUID=$root_uuid    /    $root_fstype    defaults    0 0" >> /mnt/etc/fstab
			echo "#${sel_disk}2" >> /etc/fstab
			echo "UUID=$swap_uuid    swap    swap    defaults    0 0" >> /etc/fstab
			EOF
		fi
	fi
	echo "Recovery system successful,check file \"/mnt/etc/fstab\" and reboot"
	return
}

while getopts ":B:S:b:p:dlh" opt; do
	case "$opt" in
		B)
			BOOT_SIZE=$OPTARG
			;;
		S)
			SWAP_SIZE=$OPTARG
			;;
		b)
			backup_file=$OPTARG
			;;
		p)
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
			exit 1
			;;
	esac
done

tar_res
insgrub_genfstab
END_TIME=`date "+%Y-%m-%d %H:%M:%S"`
echo "Start time: $START_TIME"
echo "End time: $END_TIME"
exit 
