# Kernel Update Checklist

## Current Status
- **Kernel built:** linux-fydetab-itztweak-6.1.75-4
- **Fix applied:** CONFIG_TRUSTED_KEYS=n (disabled TPM keys to fix ASN.1 build error)
- **Packages location:** `~/builds/linux-fydetab-itztweak/*.pkg.tar.zst`

---

## Completed

- [x] Fix `CONFIG_TRUSTED_KEYS=m` → `CONFIG_TRUSTED_KEYS=n` in config
- [x] Build kernel successfully
- [x] Create `build.sh` with logging and diagnostics
- [x] Document update procedure (`UPDATE-PROCEDURE.md`)
- [x] Document recovery options (`RECOVERY.md`)
- [x] Create SD rescue script (`create-sd-rescue.sh`)

---

## In Progress

- [ ] Create SD rescue image with new kernel
  ```sh
  cd ~/builds/linux-fydetab-itztweak
  sudo ./create-sd-rescue.sh /dev/mmcblk1
  ```

---

## Remaining Steps

### 1. Test SD Boot
- [ ] Power off tablet
- [ ] Ensure SD card is inserted
- [ ] Power on
- [ ] Verify it boots from SD (not eMMC)
- [ ] Login: root / rescue
- [ ] Check kernel: `uname -r` (should show 6.1.75-rkr3)
- [ ] Basic functionality check (display, touch, wifi)

### 2. If SD Boot Succeeds
- [ ] Power off, remove SD card
- [ ] Boot back into eMMC system
- [ ] Backup current kernel:
  ```sh
  sudo cp /boot/vmlinuz-linux-fydetab-itztweak /boot/vmlinuz-linux-fydetab-itztweak.backup
  sudo cp /boot/initramfs-linux-fydetab-itztweak.img /boot/initramfs-linux-fydetab-itztweak.img.backup
  ```
- [ ] Install new kernel to eMMC:
  ```sh
  cd ~/builds/linux-fydetab-itztweak
  sudo pacman -U linux-fydetab-itztweak-6.1.75-4-aarch64.pkg.tar.zst
  ```
- [ ] Reboot and verify

### 3. If SD Boot Fails
- Remove SD card → system boots from eMMC as normal
- Investigate failure:
  - Check SD card creation logs
  - Try serial console if available
  - Review kernel config for missing drivers

---

## Files Created This Session

| File | Purpose |
|------|---------|
| `config` | Modified: CONFIG_TRUSTED_KEYS=n |
| `build.sh` | Build script with logging |
| `create-sd-rescue.sh` | Creates bootable SD with new kernel |
| `UPDATE-PROCEDURE.md` | System update documentation |
| `RECOVERY.md` | Boot recovery documentation |
| `CHECKLIST.md` | This file |
| `logs/` | Build logs directory |

---

## Quick Commands Reference

```sh
# Build kernel
./build.sh clean   # Fresh build
./build.sh         # Resume build

# Check build logs
tail -f logs/build-latest.log

# Create SD rescue
sudo ./create-sd-rescue.sh /dev/mmcblk1

# Install to eMMC (after testing)
sudo pacman -U linux-fydetab-itztweak-6.1.75-4-aarch64.pkg.tar.zst

# Update system (after kernel)
paru -Syu --ignore linux-fydetab-itztweak,linux-fydetab-itztweak-headers
```

---

## Notes

- SD card root password: `rescue`
- Keep SD card as permanent recovery option for future kernel updates
- Build logs saved to `logs/` with timestamps
