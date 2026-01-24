# Changelog

All notable changes to the linux-fydetab kernel package will be documented in this file.

## [Unreleased]

### Changed
- **2026-01-22**: Added `enable-panthor-gpu.patch` to switch from proprietary Mali driver to open-source panthor
  - **Why**: The Mali G610 is a CSF-based Valhall GPU. The proprietary `mali` driver (CONFIG_MALI_BIFROST) claims the GPU before open-source drivers can load, preventing Mesa/EGL from working properly with Wayland apps like VSCodium
  - **What the patch does**:
    - Disables `&gpu` node (bifrost/proprietary driver)
    - Enables `&gpu_panthor` node with `mali-supply = <&vdd_gpu_s0>` for DVFS
  - **Requires**: Mainline `mesa` (24.1+) with `panthor_dri.so` in userspace

### Fixed
- **2026-01-22**: Disabled `CONFIG_TRUSTED_KEYS` in kernel config
  - **Why**: Avoids ASN.1 decoder build race condition during parallel compilation
  - **Note**: No TPM on the FydeTab Duo, so this feature isn't needed anyway

## [6.1.75-4] - Previous Release

- Base kernel from `Linux-for-Fydetab-Duo/linux-rockchip` (noble-panthor branch)
- Custom config for FydeTab Duo hardware
- Disabled proprietary Mali drivers (`CONFIG_MALI_BIFROST=n`, `CONFIG_MALI_MIDGARD=n`)
- Enabled open-source GPU drivers as modules (`CONFIG_DRM_PANFROST=m`, `CONFIG_DRM_PANTHOR=m`)
