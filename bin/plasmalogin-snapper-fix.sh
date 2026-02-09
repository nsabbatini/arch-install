#!/bin/bash

sudo mkdir -p /mnt/btrfs
sudo mount -o subvolid=5 /dev/nvme0n1p3 /mnt/btrfs
sudo btrfs subvolume create /mnt/btrfs/@plasmalogin
sudo umount /mnt/btrfs
sudo rmdir /mnt/btrfs

sudo mkdir -p /var/lib/plasmalogin
#sudo useradd -M -r -s /bin/false plasmalogin
#sudo chown plasmalogin:plasmalogin /var/lib/plasmalogin
#sudo chmod 0750 /var/lib/plasmalogin

sudo vim /etc/fstab
#  UUID=your-uuid-here  /var/lib/plasmalogin  btrfs  subvol=@plasmalogin,noatime,compress=zstd:3  0  0
sudo systemctl daemon-reload
sudo mount -av
findmnt /var/lib/plasmalogin
