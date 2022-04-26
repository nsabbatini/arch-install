#!bin/bash

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

