# Android Boot Debugging Guide (Samsung Exynos)

This guide provides methods to debug boot issues (Black Screen, Bootloop, Hangar Logo) specifically for LineageOS on Samsung Exynos devices.

## 1. Kernel Panic / Black Screen (Immediate Crash)
If the device shows a black screen immediately after the Samsung logo or boots to a black screen with LED on/off, it's likely a **Kernel Panic** or **Init Crash**.

### Method A: Pstore / Ramoops (Recommended)
Modern Android kernels (3.10+) store crash logs in RAM that survives a warm reboot.

1.  **Boot into TWRP Recovery**.
2.  **Connect to PC** and open terminal:
    ```bash
    adb shell
    ls -R /sys/fs/pstore/
    ```
3.  **Check for logs:**
    Look for files named `console-ramoops` or `console-ramoops-0`.
    ```bash
    cat /sys/fs/pstore/console-ramoops-0 > /sdcard/panic_log.txt
    ```
    *Exit shell and pull the file:*
    ```bash
    adb pull /sdcard/panic_log.txt .
    ```
4.  **Analyze:** Search for "Panic", "BUG", "Oops", or "segfault".
    *   *Example:* `Kernel panic - not syncing: VFS: Unable to mount root fs` -> Filesystem issue.
    *   *Example:* `Unable to handle kernel paging request` in `mali_kbase` -> GPU Driver (blob) issue.

### Method B: /proc/last_kmsg (Legacy)
For older kernels (3.0/3.4) or if pstore is empty:
```bash
adb shell cat /proc/last_kmsg > last_kmsg.txt
```

---

## 2. Boot Loop (Spinning Animation)
If the LineageOS animation plays forever, the kernel is alive, but a critical system service (SurfaceFlinger, SystemUI, etc.) is crashing.

### Method A: ADB Logcat (Early Boot)
You can catch logs as soon as `adbd` starts.

1.  **Prepare command:**
    ```bash
    adb logcat > boot_log.txt
    ```
    *(Run this command and keep it waiting "waiting for device")*
2.  **Reboot phone.**
3.  **Wait:** As soon as the phone connects, logs will stream to the file.
4.  **Analyze:** Search for `FATAL`, `died`, `RuntimeError`.
    *   *Tip:* `grep -i "E AndroidRuntime" boot_log.txt`

### Method B: Tombstones (Native Crashes)
If native services (SurfaceFlinger, AudioServer) crash, they leave "tombstones".

1.  Boot into TWRP.
2.  Mount **Data** partition in TWRP `Mount` menu.
3.  Check:
    ```bash
    adb shell ls -l /data/tombstones/
    ```
4.  Pull the latest tombstone file and analyze backtraces.

---

## 3. Common Specific Issues

### A. Missing Vendor Blobs (Black Screen)
*   **Symptom:** Kernel Panic related to Graphics (mali), Audio, or RIL.
*   **Fix:** Ensure `vendor.img` is populated. Check `device/samsung/universal7870-common/proprietary-files_*.txt` and re-run extraction.

### B. Encryption / Mount Data Fail (Boot to Recovery/Black Screen)
*   **Symptom:** Logcat shows `vdc: Failed to mount /data`. TWRP shows `Invalid argument`.
*   **Fix:**
    1.  Disable `encryptable` or `fileencryption` in `fstab.samsungexynos7870`.
    2.  **FORMAT DATA** in TWRP (Wipe > Format Data > "yes").

### C. SELinux Denials (Services Crashing)
*   **Symptom:** Services crash with permission denied errors in logcat.
*   **Fix:** Set `BOARD_KERNEL_CMDLINE += androidboot.selinux=permissive` in `BoardConfig.mk`.
