#!/bin/bash

#If you already installed CachyOS - FIX:
#lsblk and find your root partition e.g. /dev/vda2
#LOG OUT OF PLASMA
#Ctrl+Alt F3:
#Log in

sudo systemctl stop plasmalogin
sudo ls -a /var/lib/plasmalogin

sudo mkdir -p /mnt/btrfs
sudo mount -o subvolid=5 /dev/vda2 /mnt/btrfs
sudo btrfs subvolume create /mnt/btrfs/@plasmalogin

sudo rsync -aHAX --numeric-ids /var/lib/plasmalogin/ /mnt/btrfs/@plasmalogin/
sudo mv /var/lib/plasmalogin /var/lib/plasmalogin.old
sudo mkdir -p /var/lib/plasmalogin
sudo chown plasmalogin:plasmalogin /var/lib/plasmalogin
sudo chmod 0750 /var/lib/plasmalogin

sudo nano /etc/fstab
#  UUID=your-uuid-here  /var/lib/plasmalogin  btrfs  subvol=@plasmalogin,noatime,compress=zstd:3  0  0
sudo mount -av
findmnt /var/lib/plasmalogin
sudo rm -rf /var/lib/plasmalogin.old    #if all is well
sudo systemctl start plasmalogin
