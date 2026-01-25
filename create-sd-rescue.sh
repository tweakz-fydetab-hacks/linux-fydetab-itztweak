#!/bin/bash
# Create minimal rescue/test SD card with new kernel
# Usage: sudo ./create-sd-rescue.sh /dev/mmcblk1

set -e

SDCARD="${1:-/dev/mmcblk1}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKGDIR="$SCRIPT_DIR"
MOUNTPOINT="/mnt/sdrescue"
LOGFILE="$SCRIPT_DIR/logs/sd-rescue-$(date +%Y%m%d-%H%M%S).log"

# Ensure log directory exists
mkdir -p "$SCRIPT_DIR/logs"

# Log to both terminal and file
exec > >(tee -a "$LOGFILE") 2>&1

echo "=== Log file: $LOGFILE ==="
echo "=== Started: $(date) ==="

if [[ ! -b "$SDCARD" ]]; then
    echo "Error: $SDCARD is not a block device"
    exit 1
fi

if [[ "$SDCARD" == *"mmcblk0"* ]]; then
    echo "Error: Refusing to write to mmcblk0 (your eMMC!)"
    exit 1
fi

echo "=== Creating rescue SD on $SDCARD ==="
echo "WARNING: This will ERASE all data on $SDCARD"
read -p "Continue? [y/N] " confirm
[[ "$confirm" == "y" ]] || exit 1

# Unmount any existing partitions
umount ${SDCARD}p* 2>/dev/null || true
umount ${SDCARD}* 2>/dev/null || true
umount "$MOUNTPOINT" 2>/dev/null || true

echo "=== Partitioning ==="
# Create partition table matching eMMC layout
parted -s "$SDCARD" mklabel gpt
parted -s "$SDCARD" mkpart primary fat32 1MiB 33MiB    # Partition 1: 32MB (unused, matches eMMC)
parted -s "$SDCARD" mkpart primary ext4 33MiB 32GiB    # Partition 2: 32GB root
parted -s "$SDCARD" set 2 boot on

# Wait for kernel to recognize partitions
sleep 2
partprobe "$SDCARD"
sleep 1

echo "=== Formatting ==="
mkfs.ext4 -L rescue_root "${SDCARD}p2"

echo "=== Mounting ==="
mkdir -p "$MOUNTPOINT"
mount "${SDCARD}p2" "$MOUNTPOINT"

echo "=== Copying minimal system ==="
# Create directory structure
mkdir -p "$MOUNTPOINT"/{boot,bin,sbin,etc,lib,usr,var,tmp,root,home,mnt,proc,sys,dev,run}
mkdir -p "$MOUNTPOINT"/usr/{bin,sbin,lib,share}
mkdir -p "$MOUNTPOINT"/var/{log,tmp}

# Copy boot files from current system
echo "  -> Boot files..."
cp -a /boot/boot.scr.uimg "$MOUNTPOINT/boot/"
cp -a /boot/dtbs "$MOUNTPOINT/boot/"

# Extract NEW kernel package directly
echo "  -> New kernel from package..."
KERNELPKG=$(ls "$PKGDIR"/linux-fydetab-itztweak-6.1.75-*.pkg.tar.zst 2>/dev/null | grep -v headers | head -1)
if [[ -f "$KERNELPKG" ]]; then
    bsdtar -xf "$KERNELPKG" -C "$MOUNTPOINT"
    echo "    Installed: $KERNELPKG"
    # Create kernel symlink that mkinitcpio expects (pacman hooks normally do this)
    ln -sf /usr/lib/modules/*/vmlinuz "$MOUNTPOINT/boot/vmlinuz-linux-fydetab-itztweak"
else
    echo "Error: Kernel package not found in $PKGDIR"
    exit 1
fi

# Copy essential binaries and libraries
# Exclude large unnecessary packages for rescue system
EXCLUDE_PATTERNS=(
    --exclude='*.a'
    --exclude='libLLVM*'
    --exclude='libclang*'
    --exclude='libwebkit*'
    --exclude='libjavascriptcore*'
    --exclude='libicu*'
    --exclude='libQt5*'
    --exclude='libQt6*'
    --exclude='libgtk-4*'
    --exclude='libadwaita*'
    --exclude='libmutter*'
    --exclude='libgjs*'
    --exclude='libgnome-shell*'
    --exclude='libreoffice*'
    --exclude='firefox*'
    --exclude='chromium*'
    --exclude='electron*'
    --exclude='thunderbird*'
    --exclude='*/locale/*'
    --exclude='*/doc/*'
    --exclude='*/man/*'
    --exclude='*/gtk-doc/*'
    --exclude='*/help/*'
    --exclude='__pycache__'
    --exclude='*.pyc'
)

echo "  -> Core utilities..."
rsync -a /bin/ "$MOUNTPOINT/bin/"
rsync -a /sbin/ "$MOUNTPOINT/sbin/"
rsync -a "${EXCLUDE_PATTERNS[@]}" /usr/bin/ "$MOUNTPOINT/usr/bin/"
rsync -a /usr/sbin/ "$MOUNTPOINT/usr/sbin/"

echo "  -> Libraries (excluding large GUI libs)..."
rsync -a /lib/ "$MOUNTPOINT/lib/"
rsync -a "${EXCLUDE_PATTERNS[@]}" /usr/lib/ "$MOUNTPOINT/usr/lib/"

echo "  -> Essential config..."
# Copy minimal etc
cp -a /etc/passwd "$MOUNTPOINT/etc/"
cp -a /etc/shadow "$MOUNTPOINT/etc/"
cp -a /etc/group "$MOUNTPOINT/etc/"
cp -a /etc/fstab "$MOUNTPOINT/etc/"
cp -a /etc/hostname "$MOUNTPOINT/etc/"
cp -a /etc/hosts "$MOUNTPOINT/etc/"
cp -a /etc/resolv.conf "$MOUNTPOINT/etc/" 2>/dev/null || true
cp -a /etc/locale.conf "$MOUNTPOINT/etc/" 2>/dev/null || true
cp -a /etc/localtime "$MOUNTPOINT/etc/" 2>/dev/null || true
cp -a /etc/os-release "$MOUNTPOINT/etc/"
cp -a /etc/mkinitcpio.conf "$MOUNTPOINT/etc/"
cp -a /etc/mkinitcpio.d "$MOUNTPOINT/etc/"
cp -a /etc/pacman.conf "$MOUNTPOINT/etc/"
cp -a /etc/pacman.d "$MOUNTPOINT/etc/"
cp -a /etc/systemd "$MOUNTPOINT/etc/" 2>/dev/null || true
cp -a /etc/bash.bashrc "$MOUNTPOINT/etc/" 2>/dev/null || true
cp -a /etc/profile "$MOUNTPOINT/etc/" 2>/dev/null || true
cp -a /etc/profile.d "$MOUNTPOINT/etc/" 2>/dev/null || true

# Modify fstab for SD card
echo "  -> Adjusting fstab..."
# Comment out the eMMC root, add SD root
sed -i 's|^UUID=|#UUID=|g' "$MOUNTPOINT/etc/fstab"
sed -i 's|^PARTUUID=|#PARTUUID=|g' "$MOUNTPOINT/etc/fstab"
echo "# SD card root" >> "$MOUNTPOINT/etc/fstab"
echo "LABEL=rescue_root / ext4 rw,relatime 0 1" >> "$MOUNTPOINT/etc/fstab"

# Generate initramfs for the SD card
echo "  -> Generating initramfs..."
# We need to chroot to generate proper initramfs
mount --bind /proc "$MOUNTPOINT/proc"
mount --bind /sys "$MOUNTPOINT/sys"
mount --bind /dev "$MOUNTPOINT/dev"
chroot "$MOUNTPOINT" mkinitcpio -p linux-fydetab-itztweak
umount "$MOUNTPOINT/dev"
umount "$MOUNTPOINT/sys"
umount "$MOUNTPOINT/proc"

echo "=== Setting root password ==="
echo "  -> Setting root password to 'rescue' for SD boot"
chroot "$MOUNTPOINT" bash -c 'echo "root:rescue" | chpasswd'

echo "=== Disk usage ==="
df -h "$MOUNTPOINT"

echo "=== Cleanup ==="
sync
umount "$MOUNTPOINT"

echo ""
echo "=== DONE ==="
echo "=== Finished: $(date) ==="
echo "Rescue SD created on $SDCARD"
echo ""
echo "To test: Power off, insert SD, power on"
echo "U-Boot should boot from SD before eMMC"
echo "Root password: rescue"
echo ""
echo "If boot fails, remove SD and system boots from eMMC as normal"
echo ""
echo "Log saved to: $LOGFILE"
