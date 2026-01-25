# VSCodium / Wayland GPU Driver Fix

## Problem
VSCodium crashes under Wayland because the proprietary Mali Bifrost driver (`CONFIG_MALI_BIFROST=y`) is built into the kernel and claims the GPU before the open-source panfrost driver can load. This results in:
- No GPU render node for Mesa/EGL
- `wl_drm authentication failed` errors
- VSCodium crashes with SIGTRAP

## Current Workaround
VSCodium works with X11/XWayland mode:
```bash
codium --ozone-platform=x11
```
Persistent config: `~/.config/codium-flags.conf` contains `--ozone-platform=x11`

## System Info
- GPU: Mali G610 (CSF-based, needs panthor or patched panfrost)
- Device tree compatible: `arm,mali-bifrost`
- Mesa package: `mesa-panfork-git` (expects panfrost)
- Kernel: Custom linux-fydetab-itztweak 6.1.75

## Investigation Findings

### DRI Devices
- `/dev/dri/card0` = RKNPU (renderD128)
- `/dev/dri/card1` = rockchip-drm display (renderD129)
- No GPU render node exists (panfrost would create one)

### Driver Status
- `mali` driver: bound to `fb000000.gpu` (proprietary, built-in)
- `panfrost` driver: loaded as module, no device bound
- `panthor` driver: loaded as module, no device bound

### Kernel Config (lines 1772-1785)
```
CONFIG_DRM_PANFROST=m      # Open source - module
CONFIG_DRM_PANTHOR=m       # Open source - module
CONFIG_MALI_BIFROST=y      # Proprietary - built-in (THE PROBLEM)
CONFIG_MALI_MIDGARD=y      # Proprietary - built-in
```

---

## Fix Checklist

### [ ] Option 1: Runtime Unbind/Rebind (Quick Test)
Try unbinding GPU from proprietary driver and binding to panfrost:

```bash
# Step 1: Unbind from mali
sudo sh -c 'echo fb000000.gpu > /sys/bus/platform/drivers/mali/unbind'

# Step 2: Bind to panfrost
sudo sh -c 'echo fb000000.gpu > /sys/bus/platform/drivers/panfrost/bind'

# Step 3: Check if render node appeared
ls -la /dev/dri/

# Step 4: Check dmesg for errors
dmesg | tail -30

# Step 5: Test VSCodium under Wayland
codium --ozone-platform=wayland
```

**Status:** TRIED - Crashed the system
**Risk:** May crash display/session
**Persistence:** Does not survive reboot

---

### [ ] Option 2: Device Tree Overlay
Create overlay to prevent mali driver from probing:

```bash
# Create overlay source
cat > /tmp/disable-mali.dts << 'EOF'
/dts-v1/;
/plugin/;

&{/gpu@fb000000} {
    status = "disabled";
};
EOF

# Compile and install
dtc -I dts -O dtb -o /boot/dtbs/overlays/disable-mali.dtbo /tmp/disable-mali.dts

# Add to boot config (depends on bootloader)
```

**Status:** NOT TRIED
**Persistence:** Survives reboot

---

### [x] Option 3: Kernel Rebuild - COMPLETED but INSUFFICIENT

Edit `config` file and rebuild kernel:

```bash
# From the kernel package directory:

# Edit config - change these lines:
# CONFIG_MALI_BIFROST=y  ->  # CONFIG_MALI_BIFROST is not set
# CONFIG_MALI_MIDGARD=y  ->  # CONFIG_MALI_MIDGARD is not set

# Rebuild
./build.sh clean
```

**Status:** INSTALLED on SD - but panfrost fails to initialize

**Problem discovered:** The Mali G610 is a **CSF-based Valhall GPU**. Panfrost only supports older Bifrost/Midgard architectures. Panfrost fails with:
```
panfrost fb000000.gpu: _of_add_opp_table_v2: no supported OPPs
panfrost fb000000.gpu: devfreq init failed -2
panfrost fb000000.gpu: Fatal error during GPU init
```

Result: GNOME Shell crashes repeatedly with "No GPUs found"

---

### [!] Option 4: DTB Modification for Panthor - FAILED 2026-01-22

The device tree already has both GPU nodes defined:
- `gpu@fb000000` - mali-bifrost (was enabled)
- `gpu-panthor@fb000000` - mali-valhall-csf (was disabled)

**Initial attempt:** Swap the status of these nodes to use panthor instead.

**Status:** FAILED - panthor driver loaded but couldn't initialize DVFS

**Error from journal:**
```
panthor fb000000.gpu-panthor: Looking up mali-supply property in node /gpu-panthor@fb000000 failed
panthor fb000000.gpu-panthor: error -ENODEV: _opp_set_regulators: no regulator (mali) found
panthor fb000000.gpu-panthor: [drm:panthor_devfreq_init [panthor]] *ERROR* Couldn't set OPP regulators
```

**Root cause:** The `gpu_panthor` node was missing the `mali-supply` regulator property needed for DVFS.

---

### [x] Option 5: Patch DTS Source - IMPLEMENTED 2026-01-22

**The fix:** Patch the FydeTab device tree source to:
1. Disable the old `&gpu` (bifrost) node
2. Enable `&gpu_panthor` with `mali-supply = <&vdd_gpu_s0>;`

**Implementation:** Added `enable-panthor-gpu.patch` to the kernel PKGBUILD.

**Patch contents:**
```diff
--- a/arch/arm64/boot/dts/rockchip/rk3588s-fydetab-duo.dts
+++ b/arch/arm64/boot/dts/rockchip/rk3588s-fydetab-duo.dts
@@ -13,3 +13,13 @@
 	model = "Fydetab Duo";
 	compatible = "rockchip,rk3588s-tablet-12c-linux", "rockchip,rk3588";
 };
+
+/* Use Panthor driver instead of Bifrost for Mali G610 GPU */
+&gpu {
+	status = "disabled";
+};
+
+&gpu_panthor {
+	status = "okay";
+	mali-supply = <&vdd_gpu_s0>;
+};
```

**Files changed:**
- `linux-fydetab-itztweak/PKGBUILD` - added patch to source array and prepare()
- `linux-fydetab-itztweak/enable-panthor-gpu.patch` - new patch file

**To build and test:**
```bash
# From the kernel package directory:
./build.sh clean    # Clean rebuild with patch applied
```

**Status:** PKGBUILD updated, awaiting kernel rebuild

---

### [!] Option 6: Mesa Upgrade Required - DISCOVERED 2026-01-23

**Finding:** After testing Option 5 (DTB patch), the panthor kernel driver initialized successfully but GNOME Shell crashed with "No GPUs found".

**Root cause:** The `mesa-panfork-git` package only has `panfrost_dri.so` (for Bifrost/Midgard). The panthor driver requires `panthor_dri.so` which is only in mainline Mesa 24.1+.

**Errors from gnome-shell:**
```
MESA-LOADER: failed to open panthor: /usr/lib/dri/panthor_dri.so: cannot open shared object file: No such file or directory
Failed to setup: No GPUs found
```

**Fix:** Changed `mesa-panfork-git` to `mesa` in:
- ``images/fydetab-arch/packages.aarch64``

**Note:** The kernel patch (Option 5) is correct. The panthor driver initialized properly:
```
[drm] Initialized panthor 1.0.0 20230801 for fb000000.gpu-panthor on minor 2
panthor fb000000.gpu-panthor: [drm] mali-g610 id 0xa867 major 0x0 minor 0x0 status 0x5
```

**Next steps:**
1. Rebuild the SD card image with mainline mesa
2. Test if GNOME Shell starts with panthor GPU acceleration

---

## After Reboot - Verification Steps

Run these commands after booting from the modified SD card:

```bash
# 1. Check which GPU driver loaded
dmesg | grep -iE "panthor|panfrost|mali"

# 2. Check for GPU render node (should see renderD128 or similar for GPU)
ls -la /dev/dri/

# 3. Check if GNOME Shell started successfully
systemctl status gdm

# 4. If GUI works, test GPU acceleration
glxinfo | grep "OpenGL renderer"
# or
eglinfo | head -20
```

**Expected success indicators:**
- `panthor fb000000.gpu: [drm] Initialized panthor` in dmesg
- `/dev/dri/renderD130` or similar render node exists
- GDM/GNOME Shell running without crash loop
- `glxinfo` shows Mali or panfrost renderer (not llvmpipe)

**If it fails:**
- Mount SD from main system and restore original DTB
- Or rebuild image from fydetab-images repo

---

## Recovery Commands

If display crashes after unbind, SSH in or use TTY:

```bash
# Rebind to mali (restore original state)
sudo sh -c 'echo fb000000.gpu > /sys/bus/platform/drivers/mali/bind'

# Or just reboot
sudo reboot
```

## Next Session Resume Point

**Current state (2026-01-22):** Panthor DTB-only fix failed (missing mali-supply). Permanent fix implemented as kernel patch.

**Next steps:**
1. Rebuild kernel: `# From the kernel package directory: && ./build.sh clean`
2. Build new image: `# From the images directory:
sudo ./fydetab-arch/profiledef -c fydetab-arch -w ./work -o ./out`
3. Flash to SD and test

**After reboot, verify with:**
```bash
# Check panthor initialized with DVFS working
dmesg | grep -iE "panthor|mali-supply|opp"

# Should see GPU render node
ls -la /dev/dri/

# Test GPU acceleration
glxinfo | grep "OpenGL renderer"
```

---

## Future Planning: Package Fork Consideration

**Status:** PLANNING - not yet implemented

Consider forking the `linux-fydetab-itztweak` package to maintain custom configurations:

**Motivation:**
- Upstream Fyde kernel config enables proprietary Mali drivers by default
- We need open-source panfrost/panthor for proper Mesa/Wayland support
- Want to maintain our own config set independent of upstream defaults

**Proposed approach:**
1. Create `linux-fydetab-itztweak-custom` or similar fork package
2. Track upstream `Linux-for-Fydetab-Duo/linux-rockchip` noble-panthor branch
3. Maintain custom config as overlay/patch on top of upstream
4. When upstream updates: fetch new source, rebase config changes
5. Document config delta between upstream and custom version

**Key config differences from upstream:**
- Disable `CONFIG_MALI_BIFROST`, `CONFIG_MALI_MIDGARD` (proprietary drivers)
- Enable `CONFIG_DRM_PANFROST`, `CONFIG_DRM_PANTHOR` as modules (open source)

**Decision:** Defer until after testing current fix works
