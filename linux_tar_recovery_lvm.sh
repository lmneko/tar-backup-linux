#!/bin/bash
#2018-02-02 
PATH=/bin:/sbin:/usr/bin:/usr/sbin
export PATH 
START_TIME=`date '+%Y-%m-%d %H:%M:%S'`
BOOT_SIZE=1000                #size MB
SWAP_SIZE=8000
boot_bios_efi='bios'
boot_lvm_disk='disk'
OS_DTB='centos'
ROOT_START=$((${BOOT_SIZE}+${SWAP_SIZE}+2))                
# Check that we are root
(( EUID != 0 )) && exec sudo -- "$0" "$@"
#if [ "$EUID" -ne 0 ]; then
	#echo "Please run as root"
	#exit 1SEL_
#fi
echo "Only for restore the systems  that installed on lvm"
sleep 2s
read -p "Select a empty disk to recovery. example : \" /dev/sda \" : " sel_disk

if [ -b ${sel_disk} ] ; then
	sfdisk -d ${sel_disk} > seldisk_partion_table.bak && \
	echo " \"$sel_disk\"'s partion table has been backed up to the file seldisk_partion_table.bak"     #backup partion table
else
        echo "The selected disk is not exist. " ; exit 1
fi

parted ${sel_disk} -s -a optimal mklabel msdos \
mkpart primary  2 $(($BOOT_SIZE+2)) \
mkpart primary $(($BOOT_SIZE+2))  100% \
toggle 1 boot 
if [ $? == 0 ]; then
        partprobe 
        echo "Making disk \"${sel_disk}\" partition is successful"
        parted -s ${sel_disk} p | tail -n 5 | grep -v "^$" 
else
        echo "parted disk ${sel_disk} error.  Restore the partition table ." 
		sfdisk ${sel_disk} < seldisk_partion_table.bak
fi


#When using the BIOS boot, install grub2 on the GPT partition table
###################################################################
#ROOT_START=$(($BOOT_SIZE+$SWAP_SIZE+4))
#parted ${sel_disk} -s -a optimal mklabel gpt \
#mkpart primary  2 4 \
#mkpart primary  4 $(($BOOT_SIZE+4)) \
#mkpart primary $(($BOOT_SIZE+4)) 100%  \
#set 1 bios_grub on \
#toggle 2 boot \
#|| echo "parted disk ${sel_disk} error and exit..." ; exit 1

pvcreate ${sel_disk}2
vgcreate centos ${sel_disk}2
lvcreate -L ${SWAP_SIZE} -n /dev/centos/swap
lvcreate -L 100%FREE -n /dev/centos/root
mkfs.ext4  /dev/centos/root && mount /dev/centos/root /mnt/
mkfs.ext4 ${sel_disk}1 && mount ${sel_disk}1 /mnt/boot
mkswap /dev/centos/swap && swapon /dev/centos/swap


read -p "select the backup file. exapmle: *backup_2018_1_30.tar.gz : " backup_file
if [ ! -f $backup_file ] ; then
        echo "backup file is not exist,exiting..." 
        exit 1
fi  

echo "Restore files from the backup file and install boot loader . Please wait..."
tar --xattrs -xpf $backup_file -C /mnt 
echo "Restore completed."
mkdir -p /mnt/{dev,proc,sys}
mount -o bind /dev /mnt/dev
mount -o bind /sys /mnt/sys
mount -o bind /proc /mnt/proc
export sel_disk
chroot /mnt
grub2-install --target=i386-pc --recheck --boot-directory=/boot ${sel_disk} && \
           grub2-mkconfig -o /boot/grub2/grub.cfg

boot_uuid=`blkid | grep ${sel_disk}1 | cut -d \" -f2`
boot_fstype=`blkid | grep ${sel_disk}1 | cut -d \" -f4`
root_uuid=`blkid | grep "/dev/mapper/centos-root" | cut -d \" -f2`
root_fstype=`blkid | grep "/dev/mapper/centos-root"  | cut -d \" -f4`
#swap_uuid=`blkid | grep ${sel_disk}2 | cut -d \" -f2`
#swap_fstype=swap
mv /etc/fstab /etc/fstab.bak
echo "UUID=$boot_uuid    /boot        $boot_fstype    defaults    0 0" >> /etc/fstab
echo "/dev/mapper/centos-root    /       $root_fstype        defaults    0 0" >> /etc/fstab
echo "/dev/mapper/centos-swap    swap     swap    defaults    0 0"  >> /etc/fstab
mount -a && echo "Recovery system successful ,check file "/mnt/etc/fstab" and reboot "
exit
END_TIME=`date '+%Y-%m-%d %H:%M:%S'`
echo "Start time  : $START_TIME"
echo "End time : $END_TIME"


