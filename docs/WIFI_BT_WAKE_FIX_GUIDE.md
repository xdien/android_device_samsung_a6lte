# Debugging Fix Guide: WiFi, Sensors, Memtrack, Wake Delay, Bluetooth, Audio

## Final Status (2026-01-05)

| Feature | Status | Fix Implemented |
|---------|--------|-----------------|
| **WiFi** | ✅ FIXED | Added missing firmware blobs (`_blob` suffix) to `/vendor/etc/wifi/` |
| **Sensors** | ✅ FIXED | Used stock binary service + Added manual `init.rc` configuration + Manifest entry |
| **Memtrack** | ✅ FIXED | Added `memtrack` blob + Manifest entry + Configured service 32-bit |
| **Bluetooth** | ✅ FIXED | Full Vendor Switch (Service + Libs + Init RC) + Added dependencies (`vendor.samsung...so`) |
| **Audio** | ✅ FIXED | Full Vendor Switch (Stocks 2.0 Service, Impl, RC, Common Util Libs) + Downgraded Manifest to 2.0 |
| **Wake Delay** | ✅ FIXED | Reduced to ~1s (Resolved by fixing Sensors blocking System Server) |
| **Boot Loop** | ✅ FIXED | Resolved by providing proper Init RC for sensors service |

---

## 5. Audio Fix

### Symptoms
1. **Crash**: Stack trace in `libaudior7870.so` (Mismatch with source-built HAL).
2. **Port Error -19**: `listAudioPorts` failed due to version mismatch (Manifest 5.0 vs Blob 2.0) and config mismatch.
3. **Crash (Load Fail)**: `Could not load ... android.hardware.audio.common@2.0-util.so` not found.

### Root Cause
- **Protocol Mismatch**: LineageOS source defaults to Audio HAL 5.0. Stock blobs are 2.0. Using 5.0 wrapper with 2.0 blob caused crashes and config errors.
- **Dependency Issues**: Switching to Stock HAL required copying not just the main blob but a chain of dependencies:
  - `android.hardware.audio@2.0-service`
  - `android.hardware.audio@2.0-impl.so`
  - `android.hardware.audio.effect@2.0-impl.so`
  - `vendor.samsung.hardware.audio@1.0.so`
  - `android.hardware.audio.common@2.0-util.so`
  - `android.hardware.audio.common-util.so`

### Solution
1. **Downgrade Manifest**: Change `android.hardware.audio` version to **2.0** in `manifest.xml`.
2. **Use Stock Policy Config**: Copy `audio_policy_configuration.xml` from stock firmware.
3. **Full Vendor Switch**: Copy all the blobs listed above to their respective vendor paths.
4. **Disable Source Build**: Removed `audio.primary.exynos7870` from `device-common.mk`.

---
