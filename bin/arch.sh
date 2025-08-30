#!/bin/bash

echo "######################"
echo "Running install script"
echo "######################"
echo ""

# Before running this script, define parameters in file parameters.sh
source /root/arch-install/bin/parameters.sh

echo "Checking config parameters..."
[[ -z "$user" ]] && { echo "Error: variable user undefined"; exit 1; }
[[ -z "$disk" ]] && { echo "Error: variable disk undefined"; exit 1; }
[[ -z "$host" ]] && { echo "Error: variable host undefined"; exit 1; }
[[ -z "$gpu" ]] && { echo "Error: variable gpu undefined"; exit 1; }
[[ -z "$PL1" ]] && { echo "Error: variable PL1 undefined"; exit 1; }
[[ -z "$PL2" ]] && { echo "Error: variable PL2 undefined"; exit 1; }
[[ -z "$pkg_list" ]] && { echo "Error: variable pkg_list undefined"; exit 1; }
[[ -z "$pkg_list_extra" ]] && { echo "Error: variable pkg_list_extra undefined"; exit 1; }
[[ -z "$multilib" ]] && { echo "Error: variable multilib undefined"; exit 1; }
echo "Done"

echo "Creating partitions on $disk..."
parted --script $disk -- \
    mklabel gpt \
    mkpart EFI fat32 2048s 1050623s \
    mkpart swap linux-swap 1050624s 9439231s \
    mkpart root btrfs 9439232s 100% \
    set 1 esp on
echo "Done"

echo "Format & mount partitions, create subvolumes..."

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

# Format partitions
mkfs.vfat $partition1
mkswap $partition2
mkfs.btrfs $partition3

# Mount swap partition
swapon $partition2

# Create btrfs subvolumes
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

# Create directories for subvolumes and mount them
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

# Set 'no copy on write' to virtual machine images
chattr -VR +C /mnt/var/lib/libvirt/images

# mount EFI partition
mkdir -p /mnt/efi
mount -t vfat $partition1 /mnt/efi

echo "Done"

if [[ "$multlib" == "enabled" ]]; then
   echo "Enabling multilib packages"
   sed -Ei '/^#\[multilib\]/ {s/^#//; n; s/^#//}' /etc/pacman.conf
   pacman -Sy
   echo "Done"
fi

# For some packages, pacman asks us to choose from different repositories.
# The default pacman config allows for 5 parallel download, so the queries
# to choose repositories can be out of order with the input prompts.
# Therefore we have to prohibit parallel downloads (unfortunatly).
sed -Ei 's/^ParallelDownloads/#ParallelDownloads/g' /etc/pacman.conf

echo "Downloading packages..."
cat $pkg_list $pkg_list_extra | sed -E '/^#/d' | sed -E '/^\s*$/d' |  pacstrap -i /mnt -
echo "Done"

echo "Creating /etc/fstab..."
genfstab -U -p /mnt >> /mnt/etc/fstab
echo "Done"

echo "Copying configuration files..."
rsync -v -r /root/arch-install/etc/ /mnt/etc/
echo "Done"

echo "Configuring hostname, language, keymap..."
echo $host > /mnt/etc/hostname
echo "en_US.UTF-8 UTF-8" > /mnt/etc/locale.gen
echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
echo "KEYMAP=br-latin1-us" > /mnt/etc/vconsole.conf
echo "Done"

echo "Creating /etc/hosts..."
cat << EOF > /mnt/etc/hosts
127.0.0.1 localhost
::1       localhost
EOF
echo "Done"

echo "Enabling avahi to handle mdns instead of systemd-resolved..."
sed -Ei 's/^(hosts.*) (resolve.*)$/\1 mdns4_minimal [NOTFOUND=return] \2/g' /mnt/etc/nsswitch.conf
[[ -d /mnt/etc/systemd/resolved.conf.d ]] || { mkdir -p /mnt/etc/systemd/resolved.conf.d; }
cat << EOF > /mnt/etc/systemd/resolved.conf.d/mdns.conf
[Resolve]
MulticastDNS=no
EOF
echo "Done"

# Environment variables to force Nvidia GBM (Generic Buffer Management)
# See https://linuxiac.com/nvidia-with-wayland-on-arch-setup-guide/
write_nvidia_config_files() {
cat << EOF > /mnt/etc/environment
GBM_BACKEND=nvidia-drm
__GLX_VENDOR_LIBRARY_NAME=nvidia
EOF
}

if [[ $gpu == "nvidia" ]]; then
    echo "Configuring NVIDIA..."
    # Nvidia modules in mkinitcpio (early start) are required if the gui is started before the driver is loaded.
    # The problem is that early start of nvidia drivers will not be able to load saved video memory.
    #sed -Ei 's/^MODULES=\(\)/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/g' /mnt/etc/mkinitcpio.conf
    # Removing the kms hook is needed to prevent the kernel from loading the nouvaeu driver
    sed -Ei 's/^(HOOKS.*) kms (.*)$/\1 \2/g' /mnt/etc/mkinitcpio.conf
    write_nvidia_config_files
    echo "Done"
fi

echo "Configuring smartctl..."
echo "$disk -a -o on -S on -s (S/../.././02|L/../../6/03)" > /mnt/etc/smartd.conf
echo "Done"

echo "Configuring CPU power limits..."
[[ -d /mnt/etc/tmpfiles.d ]] || { mkdir -p /mnt/etc/tmpfiles.d; }
cat << EOF > /mnt/etc/tmpfiles.d/energy_performance_preference.conf
w /sys/class/powercap/intel-rapl:0/constraint_0_power_limit_uw - - - - $PL1
w /sys/class/powercap/intel-rapl:0/constraint_1_power_limit_uw - - - - $PL2
w /sys/class/powercap/intel-rapl:0/enabled - - - - 1
EOF
echo "Done"

echo "Copying install data to run under chroot..."
cp -r /root/arch-install /mnt/root/
echo "Done"

echo "Invoking install script to be run under chroot..."
arch-chroot /mnt bash -c "/root/arch-install/bin/arch-chroot.sh > >(tee -a /root/arch-chroot.stdout.log) 2> >(tee -a /root/arch-chroot.stderr.log >&2)"
echo "Done"

echo ""
echo "#######################"
echo "Finished install script"
echo "#######################"

exit 0
