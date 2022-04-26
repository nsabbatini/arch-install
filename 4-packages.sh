#!bin/bash

echo "initating pakage download"
pacman -S efibootmgr apparmor bash-completion man-db man-pages dialog logrotate mtools dosfstools
pacman -S networkmanager bluez bluez-utils avahi inetutils dnsutils wireless_tools
pacman -S openssh sshfs fuse3 rsync curl wget
pacman -S pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber
#pacman -S pulseaudio pulseaudio-alsa pulseaudio-bluetooth pulseaudio-jack
pacman -S mesa intel-media-driver vulkan-intel xf86-input-synaptics
pacman -S nftables flatpak cups cups-pdf haveged
echo "finished package download"
