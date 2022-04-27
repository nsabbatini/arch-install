#!bin/bash

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
systemctl enable gdm
echo "systemd services enabled"
