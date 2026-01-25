# linux-fydetab-itztweak

Custom Linux kernel package for the **FydeTab Duo** tablet (Rockchip RK3588S), maintained by itzTweak.

**Status: Experimental** - This package is in development and has not been fully tested yet.

## Overview

This kernel is based on [Linux-for-Fydetab-Duo/linux-rockchip](https://github.com/Linux-for-Fydetab-Duo/linux-rockchip) (noble-panthor branch) with the following customizations:

- **Panthor GPU support**: Device tree patch enables the open-source Panthor driver for the Mali G610 GPU
- **Custom configuration**: Optimized for FydeTab Duo hardware with Panthor/Mesa compatibility
- **Provides/Replaces linux-fydetab**: Seamless upgrade path from the upstream package

## Package Names

- `linux-fydetab-itztweak` - Kernel and modules
- `linux-fydetab-itztweak-headers` - Kernel headers for building out-of-tree modules

## Build

Prerequisites:
```sh
sudo pacman -S base-devel xmlto docbook-xsl kmod inetutils bc git uboot-tools vboot-utils dtc
```

Build packages:
```sh
./build.sh         # Continue/resume build
./build.sh clean   # Fresh build (removes src/pkg)
```

Build logs are saved to `logs/`.

## Install

```sh
sudo pacman -U linux-fydetab-itztweak-*.pkg.tar.zst
```

## uname -r

After installation, the kernel version will be:
```
6.1.75-rkr3-fydetab-itztweak
```

## Documentation

- [UPDATE-PROCEDURE.md](UPDATE-PROCEDURE.md) - Safe kernel update workflow
- [RECOVERY.md](RECOVERY.md) - Boot recovery procedures
- [GPU-DRIVER-FIX.md](GPU-DRIVER-FIX.md) - Panthor GPU investigation notes
- [CHANGELOG.md](CHANGELOG.md) - Release history

## Requirements

- Mainline Mesa (24.1+) with `panthor_dri.so` for GPU acceleration
- FydeTab Duo tablet (RK3588S)

## License

GPL-2.0 (inherited from Linux kernel)
