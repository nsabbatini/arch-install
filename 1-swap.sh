#!bin/bash

# Create swap file
dd if=/dev/zero of=/swapfile bs=1M count=2048 status=progress
chmod 600 /swapfile
mkswap /swapfile
echo '/swapfile none swap defaults 0 0' | tee -a /etc/fstab
