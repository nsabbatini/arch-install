#!bin/bash

# ############################################
# Swap file, location, time zone, hostname
# ############################################

# Create swap file
dd if=/dev/zero of=/swapfile bs=1M count=2048 status=progress
chmod 600 /swapfile
mkswap /swapfile
echo '/swapfile none swap defaults 0 0' | tee -a /etc/fstab
echo "swapfile created"

# Set the time zone and enable hardware clock
ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
hwclock --systohc
echo "timezone set"

# Edit the locale.gen file and generate the locales
sed -ie 's/^#en_US.UTF-8/en_US.UTF-8/g' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "locale set"

# Create keyblard config file and set KEYMAP variable
echo "KEYMAP=br-latin1-us" > /etc/vconsole.conf
echo "console keyboard configured"

# Configure hostname
echo "lince" > /etc/hostname
echo "host name configured"

# Create /etc/hosts
{ echo "127.0.0.1 localhost";
  echo "::1       localhost";
  echo "127.0.0.1 lince.localdomain lince";
} > /etc/hosts
echo "/etc/hosts created"

# ###########################
# Basic software and services
# ###########################

echo "initating pakage download"
pacman -S efibootmgr apparmor bash-completion man-db man-pages dialog logrotate mtools dosfstools
pacman -S networkmanager bluez bluez-utils avahi inetutils dnsutils wireless_tools
pacman -S openssh sshfs fuse3 rsync curl wget
#pacman -S pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber
pacman -S pulseaudio pulseaudio-alsa pulseaudio-bluetooth pulseaudio-jack
pacman -S mesa intel-media-driver vulkan-intel xf86-input-synaptics
pacman -S nftables flatpak cups cups-pdf haveged
echo "finished package download"

# Enable basic services
systemctl enable apparmor
systemctl enable cups
systemctl enable sshd
systemctl enable avahi-daemon
systemctl enable fstrim.timer
systemctl enable haveged
systemctl enable logrotate.timer
systemctl enable NetworkManager
systemctl enable wpa_supplicant
systemctl enable bluetooth
systemctl enable systemd-boot-update
systemctl enable systemd-timesyncd
echo "systemd services enabled"

# ###########
# Boot loader
# ###########

# Install boot loader
pacman -S efibootmgr intel-ucode dosfstools mtools
bootctl --path=/boot install
cat << EOF > /boot/loader/loader.conf
timeout 3
console-mode max
default arch.conf
EOF
echo "created loader.conf"

# The line below will write <part-uuid> into arch.conf
partuuid=$(blkid | awk 'match($0,/^.*nvme0n1p2.*PARTUUID="([a-f0-9\-]+)"$/,a){print a[1]}')
cat << EOF > /boot/loader/entries/arch.conf
title Arch Linux
linux /vmlinuz-linux
initrd /intel-ucode.img
initrd /initramfs-linux.img
options root=PARTUUID=$partuuid rw loglevel=3 quiet apparmor=1 lsm=lockdown,yama,apparmor
EOF
echo "created arch.conf"

# Create fall-back
cat /boot/loader/entries/arch.conf | sed 's/initramfs-linux/initramfs-linux-fallback/g' > /boot/loader/entries/arch-fallback.conf
echo "created arch-fallback.conf"

# ########
# Add user
# ########

useradd -m -G wheel narcizo
echo "narcizo:arch" | chpasswd
echo "User narcizo created, password is 'arch'. Change it at first opportunity."
