#!/bin/bash
#2018-01-29 
PATH=/bin:/sbin:/usr/bin:/usr/sbin
export PATH 
START_TIME=`date '+%Y-%m-%d %H:%M:%S'`
BOOT_SIZE=1000                #size MB
SWAP_SIZE=8000
boot_bios_efi='bios'
boot_lvm_disk='disk'
ROOT_START=$((${BOOT_SIZE}+${SWAP_SIZE}+2))                
# Check that we are root
(( EUID != 0 )) && exec sudo -- "$0" "$@"

sfdisk -d ${sel_disk} > ${sel_disk##*/}_partion_table.bak && \
echo "Partion table has been backed up to the file ${sel_disk##*/}_partion_table.bak"     #backup partion table
function check_part  {
if [ -z $sel_disk ];then         
       read -p "Select a empty disk to recovery. example : \" /dev/sda \" : " sel_disk
        check_part
else  if [ ! -b $sel_disk ];then
                 read -p "The selected disk is invalid. :"  sel_disk
                 check_part
        fi
        return
fi
}
check_part

        parted ${sel_disk} -s -a optimal mklabel msdos \
        mkpart primary  2 $(($BOOT_SIZE+2)) \
        mkpart primary $(($BOOT_SIZE+2))  ${ROOT_START}  \
        mkpart primary ${ROOT_START} 100% \
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
#mkpart primary linux-swap $(($BOOT_SIZE+4)) ${ROOT_START}  \
#mkpart primary ${ROOT_START} 100%  \
#set 1 bios_grub on \
#toggle 2 boot \
#|| echo "parted disk ${sel_disk} error and exit..." ; exit 1
        mkfs.ext4 ${sel_disk}3 && mount ${sel_disk}3 /mnt
        mkfs.ext4 ${sel_disk}1 && mount ${sel_disk}1 /mnt/boot
        mkswap ${sel_disk}2 && swapon ${sel_disk}2

function check_bakfile  {
if [ -z $backup_file ];then    
       read -p "select the backup file. exapmle: *backup_2018_1_30.tar.gz : " backup_file
       check_bakfile
else  if [ ! -f $backup_file ];then
                        read -p "backup file is not exist. :"  backup_file
                        check_bakfile
        fi
        read -p "${backup_file##*/} has been selected. Weather verify MD5? [Y/N]" chk_md5
        if [ ${chk_md5} == '[Yy]' ]  &&  [ -f ./backup.MD5 ];then
                md5=`md5sum ${backup_file}`
                md5bak=`cat backup.MD5`
                if [ ${md5%% *} == ${md5bak%% *} ];then
                    echo "check successful!"                  
                else
                    echo "check ${md5line##* } error!"
                    sleep 2s
                fi
         else 
               echo "MD5 file is not exist."
        fi          
        return  
fi
}
check_bakfile 

echo "Restore files from the backup file. Please wait..."
tar --xattrs -xpf $backup_file -C /mnt 
#for i in $chk_rec_file
#do
#        echo $i
#        if [ ! -d /mnt/$i ];then
#               echo "/mnt/$i is not exist.The Restore failed or error tar backup file"
#                #exit 1
#        fi
#done
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
root_uuid=`blkid | grep ${sel_disk}3 | cut -d \" -f2`
root_fstype=`blkid | grep ${sel_disk}3 | cut -d \" -f4`
swap_uuid=`blkid | grep ${sel_disk}2 | cut -d \" -f2`

mv /etc/fstab /etc/fstab.bak
echo "update \"/etc/fstab\"..."
echo "UUID=$boot_uuid    /boot        $boot_fstype    defaults    0 0" >> /etc/fstab
echo "${sel_disk}3    /       $root_fstype        defaults    0 0" >> /etc/fstab
echo "${sel_disk}2    swap     swap    defaults    0 0"  >> /etc/fstab
mount -a && echo "Recovery system successful .Please check file "/mnt/etc/fstab" and reboot "
exit

END_TIME=`date '+%Y-%m-%d %H:%M:%S'`
echo "Start time  : $START_TIME"
echo "End time : $END_TIME"


