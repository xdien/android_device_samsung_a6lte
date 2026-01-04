# Remaining Issues Fix Guide: WiFi, Bluetooth, Wake Delay

## Issue 1: WiFi Not Working

### Root Cause
```
E/android.hardware.wifi@1.0-service.legacy: Failed to initialize legacy hal function table
E/android.hardware.wifi@1.0-service.legacy: Failed to initialize legacy HAL: NOT_SUPPORTED
```

**Analysis**: WiFi HAL service không tìm thấy hardware implementation (driver interface).

### Likely Causes
1. **Missing WiFi blob**: `android.hardware.wifi@1.0-impl.so` hoặc tương đương chưa được copy từ stock
2. **Missing firmware**: WiFi firmware files (`/vendor/firmware/`) thiếu
3. **Kernel driver**: WiFi kernel module không load hoặc mismatch với HAL 
4. **Missing HAL in Manifest**: `android.hardware.wifi` chưa được declare trong device manifest (VINTF).

### Debug Steps

1. **Check if WiFi service exists**:
```bash
adb shell ls -l /vendor/bin/hw/*wifi*
```

2. **Check for WiFi implementation library**:
```bash
adb shell ls -l /vendor/lib/hw/*wifi*
adb shell ls -l /vendor/lib/hw/*wlan*
```

3. **Check kernel driver**:
```bash
adb shell lsmod | grep -i wlan
adb shell dmesg | grep -i wlan
```

4. **Check firmware path**:
```bash
adb shell ls -l /vendor/firmware/ | grep -i wifi
adb shell ls -l /vendor/firmware/ | grep -i bcm
```

Expected files (Samsung typically uses Broadcom):
- `bcmdhd_sta.bin` / `bcmdhd_sta.bin_a1` (WiFi sta firmware)
- `nvram.txt` / `nvram_net.txt` (calibration data)

### Solution Approach

**Option 1: Extract WiFi blobs from stock**
```bash
# On host
cd ~/extracted_firmware
find . -name "*wifi*" -o -name "*wlan*" -o -name "*bcm*" | grep -E "\.so$|\.bin$|nvram"

# Copy missing files to:
# - vendor/samsung/universal7870-common/proprietary/vendor/lib/hw/
# - vendor/samsung/universal7870-common/proprietary/vendor/firmware/
```

Add to `device-common.mk`:
```makefile
# WiFi HAL (if exists in stock)
PRODUCT_COPY_FILES += \
    vendor/samsung/universal7870-common/proprietary/vendor/lib/hw/android.hardware.wifi@1.0-impl.so:$(TARGET_COPY_OUT_VENDOR)/lib/hw/android.hardware.wifi@1.0-impl.so

# WiFi firmware
PRODUCT_COPY_FILES += \
    vendor/samsung/universal7870-common/proprietary/vendor/firmware/bcmdhd_sta.bin:$(TARGET_COPY_OUT_VENDOR)/firmware/bcmdhd_sta.bin \
    vendor/samsung/universal7870-common/proprietary/vendor/firmware/nvram.txt:$(TARGET_COPY_OUT_VENDOR)/firmware/nvram.txt
```

**Option 2: Check if generic WiFi HAL works**

Some devices use WiFi HAL built from LineageOS source. Check if there's a device-specific config needed.

Look for: `device/samsung/universal7870-common/wifi/` or `BoardConfigCommon.mk` WiFi section:
```makefile
# Example WiFi config
BOARD_WLAN_DEVICE := bcmdhd
BOARD_WPA_SUPPLICANT_DRIVER := NL80211
WPA_SUPPLICANT_VERSION := VER_0_8_X
WIFI_DRIVER_FW_PATH_PARAM := "/sys/module/dhd/parameters/firmware_path"
```

---

## Issue 2: Bluetooth Crash Loop

### Root Cause
```
F/libc: Fatal signal 6 (SIGABRT) in tid bt_hci_thread
[FATAL:hci_layer_android.cc(146)] Check failed: btHci != nullptr
E/bt_btif_storage: Controller not ready! Unable to return Bluetooth Address
```

**Analysis**: Bluetooth HAL không khởi tạo được HCI (Host Controller Interface) layer.

### Common Causes
1. **Missing Bluetooth firmware**: `/vendor/firmware/BCM*.hcd` thiếu
2. **Wrong device node**: `/dev/ttySAC*` permissions hoặc path sai
3. **HAL misconfiguration**: `android.hardware.bluetooth@1.0-service` config sai

### Debug Steps

1. **Check Bluetooth firmware**:
```bash
adb shell ls -l /vendor/firmware/ | grep -iE "bt|bcm|bluetooth"
```

Expected: `BCM4343A1.hcd` hoặc tương tự

2. **Check HCI device node**:
```bash
adb shell ls -l /dev/tty* | grep SAC
adb shell getprop ro.bt.bdaddr_path
```

3. **Check Bluetooth service**:
```bash
adb shell dumpsys bluetooth_manager
```

### Solution Approach

**Step 1: Extract Bluetooth firmware**
```bash
# In extracted_firmware
find . -name "*.hcd" -o -name "BCM*.bin"

# Copy to proprietary folder
cp extracted_firmware/vendor/firmware/BCM*.hcd \
   lineage/vendor/samsung/universal7870-common/proprietary/vendor/firmware/
```

Add to `device-common.mk`:
```makefile
PRODUCT_COPY_FILES += \
    vendor/samsung/universal7870-common/proprietary/vendor/firmware/BCM4343A1.hcd:$(TARGET_COPY_OUT_VENDOR)/firmware/BCM4343A1.hcd
```

**Step 2: Check/Create Bluetooth service config**

Check if file exists: `device/samsung/universal7870-common/bluetooth/`

May need to create `android.hardware.bluetooth@1.0-service.rc` with correct device path.

**Step 3: (Workaround) Disable Bluetooth temporarily**

If not critical, disable to stop crash loop:
```makefile
# In BoardConfigCommon.mk
BOARD_HAVE_BLUETOOTH := false
```

---

## Issue 3: Wake from Suspend Delay (~1 minute)

### Root Cause
Multiple potential issues:
1. **Keyguard/SystemUI slow rendering** (GPU composition heavy với `disable_hwc_overlays=1`)
2. **Input driver not triggering wakeup event** properly
3. **Power HAL suspend/resume slow**

### Current Symptoms
- `adb shell input keyevent KEYCODE_WAKEUP` takes ~60 seconds
- Physical power button also slow

### Quick Workarounds Tested

**Workaround 1: Disable lockscreen** (speeds up wake significantly):
```bash
adb shell settings put global lockscreen.disabled 1
adb shell settings put secure lock_screen_lock_after_timeout 0
```

**Workaround 2: Keep screen always on** (prevents suspend):
```bash
adb shell svc power stayon true
# Or via Settings -> Developer Options -> Stay Awake
```

**Workaround 3: Reduce screen timeout**:
```bash
adb shell settings put system screen_off_timeout 600000  # 10 minutes
```

### Root Cause Investigation

**Check 1: Input events during wake**:
```bash
# Terminal 1
adb shell getevent

# Terminal 2 (press power button)
# Should see events like:
# /dev/input/event0: EV_KEY KEY_POWER DOWN
# /dev/input/event0: EV_KEY KEY_POWER UP
```

If no events → Input driver issue

**Check 2: Power HAL logs**:
```bash
adb logcat -v time | grep -iE "power|suspend|wake"
```

Look for:
- `IPowerAidl` errors
- Long delays between "Going to sleep" and "Waking up"

**Check 3: Keyguard performance**:
```bash
# Enable Keyguard debug
adb shell setprop log.tag.KeyguardUpdateMonitor DEBUG
adb shell setprop log.tag.KeyguardViewMediator DEBUG

# Try wake and check logs
adb logcat -v time | grep Keyguard
```

### Permanent Fix Approaches

**Fix 1: Optimize HWC overlays** (risky - may cause display crashes)

Currently we have `debug.sf.disable_hwc_overlays=1` which forces ALL GPU composition.
This is slow for Keyguard unlock animation.

Try re-enabling overlays:
```makefile
# In device-common.mk, remove or comment:
# debug.sf.disable_hwc_overlays=1 \
```

**But beware**: This may bring back HWC crashes. Test thoroughly.

**Fix 2: Disable animations**:
```makefile
PRODUCT_DEFAULT_PROPERTY_OVERRIDES += \
    debug.sf.nobootanimation=1 \
    persist.sys.disable_rescue=true
```

And via adb:
```bash
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0
```

**Fix 3: Power HAL tuning**

Check if `android.hardware.power@1.x-service` exists and configured properly:
```bash
adb shell dumpsys power | grep "Power Manager State"
```

May need to add Power HAL from stock ROM if using generic.

### Confirmed Fixes (2026-01-03)

**1. Sensors Crash Fix**:
- **Nguyên nhân**: `android.hardware.sensors@1.0-service` build từ source LineageOS không tương thích với legacy blob `sensors.universal7870.so` (báo lỗi version 1.4).
- **Giải pháp**: Sử dụng binary `android.hardware.sensors@1.0-service` từ stock ROM.
  ```bash
  adb push extracted_firmware/vendor/bin/hw/android.hardware.sensors@1.0-service /vendor/bin/hw/
  ```

**2. Wifi Fix**:
- **Nguyên nhân**: Driver `bcmdhd` tìm firmware tại `/vendor/etc/wifi/` thay vì `/vendor/firmware/`. Cần đúng tên file (ví dụ `bcmdhd_sta.bin_c5`).
- **Giải pháp**: Copy toàn bộ nội dung `vendor/etc/wifi/` từ stock.
  ```bash
  adb push extracted_firmware/vendor/etc/wifi/. /vendor/etc/wifi/
  ```
- **Manifest**: Xóa `android.hardware.wifi` khỏi `device/samsung/a6lte/manifest.xml` nếu nó gây conflict với fragment có sẵn.

---

## Testing Checklist After Fixes

### WiFi Testing:
```bash
# 1. Check service started
adb shell dumpsys wifi | grep "Wi-Fi is"

# 2. Try enable
adb shell svc wifi enable
adb shell dumpsys wifi | grep state

# 3. Scan networks
adb shell cmd wifi start-scan
adb shell cmd wifi list-scan-results
```

### Bluetooth Testing:
```bash
# 1. Check service
adb shell dumpsys bluetooth_manager | grep -A 5 enabled

# 2. Try enable
adb shell svc bluetooth enable

# 3. Check for crashes
adb logcat -v time | grep -iE "bluetooth|bt_hci"
```

### Wake Testing:
```bash
# 1. Lock screen
adb shell input keyevent 26  # Power button

# 2. Wait 5 seconds

# 3. Wake and measure time
time adb shell input keyevent KEYCODE_WAKEUP

# Should be < 2 seconds for good experience
```

---

## Priority & Impact

| Issue | Impact | Priority | Estimated Effort | Status |
|-------|--------|----------|------------------|--------|
| WiFi not working | **HIGH** - No network connectivity | **P0** | Medium | **FIXED** ✅ |
| Sensors (Light/Prox) | Medium - Auto brightness, pocket mode | **P1** | Medium | **FIXED** ✅ |
| Wake delay | Medium - UX issue | **P2** | High | **IMPROVED** (~1s) ✅ |
| Bluetooth crash | Medium - Drain battery, annoying | **P1** | Medium (firmware + config) | Open |

---

## Quick Fix Summary for User

### Immediate Actions (No Rebuild Required):

1. **Disable lockscreen to speed up wake**:
```bash
adb shell settings put global lockscreen.disabled 1
```

2. **Keep screen on during development**:
```bash
adb shell svc power stayon true
```

3. **Verify WiFi/BT firmware presence**:
```bash
adb shell ls -l /vendor/firmware/ | grep -iE "bcm|wifi|bt|bluetooth"
```

If missing → Need to extract from stock ROM and rebuild.

### Next Build (v44) Should Include:

1. **WiFi firmware and HAL blobs**
2. **Bluetooth firmware**
3. **Optionally**: Try removing `debug.sf.disable_hwc_overlays=1` to test wake performance

---

## Files to Extract from Stock ROM

```bash
cd ~/extracted_firmware

# WiFi
find . -path "*/vendor/lib/hw/*wifi*"
find . -path "*/vendor/lib/hw/*wlan*"
find . -name "bcmdhd*"
find . -name "nvram*.txt"

# Bluetooth
find . -name "*.hcd"
find . -name "BCM*.bin"

# Power HAL (if exists)
find . -path "*/vendor/lib/hw/*power*"
find . -path "*/vendor/bin/hw/*power*"
```

Copy all found files to:
- `lineage/vendor/samsung/universal7870-common/proprietary/vendor/lib/hw/`
- `lineage/vendor/samsung/universal7870-common/proprietary/vendor/firmware/`

Then add `PRODUCT_COPY_FILES` entries to `device-common.mk`.

---

**Created**: 2026-01-03
**Author**: Debugging session continuation
**Related**: LESSONS_LEARNED_DISPLAY_FIX.md
