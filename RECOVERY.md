# FydeTab Duo Boot Recovery

This document covers recovery procedures when the system fails to boot after a kernel update.

## Boot Process Overview

The FydeTab Duo uses U-Boot as its bootloader. The boot sequence:

1. U-Boot initializes from SPI flash
2. U-Boot reads `/boot/boot.scr.uimg` (boot script)
3. Boot script loads:
   - `/boot/vmlinuz-linux-fydetab-itztweak` (kernel)
   - `/boot/initramfs-linux-fydetab-itztweak.img` (initramfs)
   - `/boot/dtbs/rockchip/rk3588s-fydetab-duo.dtb` (device tree)
4. Kernel boots

## Current Boot Configuration

```
Kernel:    /boot/vmlinuz-linux-fydetab-itztweak
Initramfs: /boot/initramfs-linux-fydetab-itztweak.img
DTB:       /boot/dtbs/rockchip/rk3588s-fydetab-duo.dtb
Root:      ext4, partition 2, detected by PARTUUID
Console:   ttyFIQ0 (serial) + tty1 (display)
```

## Prerequisites for Recovery

You need ONE of the following:
- USB-C serial debug cable (connects to the debug USB-C port)
- Bootable SD card or USB drive with a working Linux system
- Another computer to mount the eMMC (requires opening the device)

## Recovery Option 1: Serial Console (Recommended)

### Requirements
- USB-C serial debug cable (3.3V TTL)
- Terminal program (minicom, screen, picocom)

### Procedure

1. Connect serial cable to debug USB-C port (not the charging port)

2. Open terminal at 1500000 baud:
   ```sh
   picocom -b 1500000 /dev/ttyUSB0
   # OR
   screen /dev/ttyUSB0 1500000
   ```

3. Power on the device and quickly press a key to interrupt U-Boot

4. At the U-Boot prompt, boot from backup:
   ```
   setenv linux_image /boot/vmlinuz-linux-fydetab-itztweak.backup
   setenv initrd /boot/initramfs-linux-fydetab-itztweak.img.backup
   boot
   ```

5. Once booted, restore the backup permanently:
   ```sh
   sudo cp /boot/vmlinuz-linux-fydetab-itztweak.backup /boot/vmlinuz-linux-fydetab-itztweak
   sudo cp /boot/initramfs-linux-fydetab-itztweak.img.backup /boot/initramfs-linux-fydetab-itztweak.img
   ```

### Making Backup Bootable via Menu (Advanced)

You can create a boot script with a menu. Create `/boot/boot.cmd`:
```
setenv bootmenu_0 "Normal Boot=setenv linux_image /boot/vmlinuz-linux-fydetab-itztweak; setenv initrd /boot/initramfs-linux-fydetab-itztweak.img; run bootcmd_normal"
setenv bootmenu_1 "Backup Kernel=setenv linux_image /boot/vmlinuz-linux-fydetab-itztweak.backup; setenv initrd /boot/initramfs-linux-fydetab-itztweak.img.backup; run bootcmd_normal"
setenv bootmenu_delay 5
bootmenu
```

Compile with:
```sh
mkimage -A arm64 -T script -C none -d /boot/boot.cmd /boot/boot.scr.uimg
```

## Recovery Option 2: Boot from SD Card / USB

### Requirements
- SD card or USB drive with bootable Arch Linux ARM (or any Linux)
- Card reader / USB port

### Procedure

1. Create bootable media if you don't have one:
   - Download Arch Linux ARM for RK3588
   - Flash to SD card using `dd` or balenaEtcher

2. Insert SD card and power on (U-Boot typically tries SD before eMMC)

3. Once booted from SD, identify and mount your eMMC root partition:
   ```sh
   lsblk
   # eMMC is usually /dev/mmcblk0, root is partition 2
   sudo mount /dev/mmcblk0p2 /mnt
   ```

4. Restore kernel backup:
   ```sh
   sudo cp /mnt/boot/vmlinuz-linux-fydetab-itztweak.backup /mnt/boot/vmlinuz-linux-fydetab-itztweak
   sudo cp /mnt/boot/initramfs-linux-fydetab-itztweak.img.backup /mnt/boot/initramfs-linux-fydetab-itztweak.img
   ```

5. Unmount and reboot:
   ```sh
   sudo umount /mnt
   sudo reboot
   ```

6. Remove SD card during reboot to boot from eMMC

## Recovery Option 3: Maskrom Mode (Last Resort)

If U-Boot itself is corrupted, you can use Maskrom mode to reflash.

### Requirements
- Another computer with `rkdeveloptool` installed
- USB-C cable (data capable)
- Original firmware images

### Procedure

1. Enter Maskrom mode:
   - Power off completely
   - Hold the Maskrom button (small button near USB-C port)
   - Connect USB-C to computer
   - Release button after 3 seconds

2. Verify device detected:
   ```sh
   rkdeveloptool ld
   ```

3. Flash bootloader and system (specific commands depend on your firmware package)

## Prevention: Keeping Recovery Options Ready

1. **Always maintain kernel backups:**
   ```sh
   sudo cp /boot/vmlinuz-linux-fydetab-itztweak /boot/vmlinuz-linux-fydetab-itztweak.backup
   sudo cp /boot/initramfs-linux-fydetab-itztweak.img /boot/initramfs-linux-fydetab-itztweak.img.backup
   ```

2. **Keep a bootable SD card ready** with a working system

3. **Have serial cable accessible** if you do frequent kernel development

4. **Document your partition layout:**
   ```sh
   lsblk -f > ~/partition-layout.txt
   sudo blkid >> ~/partition-layout.txt
   ```

## Diagnosing Boot Failures

### If you have serial console access:

Watch the boot output for errors:
- **"Wrong image format"** - kernel or initramfs corrupted
- **"Unable to read file"** - file missing or filesystem issue
- **Kernel panic** - kernel config issue, missing modules, or initramfs problem
- **Hangs after "Starting kernel"** - device tree or early boot issue

### Common kernel boot failures:

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| No output after "Starting kernel" | Bad DTB or early console | Check DTB path, serial config |
| Kernel panic: VFS unable to mount | Wrong root= parameter or missing fs driver | Check boot.scr, rebuild kernel with ext4 |
| Kernel panic: init not found | Corrupted rootfs or wrong partition | Boot from SD, check filesystem |
| Hangs with blinking cursor | initramfs issue | Regenerate: `mkinitcpio -P` |
