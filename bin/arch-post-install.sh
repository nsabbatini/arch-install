#!/bin/bash

[[ $# -eq 0 ]] && { echo "No parameters supplied"; exit 1; }

cifs_user=$1
cifs_passwd=$2
brother_ip=$3

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

# Create credentias for the NAS smb mounts
cat << EOF > ~/.cifs_creds
username=$cifs_user
password=$cifs_passwd
EOF

# Configure scanner and service to accept scan initiated remotely on the scanner.
# Scans initiated remotely are stored in /srv/brscan-skey/brscan, under user brscan-skey,
# need to open port UDP 54925 on the firewall. To facilitate handling files in
# /srv/brscan-skey, we put the main user into brscan-skey group.
ping -c 1 $brother_ip > /dev/null 2>&1
if [ $? -eq 0 ]; then
   sudo brsaneconfig4 -a name=brscanner model=Brother_DCP_B7520DW ip=$brother_ip
   brsaneconfig4 -q
   sudo systemctl enable --now brscan-skey
   sudo /opt/brother/scanner/brscan-skey/brscan-skey -u $USER
   sudo usermod -a -G brscan-skey $USER
else
   echo "Error: could not configure Brother scanner because it is unreachable"
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
   # Need to ran with sudo to preserve ownership
   sudo rsync -a --stats $src_dir/ $dst_dir/
else
   echo "Could not access backup source dir"
   exit 1
fi

exit 0
