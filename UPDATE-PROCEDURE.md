# FydeTab Duo System Update Procedure

This document outlines the correct order of operations for updating your system while maintaining a custom kernel.

## Why Order Matters

The `linux-fydetab-itztweak` package may depend on specific kernel headers or module versions. Updating system packages before rebuilding the kernel can cause mismatches. Following this procedure ensures compatibility.

## Quick Reference

```
1. Backup kernel
2. Rebuild kernel
3. Install kernel
4. Update system (paru -Syu)
5. Reboot
6. Verify
```

## Detailed Steps

### Step 1: Backup Current Working Kernel

Always backup before making changes:

```sh
sudo cp /boot/vmlinuz-linux-fydetab-itztweak /boot/vmlinuz-linux-fydetab-itztweak.backup
sudo cp /boot/initramfs-linux-fydetab-itztweak.img /boot/initramfs-linux-fydetab-itztweak.img.backup
```

### Step 2: Check for Kernel Source Updates (Optional)

If you want to update to a newer kernel version, check the upstream repository:

```sh
cd ~/builds/linux-fydetab-itztweak
# Check PKGBUILD for source URL and update _commit or version if desired
```

### Step 3: Rebuild the Kernel

```sh
cd ~/builds/linux-fydetab-itztweak
./build.sh clean    # Fresh build (recommended if updating kernel version)
# OR
./build.sh          # Resume/incremental build (if just recompiling same version)
```

Wait for build to complete. Check for success:
```sh
ls -la *.pkg.tar.zst
```

### Step 4: Install the New Kernel

```sh
cd ~/builds/linux-fydetab-itztweak
sudo pacman -U linux-fydetab-itztweak-*.pkg.tar.zst
```

If you also need headers (for DKMS modules like nvidia, virtualbox, etc.):
```sh
sudo pacman -U linux-fydetab-itztweak-*.pkg.tar.zst linux-fydetab-itztweak-headers-*.pkg.tar.zst
```

### Step 5: Update System Packages

Now update the rest of the system:

```sh
paru -Syu
```

If paru tries to replace `linux-fydetab-itztweak` with a different kernel, decline or exclude it:
```sh
paru -Syu --ignore linux-fydetab-itztweak,linux-fydetab-itztweak-headers
```

### Step 6: Reboot

```sh
sudo reboot
```

### Step 7: Verify After Reboot

```sh
uname -r                    # Check kernel version
journalctl -b -p err        # Check for boot errors
dmesg | grep -i error       # Check kernel messages
```

## Troubleshooting

### System won't boot after update

See `RECOVERY.md` for U-Boot recovery procedures.

### Kernel build fails

1. Check the build log: `~/builds/linux-fydetab-itztweak/logs/build-latest.log`
2. Common fixes:
   - Clean build: `./build.sh clean`
   - Check disk space: `df -h`
   - Check memory: `free -h`

### Package conflicts during paru update

If system packages conflict with your custom kernel:
```sh
paru -Syu --ignore linux-fydetab-itztweak,linux-fydetab-itztweak-headers
```

## Maintenance Schedule

Recommended update frequency:
- **System packages (paru)**: Weekly or as needed for security updates
- **Kernel rebuild**: Only when needed (security fixes, new features, or dependency changes)

## Notes

- The kernel build takes significant time on this device. Plan accordingly.
- Build logs are saved to `~/builds/linux-fydetab-itztweak/logs/`
- Always keep a backup of the last known working kernel
