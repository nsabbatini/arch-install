#!bin/bash

exec &> >(tee -a "/root/arch-chroot.log")

echo "############################"
echo "Running install under chroot"
echo "############################"
echo ""

# Before running this script, adjust parameters in file "parameters.sh"
source /root/arch-install/bin/parameters.sh

if [[ "$multlib" == "enabled" ]]; then
   echo "Enabling multilib packages"
   sed -Ei '/^#\[multilib\]/ {s/^#//; n; s/^#//}' /etc/pacman.conf
fi

echo "Running reflector..."
reflector --country 'US,BR' --sort rate --fastest 5 --save /etc/pacman.d/mirrorlist

echo "Installing packages..."
pacman -Syu
cat $pkg_list $pkg_list_extra | sed -E '/^#/d' | sed -E '/^\s*$/d' |  stdbuf -oL -eL pacman -S --needed -
[[ $? == 0 ]] || { echo "Error: pacman failed, fix and run again"; exit 1; }

echo "Configuring locale..."
ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
hwclock --systohc
locale-gen

echo "Installing boot loader..."

grub-install --target=x86_64-efi --efi-directory=/efi --boot-directory=/boot --bootloader-id=arch
grub-mkconfig -o /boot/grub/grub.cfg

sed -Ei 's/^(.*CMDLINE_LINUX=)""/\1"lsm=landlock,lockdown,yama,integrity,apparmor,bpf zswap.enabled=1"/' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

sed -Ei 's/^(HOOKS.*)\)/\1 grub-btrfs-overlayfs)/g' /etc/mkinitcpio.conf
sudo mkinitcpio -P

echo "Setting root password..."
echo "Choose a password for root account"
passwd root

echo "Creating non-root user account"
useradd -m -G wheel,libvirt $user
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/g' /etc/sudoers
echo "Choose a password for your user account"
passwd $user

echo "Creating disk mounts for backup and media"
mkdir -p /media/Music
mkdir -p /media/Pictures
mkdir -p /media/Videos
mkdir -p /mnt/backup

echo "Enabling systemd services..."
systemctl enable nftables
systemctl enable cups
systemctl enable sshd
systemctl enable fstrim.timer
systemctl enable logrotate.timer
systemctl enable reflector.timer
systemctl enable systemd-boot-update
systemctl enable systemd-timesyncd
systemctl enable systemd-networkd
systemctl enable systemd-resolved
systemctl enable apparmor
systemctl enable iwd
systemctl enable avahi-daemon
systemctl enable avahi-daemon.socket
systemctl enable bluetooth
systemctl enable smartd
systemctl enable sddm
systemctl enable libvirtd
systemctl enable power-profiles-daemon
systemctl enable media-Music.automount
systemctl enable media-Pictures.automount
systemctl enable media-Videos.automount
systemctl enable mnt-backup.automount
systemctl enable wait-for-ping
systemctl enable snapper-timeline.timer
systemctl enable snapper-cleanup.timer
systemctl enable grub-btrfsd.service
if [[ $gpu == "nvidia" ]]; then
   sudo systemctl enable nvidia-suspend.service
   sudo systemctl enable nvidia-hibernate.service
   sudo systemctl enable nvidia-resume.service
fi

echo ""
echo "#############################"
echo "Finished install under chroot"
echo "#############################"

exit 0
