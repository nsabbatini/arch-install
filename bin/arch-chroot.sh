#!bin/bash

echo "############################"
echo "Running install under chroot"
echo "############################"
echo ""

# Before running this script, adjust parameters in file "parameters.sh"
source /root/arch-plasma/bin/parameters.sh
[[ -z "$user" ]] && { echo "Error: variable user undefined"; exit 1; }
[[ -z "$gpu" ]] && { echo "Error: variable gpu undefined"; exit 1; }
[[ -z "$multilib" ]] && { echo "Error: variable multilib undefined"; exit 1; }

echo "Configuring locale..."
ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
hwclock --systohc
locale-gen
echo "Locale done"

echo "Installing boot loader..."

grub-install --target=x86_64-efi --efi-directory=/efi --boot-directory=/boot --bootloader-id=arch
grub-mkconfig -o /boot/grub/grub.cfg

sed -Ei 's/^(.*LINUX_DEFAULT=)""$/\1"rw quiet loglevel=3 lsm=landlock,lockdown,yama,integrity,apparmor,bpf zswap.enabled=1"' /etc/default/grub
update-grub

echo "Bootloader done"

if [[ "$multlib" == "enabled" ]]; then
   echo "Enabling multilib packages"
   sed -Ei '/^#\[multilib\]/ {s/^#//; n; s/^#//}' /etc/pacman.conf
   echo "Done"
fi

echo "Setting root password..."
echo "Choose a password for root account"
passwd root
echo "Root password done"

echo "Creating non-root user account"
useradd -m -G wheel,libvirt $user
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/g' /etc/sudoers
echo "Choose a password for your user account"
passwd $user
echo "Non-root account done"

echo "Creating disk mounts for backup and media"
mkdir -p /media/Music
mkdir -p /media/Pictures
mkdir -p /media/Videos
mkdir -p /mnt/backup
echo "Disk mounts done"

# Configure systemd-resolved
rm /etc/resolv.conf
ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf

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
if [[ $gpu == "nvidia" ]]; then
   sudo systemctl enable nvidia-suspend.service
   sudo systemctl enable nvidia-hibernate.service
   sudo systemctl enable nvidia-resume.service
fi
echo "Enabling services done"

echo ""
echo "#############################"
echo "Finished install under chroot"
echo "#############################"

exit 0
