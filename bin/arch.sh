#!/bin/bash

exec &> >(tee -a "/root/arch.log")

echo "######################"
echo "Running install script"
echo "######################"
echo ""

usage() {
    echo "Usage: arch.sh [-s] [-h]"
    echo "Arch Linux installation pre-chroot"
    echo "Options:"
    echo "   -s skips disk partition, format, subvolume creation and mounting"
    echo "   -h displays command usage and quits" 
}

skip_partition="false"

while getopts "s:h" option
do
    case "$option" in
        s)
            skip_partition="true"
            ;;
        h)
            usage
            exit 0
            ;;
    esac
done

# Before running this script, define parameters in file parameters.sh
source /root/arch-install/bin/parameters.sh

echo "Checking config parameters"
[[ -z "$user" ]] && { echo "Error: variable user undefined"; exit 1; }
[[ -z "$disk" ]] && { echo "Error: variable disk undefined"; exit 1; }
[[ -z "$host" ]] && { echo "Error: variable host undefined"; exit 1; }
[[ -z "$machine" ]] && { echo "Error: variable machine undefined"; exit 1; }
[[ -z "$pkg_list" ]] && { echo "Error: variable pkg_list undefined"; exit 1; }
[[ -z "$pkg_list_extra" ]] && { echo "Error: variable pkg_list_extra undefined"; exit 1; }
[[ -z "$PL1" ]] && { echo "Error: variable PL1 undefined"; exit 1; }
[[ -z "$PL2" ]] && { echo "Error: variable PL2 undefined"; exit 1; }

if [[ $disk =~ .*sd[a-z] ]]; then
    partition1="${disk}1"
    partition2="${disk}2"
    partition3="${disk}3"
elif [[ $disk =~ .*nvme.* ]]; then
    partition1="${disk}p1"
    partition2="${disk}p2"
    partition3="${disk}p3"
elif [[ $disk =~ .*vd[a-z] ]]; then
    partition1="${disk}1"
    partition2="${disk}2"
    partition3="${disk}3"
else
    echo "Error: disk name not recognized"
    exit 1
fi

# Skipping is useful when there was a pacstrap error in a previous run"
if [[ $skip_partition == "false" ]]; then

   echo "Creating partitions on $disk"
   parted --script $disk -- \
       mklabel gpt \
       mkpart EFI fat32 2048s 1050623s \
       mkpart swap linux-swap 1050624s 9439231s \
       mkpart root btrfs 9439232s 100% \
       set 1 esp on

   echo "Formatting"
   mkfs.vfat $partition1
   mkswap $partition2
   mkfs.btrfs -f $partition3

   echo "Mounting swap partition"
   swapon $partition2

   echo "Creating btrfs subvolumes"
   mount $partition3 /mnt
   cd /mnt
   btrfs subvolume create @
   btrfs subvolume create @home
   btrfs subvolume create @opt
   btrfs subvolume create @srv
   btrfs subvolume create @cache
   btrfs subvolume create @images
   btrfs subvolume create @log
   btrfs subvolume create @spool
   btrfs subvolume create @tmp

   echo "Mounting btrfs subvolumes"
   cd /root
   umount /mnt
   btrfs_mnt_opt="noatime,ssd,space_cache=v2,compress=zstd,discard=async"
   mount -t btrfs -o ${btrfs_mnt_opt},subvol=@ $partition3 /mnt
   mkdir -p /mnt/{home,opt,srv,var/cache,var/lib/libvirt/images,var/log,var/spool,var/tmp}
   mount -t btrfs -o ${btrfs_mnt_opt},subvol=@home $partition3 /mnt/home
   mount -t btrfs -o ${btrfs_mnt_opt},subvol=@opt $partition3 /mnt/opt
   mount -t btrfs -o ${btrfs_mnt_opt},subvol=@srv $partition3 /mnt/srv
   mount -t btrfs -o ${btrfs_mnt_opt},subvol=@cache $partition3 /mnt/var/cache
   mount -t btrfs -o ${btrfs_mnt_opt},subvol=@images $partition3 /mnt/var/lib/libvirt/images
   mount -t btrfs -o ${btrfs_mnt_opt},subvol=@log $partition3 /mnt/var/log
   mount -t btrfs -o ${btrfs_mnt_opt},subvol=@spool $partition3 /mnt/var/spool
   mount -t btrfs -o ${btrfs_mnt_opt},subvol=@tmp $partition3 /mnt/var/tmp

   echo "Setting no copy on write to virtual machine images"
   chattr -VR +C /mnt/var/lib/libvirt/images

   echo "Mounting efi partition"
   mkdir -p /mnt/efi
   mount -t vfat $partition1 /mnt/efi

   echo "Running reflector"
   reflector --country 'US,DE,BR' --sort rate --fastest 5 --latest 10 --age 12 --protocol https --ipv6 --save /etc/pacman.d/mirrorlist

fi

echo "Running pacstrap"
stdbuf -oL -eL pacstrap -i /mnt base reflector
[[ $? == 0 ]] || { echo "Error: pacstrap failed, fix and rerun with -s"; exit 1; }

echo "Creating /etc/fstab"
genfstab -U -p /mnt >> /mnt/etc/fstab

echo "Copying configuration files"
rsync -v -r /root/arch-install/etc/ /mnt/etc/

echo "Configuring hostname, language, keymap"
echo $host > /mnt/etc/hostname
echo "en_US.UTF-8 UTF-8" > /mnt/etc/locale.gen
echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
echo "KEYMAP=br-latin1-us" > /mnt/etc/vconsole.conf

echo "Creating /etc/hosts"
cat << EOF > /mnt/etc/hosts
127.0.0.1 localhost
::1       localhost
EOF

echo "Creating network files"
[[ $machine == "laptop" ]] && { br0_rqd_online="no"; }
[[ $machine == "desktop" ]] && { br0_rqd_online="yes"; }

cat << EOF > /mnt/systemd/network/25-br0.network
[Match]
Name=br0

[Link]
RequiredForOnline=$br0_rqd_online

[Network]
DHCP=yes
IPv6AcceptRA=yes
Domains=localdomain

[DHCPv4]
RouteMetric=20

[IPv6AcceptRA]
RouteMetric=20
EOF

if [[ $machine == "laptop" ]]; then
cat << EOF > /mnt/systemd/network/25-wireless.network
[Match]
Name=wlan*

[Link]
RequiredForOnline=routable

[Network]
DHCP=yes
IPv6AcceptRA=yes
#IgnoreCarrierLoss=3s
Domains=localdomain

[DHCPv4]
RouteMetric=40
# The ethernet interface will have the normal hostname
# The wifi interface will inform the dhcp server a different name
Hostname=${host}w

[IPv6AcceptRA]
RouteMetric=40
EOF
fi

echo "Enabling avahi to handle mdns instead of systemd-resolved"
sed -Ei 's/^(hosts.*) (resolve.*)$/\1 mdns4_minimal [NOTFOUND=return] \2/g' /mnt/etc/nsswitch.conf
[[ -d /mnt/etc/systemd/resolved.conf.d ]] || { mkdir -p /mnt/etc/systemd/resolved.conf.d; }
cat << EOF > /mnt/etc/systemd/resolved.conf.d/mdns.conf
[Resolve]
MulticastDNS=no
EOF

# Environment variables to force Nvidia GBM (Generic Buffer Management)
# See https://linuxiac.com/nvidia-with-wayland-on-arch-setup-guide/
write_nvidia_config_files() {
cat << EOF > /mnt/etc/environment
GBM_BACKEND=nvidia-drm
__GLX_VENDOR_LIBRARY_NAME=nvidia
EOF
}

if [[ $machine == "desktop" ]]; then
    echo "Configuring NVIDIA"
    # Nvidia modules in mkinitcpio (early start) are required if the gui is started before the driver is loaded.
    # The problem is that early start of nvidia drivers will not be able to load saved video memory.
    #sed -Ei 's/^MODULES=\(\)/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/g' /mnt/etc/mkinitcpio.conf
    # Removing the kms hook is needed to prevent the kernel from loading the nouvaeu driver
    sed -Ei 's/^(HOOKS.*) kms (.*)$/\1 \2/g' /mnt/etc/mkinitcpio.conf
    write_nvidia_config_files
fi

echo "Configuring smartctl"
echo "$disk -a -o on -S on -s (S/../.././02|L/../../6/03)" > /mnt/etc/smartd.conf

echo "Configuring CPU power limits"
[[ -d /mnt/etc/tmpfiles.d ]] || { mkdir -p /mnt/etc/tmpfiles.d; }
cat << EOF > /mnt/etc/tmpfiles.d/energy_performance_preference.conf
w /sys/class/powercap/intel-rapl:0/constraint_0_power_limit_uw - - - - $PL1
w /sys/class/powercap/intel-rapl:0/constraint_1_power_limit_uw - - - - $PL2
w /sys/class/powercap/intel-rapl:0/enabled - - - - 1
EOF

echo "Copying install scripts to run post-chroot"
cp -r /root/arch-install /mnt/root/

echo ""
echo "##########################"
echo "Finished pre-chroot script"
echo "##########################"
echo ""

exit 0
