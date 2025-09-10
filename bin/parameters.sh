#!bin/bash

####################################################
# Adjust these parameters before running the scripts
####################################################

#user="narcizo"

#disk="/dev/sda"
#disk="/dev/nvme0n1"

# hostname
#host="lince"
#host="castor"

# The install scripts assume the following
#   - a desktop will have Nvidia, wifi and steam (32-bit libs)
#   - a laptop will have wifi and an integrated Intel gpu
#machine="laptop"
#machine="desktop"

# Packages list
pkg_list="/root/arch-install/bin/pkg_list.txt"
#pkg_list_extra="/root/arch-install/bin/pkg_list_laptop.txt"
#pkg_list_extra="/root/arch-install/bin/pkg_list_desktop.txt"

# Power limits
# This is for i9-9900K (castor)
#PL1=120000000
#PL2=210000000
# This is for i7-10710U (lince)
#PL1=15000000
#PL2=45000000
