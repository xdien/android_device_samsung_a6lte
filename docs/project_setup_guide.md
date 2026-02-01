# Project Setup and Build Guide for Samsung Galaxy A6 (SM-A600G)

This guide details the complete process to set up the build environment and sources for LineageOS 18.1 on the Samsung Galaxy A6 (A600G).

## 1. Initialize LineageOS 18.1 Source

Index the core LineageOS 18.1 repository:

```bash
mkdir -p lineage
cd lineage
repo init -u https://github.com/LineageOS/android.git -b lineage-18.1
repo sync
```

## 2. Clone Device-Specific Repositories

Clone the device tree, vendor tree, kernel, and necessary dependencies into the source tree.

### Device & Vendor Trees (Maintainer Forks)
```bash
# Device Tree
git clone https://github.com/xdien/android_device_samsung_a6lte.git device/samsung/a6lte

# Vendor Tree
git clone https://github.com/xdien/android_vendor_samsung_a6lte.git vendor/samsung/a6lte

# Common Device Tree (Forked)
git clone -b lineage-18.1-oss_bsp-vndk https://github.com/xdien/android_device_samsung_universal7870-common.git device/samsung/universal7870-common

# Kernel Source (Forked)
git clone -b aosp-11 https://github.com/xdien/android_kernel_samsung_exynos7870.git kernel/samsung/exynos7870
```

### Required Dependencies (Upstream/Common)
These repositories are essential for the build to succeed.

```bash
# Common Vendor Tree (Upstream)
git clone -b lineage-18.1-oss_bsp-vndk https://github.com/samsungexynos7870/android_vendor_samsung_universal7870-common.git vendor/samsung/universal7870-common

# Samsung Hardware HALs (LineageOS)
git clone -b lineage-18.1 https://github.com/LineageOS/android_hardware_samsung.git hardware/samsung

# Samsung SLSI SEPolicy (LineageOS)
git clone -b lineage-18.1 https://github.com/LineageOS/android_device_samsung_slsi_sepolicy.git device/samsung_slsi/sepolicy

# Samsung SLSI Config (Required for BoardConfig7870.mk)
git clone https://github.com/samsungexynos7870/android_hardware_samsung_slsi-linaro_config.git hardware/samsung_slsi-linaro/config
```

## 3. Build with Docker

Refer to the `docker_build_guide.md` for the specific Docker command, but generally:

```bash
# Example shell access to build environment
docker run --rm -it --user $(id -u):$(id -g) \
-v $(pwd):/srv/src \
-v $(pwd)/.cache:/srv/ccache \
lineageos4microg/docker-lineage-cicd:latest \
/bin/bash
```

Inside the container:
```bash
cd /srv/src
source build/envsetup.sh
lunch lineage_a6lte-userdebug
mka bacon
```
