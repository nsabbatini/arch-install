#!bin/bash

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
