# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This repository contains Arch Linux ARM PKGBUILDs for running ArchLinuxARM on the FydeTab Duo tablet (Rockchip RK3588-based device). Each subdirectory is an independent package with its own PKGBUILD.

## Build Commands

Prerequisites:
```sh
sudo pacman -S base-devel
```

Build and install a package:
```sh
cd <package-directory>
makepkg -si
```

Build without installing:
```sh
makepkg -s
```

Rebuild with existing sources:
```sh
makepkg -sf
```

## Package Categories

**Core System:**
- `linux-fydetab/` - Custom Linux 6.1 kernel for RK3588 (builds kernel + headers packages)
- `mutter/` - GNOME compositor with custom orientation patch

**Firmware:**
- `mali-G610-firmware-rkr4/` - Mali G610 GPU firmware
- `ap6275p-firmware/` - WiFi/Bluetooth firmware for AP6275P module

**Device Configuration:**
- `fydetabduo-post-install/` - Device-specific systemd services, udev rules, display fixes
- `calamares-settings/` - Installer configuration

**Bootloader:**
- `grub/` - Custom GRUB with DTB support and EFI configurations
- `grub-btrfs/` - Btrfs snapshot boot menu integration

**Utilities:**
- `calamares/` - System installer framework (has custom patches for paru/AUR support)
- `gnome-shell-extension-gjs-osk/` - On-screen keyboard extension
- `ckbcomp/` - XKB keyboard compiler

## Architecture Notes

- Target architecture is aarch64 (ARM64)
- Kernel sources come from `Linux-for-Fydetab-Duo/linux-rockchip` (noble-panthor branch)
- The `mutter/` package includes a patch preventing automatic screen orientation reset
- `fydetabduo-post-install/` contains most hardware-specific fixes (touch firmware, display rotation, Bluetooth)

## Kernel Build Workflow

The kernel build uses a script that captures logs and system diagnostics for crash analysis.

**To build the kernel:**
```sh
cd linux-fydetab
./build.sh        # Resume/continue build
./build.sh clean  # Fresh build (removes src/pkg first)
```

**Logs are saved to:** `linux-fydetab/logs/`
- `build-latest.log` - Build output (symlink to most recent)
- `system-latest.log` - System state, memory, temps, dmesg (symlink to most recent)
- Timestamped versions are preserved for history

**If the machine crashes during build:**
1. Reboot and start Claude
2. Tell Claude: "Analyze the kernel build logs"
3. Claude will read `logs/build-latest.log` and `logs/system-latest.log`

**If build fails with errors:**
- Same process - Claude will identify the error and suggest fixes

**Known issues fixed in config:**
- `CONFIG_TRUSTED_KEYS=n` - Disabled to avoid ASN.1 decoder build race condition (no TPM on device anyway)

## SD Card Boot Log Analysis

When testing kernel changes on the SD card, access boot journals from the mounted SD:

**Mount location:** `/run/media/$USER/ROOTFS/`
- Btrfs subvolumes: `@`, `@home`, `@log`, `@pkg`, `@.snapshots`

**Journal location:** `/run/media/$USER/ROOTFS/@log/journal/<machine-id>/`

**Commands to analyze SD card boots:**
```bash
# Find the machine-id directory
ls /run/media/$USER/ROOTFS/@log/journal/

# List all boots on the SD card
journalctl --file=/run/media/$USER/ROOTFS/@log/journal/<machine-id>/system.journal --list-boots

# Get GPU-related logs from most recent boot
journalctl --file=/run/media/$USER/ROOTFS/@log/journal/<machine-id>/system.journal -b 0 -k | grep -iE "panthor|panfrost|mali|gpu"

# Get GNOME/GDM logs from user journal
journalctl --file=/run/media/$USER/ROOTFS/@log/journal/<machine-id>/user-1001.journal -b 0 | grep -iE "gnome-shell|MESA|dri|EGL"

# Get all error-level messages
journalctl --file=/run/media/$USER/ROOTFS/@log/journal/<machine-id>/system.journal -b 0 -p err
```

**Note:** The machine-id is a hex string like `b74ea1e0717e4a1c90ab6a30114b905e`
