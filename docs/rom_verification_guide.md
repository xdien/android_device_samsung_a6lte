# Verification Plan: LineageOS 18.1 for SM-A600G

This document outlines how to verify that your built ROM correctly utilizes the device tree and functions properly on the Samsung Galaxy A6 (SM-A600G).

## 1. Post-Build Static Analysis
Before flashing, inspect the build artifacts in `out/target/product/a6lte/`.

### A. Verify Build Properties
Extract `system/build.prop` (from `system.img` or the zip file) and check for:
```bash
grep -E "ro.product.device|ro.product.model|ro.board.platform" system/build.prop
```
**Expected Output:**
- `ro.product.device=a6lte`
- `ro.product.model=SM-A600G`
- `ro.board.platform=exynos7870`

### B. Verify Vendor Blobs Integrity
Ensure key proprietary blobs are present in `vendor.img`:
- `libExynosHWCService.so` (Display)
- `libsensorndkbridge.so` (Sensors)
- `libaudior7870.so` (Audio)

## 2. Boot Testing (Dynamic Verification)

### Phase 1: Recovery/Kernel Test (Low Risk)
Test if the kernel and basic hardware initialization are working without flashing the full system.
1. **Flash `recovery.img`** (if built) or use your existing TWRP.
   - If using built recovery: `heimdall flash --RECOVERY recovery.img`
2. **Flash `boot.img` using TWRP (Recommended):**
   - Copy `boot.img` to your device storage.
   - Boot into TWRP.
   - Tap **Install** -> Tap **Install Image** (bottom right).
   - Select your `boot.img` file.
   - Select **Boot** partition.
   - Swipe to flash.

   **Alternative: Flash via PC (Linux)**
   Since you are on Linux and have `heimdall` installed:
   1. Reboot to Download Mode: `adb reboot download`
   2. Flash boot image:
      ```bash
      heimdall flash --BOOT out/target/product/a6lte/boot.img --no-reboot
      ```
   3. Manually reboot (Volume Down + Power) to test.
3. **Boot into System.**
   - If it shows the boot animation, the kernel is working.

### Phase 2: Full ROM Flash
1. **Backup:** Make a Nandroid backup of your current working ROM in TWRP.
2. **Wipe:** Format Data / Factory Reset in TWRP.
3. **Flash:** Install the `lineage-18.1-*.zip`.
4. **Reboot:**
   - **First Boot:** Can take 5-10 minutes.
   - **Success Criteria:** LineageOS boot animation appears and eventually reaches the setup screen.

## 3. Functional Testing Checklist
Once booted, verify these key components (using the device tree configurations):

| Component | Test Action | Expected Result |
|-----------|-------------|-----------------|
| **Display** | Adjust brightness, check colors | Smooth transition, correct resolution |
| **Touch** | Tap all corners, multi-touch | Responsive, no ghost touches |
| **WiFi** | Connect to AP | Connects, internet works |
| **Audio** | Play music, make a call | Sound from speaker/earpiece, mic works |
| **RIL (Sim)**| Check signal bars, LTE data | 4G/LTE icon, calls work |
| **Camera** | Open Camera app | Preview shows, takes photo (Front/Back) |
| **Sensors** | Auto-rotate screen | Screen rotates correctly |
| **GPS** | Open Maps app | Locks location |

## 4. Debugging Boot Loops
If the device hangs at the logo or boot animation:

**A. ADB Logcat (If ADB is active)**
```bash
adb logcat > boot_log.txt
```
**Look for:**
- `dlopen failed`: Missing vendor blob (`.so` file).
- `SurfaceFlinger` crashes: Graphics/HWC issue.
- `zygote` crashing: Framework/Runtime issue.

**B. Kernel Panic (Pstore)**
If it reboots immediately:
boot into TWRP -> Advanced -> Terminal:
```bash
cat /sys/fs/pstore/console-ramoops
```
This saves the last kernel log before the crash.
