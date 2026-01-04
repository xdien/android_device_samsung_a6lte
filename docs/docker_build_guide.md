# Docker Build Guide for Samsung A6 (a6lte)

This document records the Docker command used to build LineageOS 18.1 for the Samsung Galaxy A6 (a6lte).

## Prerequisites

*   Docker installed.
*   LineageOS source tree available.
*   `passwd.fake` and `group.fake` files in the source root (to map user permissions correctly).
    *   *Tip: These files help avoid permission issues when the container writes to the host filesystem.*

## Build Command

The following command mounts the source tree and ccache, sets up the environment, and triggers the build.

```bash
docker run --rm --user $(id -u):$(id -g) \
-v /mnt/build_android/workspace/a6lte/lineage:/srv/src \
-v /mnt/build_android/workspace/a6lte/.cache:/srv/ccache \
-v /mnt/build_android/workspace/a6lte/lineage/passwd.fake:/etc/passwd:ro \
-v /mnt/build_android/workspace/a6lte/lineage/group.fake:/etc/group:ro \
-e CCACHE_DIR=/srv/ccache \
-e HOME=/tmp \
--entrypoint /bin/bash \
lineageos4microg/docker-lineage-cicd:latest \
-c "export PATH=/srv/src/prebuilts/clang/host/linux-x86/clang-r383902b/bin:/srv/src/prebuilts/gcc/linux-x86/host/x86_64-linux-glibc2.17-4.8/bin:\$PATH && cd /srv/src && source build/envsetup.sh && lunch lineage_a6lte-userdebug && mka bootimage vendorimage bacon -j12 2>&1 | tee build_v24_SW_RENDER.log"
```

### Command Breakdown

*   **Volume Mounts (`-v`):**
    *   Maps the host source directory to `/srv/src` in the container.
    *   Maps the host ccache directory to `/srv/ccache`.
    *   Maps fake passwd/group files to handle user identity.
*   **Environment (`-e`):**
    *   Sets `CCACHE_DIR`.
    *   Sets `HOME` to `/tmp` (as the container user might not have a home dir).
*   **Entrypoint:** Overrides the default entrypoint to `/bin/bash` to run a custom shell command string.
*   **Build Script (`-c "..."`):**
    *   **PATH Export:** Explicitly adds specific Clang and GCC toolchains to the PATH. This is important if the default environment doesn't pick up the desired compiler versions.
    *   **Setup:** Sources `build/envsetup.sh` and runs `lunch`.
    *   **Make:** Runs `mka bootimage vendorimage bacon` with 12 parallel jobs (`-j12`) and logs output to `build_v24_SW_RENDER.log`.
