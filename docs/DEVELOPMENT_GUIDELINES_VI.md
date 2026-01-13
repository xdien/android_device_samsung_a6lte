# A6LTE Development Guidelines

## Quy tắc chung cho dự án LineageOS A6LTE

### 1. Cấu trúc Repository

```
lineage/
├── device/samsung/
│   ├── a6lte/                    # Device-specific configs
│   │   └── docs/                 # Documentation
│   └── universal7870-common/     # Common configs for Exynos 7870
│       ├── hardware/
│       │   ├── camera/           # Camera Wrapper
│       │   ├── camera_shim/      # libexynoscamera_shim
│       │   └── ion_shim/         # libion_camerashim
│       └── rootdir/etc/          # Init scripts, RC files
├── vendor/samsung/
│   ├── a6lte/                    # Device vendor blobs
│   └── universal7870-common/     # Common vendor blobs
└── kernel/samsung/exynos7870/    # Kernel source
```

### 2. Quy tắc Debug HAL

#### 2.1 Luôn tạo Wrapper
- **ĐỪNG** patch trực tiếp vendor blob (binary)
- **HÃY** tạo wrapper library để intercept và modify behavior
- Wrapper cho phép rollback dễ dàng và debug linh hoạt

#### 2.2 Log mọi thứ
```cpp
ALOGE("function_name: param1=%d, param2=0x%x", param1, param2);
```
- Sử dụng `ALOGE` (Error level) để log luôn hiển thị
- Log TRƯỚC và SAU khi gọi vendor function
- Log return value

#### 2.3 Tombstone Analysis
Khi crash:
1. Lấy tombstone: `adb pull /data/tombstones/tombstone_XX`
2. Check `fault addr` - so sánh với giá trị các field trong struct
3. Check backtrace để xác định function gây crash

### 3. Quy tắc Build

#### 3.1 Build Module đơn lẻ
```bash
source build/envsetup.sh
lunch lineage_a6lte-userdebug
m module_name
```
Ví dụ: `m camera.samsungexynos7870`

#### 3.2 Push và Test nhanh
```bash
adb root && adb remount
adb push out/target/product/a6lte/vendor/lib/hw/module.so /vendor/lib/hw/
adb shell "stop service_name && start service_name"
```

#### 3.3 Full Build
Chỉ build full khi:
- Thay đổi device tree configs
- Thay đổi kernel
- Chuẩn bị release

### 4. Quy tắc Shim Library

#### 4.1 Khi nào cần Shim
- Symbol missing (undefined reference)
- Function behavior cần thay đổi
- Struct layout khác biệt giữa các Android version

#### 4.2 Cấu trúc Shim
```c
// shim.c
#define LOG_TAG "ShimName"
#include <cutils/log.h>
#include <dlfcn.h>

// Constructor để log khi library được load
__attribute__((constructor)) void init() {
    ALOGI("Shim loaded");
}

// Override function
int target_function(params) {
    // Modify params if needed
    // Call original function
    // Modify return if needed
}
```

#### 4.3 Đăng ký Shim
1. Thêm vào `device-common.mk`:
   ```makefile
   PRODUCT_PACKAGES += \
       libshim_name
   ```

2. Thêm `LD_PRELOAD` trong RC file nếu cần

### 5. Quy tắc Camera HAL

#### 5.1 Struct Compatibility
Luôn check struct layout khi port từ Android cũ:
- `camera3_stream_t` 
- `camera3_stream_configuration_t`
- `camera3_capture_request_t`

#### 5.2 Critical Fields
| Field | Issue | Solution |
|-------|-------|----------|
| `data_space` | Legacy HAL coi là pointer | Clear về 0 trước khi gọi HAL |
| `max_buffers` | Legacy HAL không set | Force set = 4 sau configure |
| `format` | Incompatible với Gralloc | Shim nếu cần |
| `usage` | Missing flags | Add required flags |

#### 5.3 Wrapper Flow
```
Framework → Wrapper → Vendor HAL

configure_streams:
1. PRE-CALL: Modify params cho HAL compatible
2. CALL: VENDOR_CALL(device, configure_streams, ...)
3. POST-CALL: Fix/Restore params cho Framework compatible
```

### 6. Quy tắc Git Commit

#### 6.1 Commit Message Format
```
[component]: Brief description

Detailed explanation of:
- What was changed
- Why it was changed
- Any side effects

Signed-off-by: Name <email>
```

Ví dụ:
```
camera: Fix HAL crash due to dataspace struct mismatch

Legacy Exynos camera HAL treats data_space field as a pointer,
causing SIGSEGV when Android 11 framework passes actual dataspace
values (e.g., 0x8C20000).

Solution: Clear data_space to 0 before calling vendor HAL in
Camera3Wrapper to prevent crash.

Signed-off-by: Developer <dev@example.com>
```

#### 6.2 Commit Atomicity
- Mỗi commit giải quyết MỘT vấn đề cụ thể
- Có thể revert độc lập
- Có thể cherry-pick sang branch khác

### 7. Quy tắc Testing

#### 7.1 Smoke Test Checklist
- [ ] Device boot thành công
- [ ] UI responsive
- [ ] WiFi connect được
- [ ] Bluetooth pair được
- [ ] Camera mở và có hình
- [ ] Audio speaker/headphone
- [ ] Sensor hoạt động (rotation, light, proximity)

#### 7.2 Camera Test Checklist
- [ ] Preview hiển thị
- [ ] Chụp ảnh lưu được
- [ ] Quay video hoạt động
- [ ] Flash LED hoạt động
- [ ] Switch front/back camera
- [ ] Zoom không crash
- [ ] Portrait mode (nếu có)

### 8. Troubleshooting Quick Reference

| Symptom | Likely Cause | Solution |
|---------|--------------|----------|
| SIGSEGV tại địa chỉ lạ | Struct mismatch | Check field layout |
| `Invalid argument` | Wrong params/flags | Shim để fix params |
| `Function not implemented` | Missing field | Set required fields |
| `DEAD_OBJECT` | HAL crash | Check tombstone |
| Black preview | Format/Usage mismatch | Shim format/usage |
| Service restart loop | Init script error | Check RC file |

---

## Liên hệ & Tham khảo

- LineageOS Wiki: https://wiki.lineageos.org/
- Android HAL Documentation: https://source.android.com/docs/core/architecture/hal
- Samsung Exynos Resources: (Samsung proprietary)

---

*Tài liệu này được cập nhật lần cuối: 2026-01-13*
