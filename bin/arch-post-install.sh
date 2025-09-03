#!/bin/bash

host=$(hostname)

# Fix systemd-resolved (this cannot be done by the install script because arch-chroot
# puts its own link in /etc/resolv.conf)
sudo rm /etc/resolv.conf
sudo ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf

# Install yay
mkdir /home/$USER/aur; cd /home/$USER/aur
git clone https://aur.archlinux.org/yay-bin.git
cd yay-bin; makepkg -si; cd /home/$USER

# Install AUR software
yay -S --batchinstall btrfs-assistant google-chrome librewolf-bin \
       yubico-authenticator-bin spotify etcher-bin downgrade konsave \
       otf-ibm-plex brother-dcp-b7520dw brscan4 brscan-skey gtk2
sudo systemctl enable --now pcscd.socket

# For the desktop (gaming machine)
if [[  $host == "castor" ]]; then
   yay -S heroic-games-launcher-bin protontricks
fi

# Configure btrfs and snapper
sudo btrfs filesystem label / ARCH
sudo snapper -c root create-config /
sudo snapper -c root set-config ALLOW_USERS="$USER" SYNC_ACL=yes
sudo snapper -c root create --description "Fresh after install"

# Restore backup to the home directory
src_dir="/mnt/backup/$host.localdomain/daily.0/$USER"
dst_dir="/home/$USER"
if [[ -d $src_dir ]]; then
   rsync -av $src_dir/ $dst_dir/
else
   echo "Could not access backup source dir"
   exit 1
fi

exit 0
