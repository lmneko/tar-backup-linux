#!/bin/bash
#2018Äê01ÔÂ29ÈÕ 
PATH=/bin:/sbin:/usr/bin:/usr/sbin
export PATH
read -p "select a empty disk to recovery. example : /dev/sda" sel_disk
read -p "select the backup file. exapmle: *backup_2018_1_30.tar.gz" backup_file
parted ${seldisk} -s -a optimal mklabel msdos mkpart primary 1m 1G  mkpart primary linux-swap 1G 9G mkpart primary 9G 100% toggle 1 boot
mkfs.ext4 ${sel_disk}3 && mount ${sel_disk}3 /mnt
mkfs.ext4 ${sel_disk}1 && mount ${sel_disk}1 /mnt/boot
mkswap ${sel_disk}2 && swapon ${sel_disk}2

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
mount -a && echo "Recovery system successful ,check file "/etc/fstab" and reboot " ; exit  ||  exit