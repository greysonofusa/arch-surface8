#!/usr/bin/env bash
set -euo pipefail

### SAFETY CHECK ###
[[ "$(id -u)" -eq 0 ]] || { echo "Run as root"; exit 1; }

DISK="/dev/nvme0n1"
VG="ArchVG"
LV="root"

echo "=== Surface Pro 8 Arch Installer ==="

### USER INPUT ###
read -rp "Enter hostname: " HOSTNAME
read -rp "Enter username: " USERNAME

echo "Set ROOT password:"
passwd

echo "Set password for $USERNAME:"
read -rsp "Password: " USERPASS
echo
read -rsp "Confirm: " CONFIRM
echo
[[ "$USERPASS" == "$CONFIRM" ]] || { echo "Passwords do not match"; exit 1; }

read -rp "Grant $USERNAME sudo privileges? (y/n): " SUDO_OK

### TIME SYNC ###
timedatectl set-ntp true

### DISK PARTITIONING ###
echo "Partitioning disk..."
wipefs -af "$DISK"
sgdisk -Z "$DISK"

sgdisk -n 1:0:+1G -t 1:ef00 "$DISK"
sgdisk -n 2:0:0   -t 2:8e00 "$DISK"

partprobe "$DISK"

### FILESYSTEMS ###
mkfs.fat -F32 "${DISK}p1"

pvcreate "${DISK}p2"
vgcreate "$VG" "${DISK}p2"
lvcreate -l 100%FREE -n "$LV" "$VG"

mkfs.f2fs "/dev/$VG/$LV"

### MOUNTS ###
mount "/dev/$VG/$LV" /mnt
mkdir -p /mnt/efi
mount "${DISK}p1" /mnt/efi

### BASE INSTALL ###
pacstrap /mnt \
  base base-devel \
  linux-firmware \
  sudo \
  git \
  vim \
  networkmanager \
  sbctl \
  efibootmgr

genfstab -U /mnt >> /mnt/etc/fstab

### CHROOT ###
arch-chroot /mnt /bin/bash <<EOF

set -e

### SYSTEM CONFIG ###
echo "$HOSTNAME" > /etc/hostname

ln -sf /usr/share/zoneinfo/America/Chicago /etc/localtime
hwclock --systohc

sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen

echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=us" > /etc/vconsole.conf

### USERS ###
useradd -m -G wheel $USERNAME
echo "$USERNAME:$USERPASS" | chpasswd

if [[ "$SUDO_OK" =~ ^[Yy]$ ]]; then
  sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
fi

### NETWORK ###
systemctl enable NetworkManager

### LINUX-SURFACE KEYS ###
curl -s https://raw.githubusercontent.com/linux-surface/linux-surface/master/pkg/keys/surface.asc \
  | pacman-key --add -

pacman-key --finger 56C464BAAC421453
pacman-key --lsign-key 56C464BAAC421453

cat <<SURFACE >> /etc/pacman.conf

[linux-surface]
Server = https://pkg.surfacelinux.com/arch/
SURFACE

pacman -Syu --noconfirm

### KERNEL + FIRMWARE ###
pacman -S --noconfirm \
  linux-surface \
  linux-surface-headers \
  iptsd \
  linux-firmware-intel \
  linux-firmware-marvell

systemctl enable iptsd

### COSMIC ###
pacman -S --noconfirm \
  cosmic \
  cosmic-session \
  cosmic-greeter \
  greetd

cat <<GREET > /etc/greetd/config.toml
[terminal]
vt = 1

[default_session]
command = "cosmic-greeter"
user = "greeter"
GREET

systemctl enable greetd

### GAMING + PERFORMANCE ###
pacman -S --noconfirm \
  steam \
  gamescope \
  gamemode \
  lib32-gamemode \
  mesa \
  vulkan-intel \
  intel-media-driver \
  thermald \
  zram-generator

systemctl enable gamemoded thermald

cat <<PERF > /etc/environment
MESA_GLTHREAD=true
ANV_QUEUE_THREAD_DISABLE=1
INTEL_DEBUG=noccs
PERF

cat <<SYSCTL > /etc/sysctl.d/99-surface.conf
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.dirty_ratio=10
vm.dirty_background_ratio=5
SYSCTL

cat <<ZRAM > /etc/systemd/zram-generator.conf
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
ZRAM

### UKI ###
ROOT_UUID=\$(blkid -s UUID -o value \$(findmnt -no SOURCE /))

mkdir -p /etc/kernel/cmdline
echo "root=UUID=\$ROOT_UUID rw quiet splash" > /etc/kernel/cmdline/root.conf

cat <<UKI > /etc/mkinitcpio.d/linux-surface.preset
ALL_config="/etc/mkinitcpio.conf"
ALL_kver="/usr/lib/modules/%k"
PRESETS=('default')
default_uki="/efi/EFI/Linux/arch-linux-surface.efi"
UKI

mkinitcpio -P

### SECURE BOOT ###
sbctl create-keys
sbctl enroll-keys --microsoft
sbctl sign /efi/EFI/Linux/arch-linux-surface.efi

bootctl install

EOF

### FINISH ###
umount -R /mnt
echo "=== INSTALL COMPLETE ==="
echo "Reboot, enable Secure Boot, enroll keys when prompted."