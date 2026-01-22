#!/usr/bin/env bash
su
#Enter Super User Password!
pacman -Syy
pacman -S --no-confirm ufw git NetworkManager curl nano
curl -s https://raw.githubusercontent.com/linux-surface/linux-surface/master/pkg/keys/surface.asc \
    | pacman-key --add -
    pacman-key --finger 56C464BAAC421453
    pacman-key --lsign-key 56C464BAAC421453  
cat > /etc/pacman.conf <<EOF
[linux-surface]
Server = https://pkg.surfacelinux.com/arch/
EOF
pacman -Syu
pacman -S --no-confirm linux-surface linux-surface-headers iptsd linux-firmware-intel sbctl
mkinitcpio -P
sbctl create-keys
sbctl enroll-keys -m
sbctl sign -s /boot/EFI/Linux/arch-linux.efi
efibootmgr --create --disk /dev/nvme0n1 --part 1 --label "Arch Surface" --loader /EFI/Linux/arch-linux.efi --verbose
systemctl enable ufw
systemctl start ufw
ufw enable
ufw default deny incoming
ufw default allow outgoing
pacman -S --no-confirm steam lib32-mesa lib32-vulkan-intel vulkan-tools lib32-vulkan-icd-loader lib32-gcc-libs gamemode lib32-gamemode ttf-liberation intel-media-driver lib32-intel-media-driver libva-utils thermald
systemctl enable --now thermald
dd if=/dev/zero of=/swapfile bs=1G count=16 status=progress
chmod 0600 /swapfile
mkswap /swapfile
swapon /swapfile
sudo pacman -S cosmic
echo " This will install all Cosmic- Desktop Environment. Press Enter!
systemctl enable cosimic-greeter
reboot now
