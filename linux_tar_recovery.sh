#!/bin/bash
#2018-01-29 
PATH=/bin:/sbin:/usr/bin:/usr/sbin
export PATH
START_TIME=`date '+%Y-%m-%d %H:%M:%S'`
BOOT_SIZE=1000                #size MB
SWAP_SIZE=8000                
# Check that we are root
(( EUID != 0 )) && exec sudo -- "$0" "$@"
#if [ "$EUID" -ne 0 ]; then
	#echo "Please run as root"
	#exit 1SEL_
#fi
read -p "Select a empty disk to recovery. example : \" /dev/sda \" : " sel_disk

if [ ! -b ${sel_disk} ] ; then
        echo "The selected disk is not exist. " ; exit 1
fi     
ROOT_START=$((${BOOT_SIZE}+${SWAP_SIZE}+2))
parted ${sel_disk} -s -a optimal mklabel msdos \
mkpart primary  2 $(($BOOT_SIZE+2)) \
mkpart primary linux-swap $(($BOOT_SIZE+2)) ${ROOT_START} \
mkpart primary ${ROOT_START} 100% \
toggle 1 boot 
if [ $? == 0 ]; then
        partprobe 
        echo "Making disk \"${sel_disk}\" partition is successful"
        parted -s ${sel_disk} p | tail -n 5 | grep -v "^$" 
        else
        echo "parted disk ${sel_disk} error and exit..." ; exit 1
fi
#When using the BIOS boot, install grub2 on the GPT partition table
###################################################################
#ROOT_START=$(($BOOT_SIZE+$SWAP_SIZE+4))
#parted ${sel_disk} -s -a optimal mklabel gpt \
#mkpart primary  2 4 \
#mkpart primary  4 $(($BOOT_SIZE+4)) \
#mkpart primary linux-swap $(($BOOT_SIZE+4)) ${ROOT_START}  \
#mkpart primary ${ROOT_START} 100%  \
#set 1 bios_grub on \
#toggle 2 boot \
#|| echo "parted disk ${sel_disk} error and exit..." ; exit 1

mkfs.ext4 ${sel_disk}3 && mount ${sel_disk}3 /mnt
mkfs.ext4 ${sel_disk}1 && mount ${sel_disk}1 /mnt/boot
mkswap ${sel_disk}2 && swapon ${sel_disk}2

read -p "select the backup file. exapmle: *backup_2018_1_30.tar.gz : " backup_file
if [ ! -f $backup_file] ; then
        echo "backup file is not exist,exiting..." ; exit 1
fi  

echo "Restore files from the backup file and install boot loader ."
tar --xattrs -xpf ~/$backup_file -C /mnt 
mkdir -p /mnt/{dev,proc,sys}
mount -o bind /dev /mnt/dev
mount -o bind /sys /mnt/sys
mount -o bind /proc /mnt/proc
chroot /mnt
grub2-install --target=i386-pc --recheck --boot-directory=/boot /dev/sda && \
           grub2-mkconfig -o /boot/grub2/grub.cfg

$boot_uuid=`blkid | grep ${sel_disk}1 | cut -d \" -f2`
$boot_fstype=`blkid | grep ${sel_disk}1 | cut -d \" -f4`
$root_uuid=`blkid | grep ${sel_disk}3 | cut -d \" -f2`
$root_fstype=`blkid | grep ${sel_disk}3 | cut -d \* -f4`
$swap_uuid=`blkid | grep ${sel_disk}2 | cut -d \" -f2`
$swap_fstype=swap
mv /etc/fstab /etc/fstab.bak
echo "UUID=$boot_uuid    /boot        $boot_fstype    defaults    0 0" >> /etc/fstab
echo "${sel_disk}3    /       $root_fstype        defaults    0 0" >> /etc/fstab
echo "${sel_disk}2    swap        defaults    0 0"  >> /etc/fstab
mount -a && echo "Recovery system successful ,check file "/etc/fstab" and reboot " ; exit  ||  exit 1

