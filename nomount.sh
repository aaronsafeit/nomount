Copyright (c) 2025 Aaron A. Dennis

Licensed under the MIT License. See LICENSE file for details

#!/bin/bash

# Step 1: Disable Auto-Mounting of External Drives

# Disable auto-mounting for GNOME desktop environment
gsettings set org.gnome.desktop.media-handling automount false
gsettings set org.gnome.desktop.media-handling automount-open false

# Disable auto-mounting for XFCE desktop environment
xfconf-query -c thunar-volman -p /automount-drives/enabled -s false
xfconf-query -c thunar-volman -p /automount-media/enabled -s false
xfconf-query -c thunar-volman -p /autobrowse/enabled -s false

# Disable auto-mounting for MATE desktop environment
gsettings set org.mate.media-handling automount false

# Step 2: Prevent Writing to External Drives

# Blacklist USB storage module to prevent loading
echo "blacklist usb-storage" | sudo tee /etc/modprobe.d/usb-storage.conf

# Set all detected disks to read-only
for disk in /dev/sd* /dev/nvme* /dev/mmcblk*; do
  if [ -b "$disk" ]; then
    sudo blockdev --setro "$disk"
  fi
done

# Step 3: Mask Auto-Mounting Services

# Mask udisks2 service to prevent automatic mounting
sudo systemctl mask udisks2.service
sudo systemctl mask udisks2.socket

# Mask autofs service to prevent automatic mounting
sudo systemctl mask autofs.service

# Step 4: Update /etc/fstab for External Drives

# Get the UUID of the boot disk
boot_uuid=$(lsblk -o NAME,UUID,MOUNTPOINT | grep '/$' | awk '{print $2}')

# Backup the current /etc/fstab
cp /etc/fstab /etc/fstab.bak

# Loop through all connected disks
for disk in /dev/sd* /dev/nvme* /dev/mmcblk*; do
  # Skip the boot disk
  if [ "$(lsblk -o NAME,UUID | grep "$disk" | awk '{print $2}')" == "$boot_uuid" ]; then
    continue
  fi

  # Get the UUID of the disk
  uuid=$(lsblk -o NAME,UUID | grep "$disk" | awk '{print $2}')

  # Skip if UUID is empty (e.g., unformatted or no partition)
  if [ -z "$uuid" ]; then
    continue
  fi

  # Create a mount point
  mount_point="/media/$(basename $disk)"
  mkdir -p "$mount_point"

  # Add the entry to /etc/fstab
  echo "UUID=$uuid $mount_point auto ro,noauto,x-gvfs-show 0 0" | sudo tee -a /etc/fstab
done

# Reload fstab
sudo mount -a

echo "Configuration complete. External drives are now read-only and will not auto-mount."

