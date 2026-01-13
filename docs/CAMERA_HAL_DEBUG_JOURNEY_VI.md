# Camera HAL Debug Journey - Samsung A6LTE (LineageOS 18.1)

## Tổng quan

Tài liệu này ghi lại hành trình debug và fix Camera HAL crash trên Samsung Galaxy A6 (a6lte) chạy LineageOS 18.1 (Android 11). Đây là một case study điển hình về việc port camera HAL cũ (Android 8/9) lên Android mới hơn.

**Ngày hoàn thành:** 2026-01-13

---

## Vấn đề ban đầu

Khi mở ứng dụng Camera, service `android.hardware.camera.provider@2.4-service` crash ngay lập tức với lỗi `SIGSEGV`.

### Triệu chứng:
- Camera App hiển thị màn đen hoặc crash
- Logcat báo lỗi `DEAD_OBJECT`
- Tombstone cho thấy crash trong `libexynoscamera3.so`

---

## Phân tích Root Cause

### 1. Ion Allocator Issue (Đã fix)
**Vấn đề:** `ion_alloc` trả về lỗi `Invalid argument` do legacy HAL sử dụng heap mask không tương thích với kernel mới.

**Giải pháp:** Tạo `libion_camerashim.so` để intercept và retry `ion_alloc` với heap mask hợp lệ.

```c
// ion_shim.c
int ion_alloc(int fd, size_t len, size_t align, unsigned int heap_mask, unsigned int flags, int *handle_fd) {
    // Retry với ION_HEAP_SYSTEM_MASK nếu heap_mask cũ fail
    if (heap_mask == (1 << 21) || heap_mask == (1 << 24) || ...) {
        new_mask = ION_HEAP_SYSTEM_MASK;
    }
}
```

### 2. DataSpace Crash (Critical Fix)

**Vấn đề:** Legacy HAL (Android 8/9) có struct `camera3_stream_t` khác với Android 11. Field `data_space` ở vị trí mà HAL cũ coi là `void* private_data`. Khi Framework pass `data_space = 0x8C20000` (HAL_DATASPACE_V0_JFIF), HAL cũ coi nó là địa chỉ bộ nhớ và dereference → **SIGSEGV**.

**Bằng chứng:**
```
fault addr 0x8c20000
#00 pc 000b1e84  libexynoscamera3.so (android::ExynosCamera3::m_setStreamInfo+780)
```
Fault address = Data space value = 146931712 = 0x8C20000

**Giải pháp:** Clear `data_space` về 0 trước khi gọi vendor HAL trong `Camera3Wrapper.cpp`.

### 3. Max Buffers Issue

**Vấn đề:** Sau khi fix DataSpace, Framework báo lỗi:
```
Camera HAL requested max_buffer count: 0, requires at least 1
Unable to configure stream 0 queue: Function not implemented (-38)
```

Legacy HAL không set giá trị `max_buffers` cho stream (field này không tồn tại trong struct cũ).

**Giải pháp:** Shim `max_buffers = 4` sau khi `configure_streams` return.

### 4. DataSpace Override Check

**Vấn đề:** Framework Android 11 check xem HAL có thay đổi `data_space` không:
```
Stream 0: DataSpace override not allowed for format 0x23
```

**Giải pháp:** KHÔNG restore `data_space` về giá trị gốc. Framework sẽ log Error nhưng không block flow nếu `max_buffers` hợp lệ.

---

## Các file đã sửa đổi

### 1. `Camera3Wrapper.cpp`
**Path:** `device/samsung/universal7870-common/hardware/camera/Camera3Wrapper.cpp`

**Thay đổi chính:**
```cpp
#include <vector>

static int camera3_configure_streams(...) {
    std::vector<android_dataspace_t> original_dataspaces;
    
    // PRE-CALL: Save & Clear DataSpace
    original_dataspaces.resize(stream_list->num_streams);
    for (uint32_t i = 0; i < stream_list->num_streams; i++) {
        camera3_stream_t *stream = stream_list->streams[i];
        original_dataspaces[i] = stream->data_space;
        
        // SHIM 1: Clear dataspace to prevent HAL crash
        if (stream->data_space != 0) {
            stream->data_space = (android_dataspace_t)0;
        }
    }
    
    int ret = VENDOR_CALL(device, configure_streams, stream_list);
    
    // POST-CALL: Fix Max Buffers (DO NOT restore dataspace!)
    if (ret == 0 && stream_list) {
        for (uint32_t i = 0; i < stream_list->num_streams; i++) {
            camera3_stream_t *stream = stream_list->streams[i];
            
            // FIX MAX BUFFERS - Legacy HAL doesn't set this
            if (stream->max_buffers == 0) {
                stream->max_buffers = 4;
            }
        }
    }
    
    return ret;
}
```

### 2. `libion_camerashim.so`
**Path:** `device/samsung/universal7870-common/hardware/ion_shim/`

Shim library để intercept `ion_alloc` calls và retry với heap mask hợp lệ.

### 3. `android.hardware.camera.provider@2.4-service.rc`
**Path:** `device/samsung/universal7870-common/rootdir/etc/`

Thêm `LD_PRELOAD` cho các shim libraries:
```
setenv LD_PRELOAD /vendor/lib/libexynoscamera_shim.so:/vendor/lib/libion_camerashim.so
```

### 4. Vendor HAL Rename
**Thay đổi:** Di chuyển `camera.vendor.exynos7870.so` → `/vendor/lib/libcamera_blob.so`

Để đảm bảo `Camera3Wrapper` (camera.samsungexynos7870.so) được load thay vì vendor blob trực tiếp.

---

## Bài học kinh nghiệm

### 1. Struct Layout Mismatch
Khi port HAL cũ lên Android mới, LUÔN kiểm tra struct layout. Android thường thêm field mới vào struct giữa các version.

### 2. Fault Address = Field Value
Nếu crash address trùng với một giá trị trong struct/parameter, rất có thể HAL đang coi field đó là pointer.

### 3. Wrapper Pattern
Sử dụng Wrapper pattern để intercept và modify các tham số trước/sau khi gọi vendor HAL là cách hiệu quả nhất để fix incompatibility.

### 4. Framework vs HAL Requirements
Framework Android mới có thể strict hơn về validation. Cần balance giữa việc làm HAL vui và Framework chấp nhận.

### 5. Log-Driven Debug
Luôn thêm log chi tiết vào Wrapper để trace flow và giá trị các tham số.

---

## Checklist cho Camera HAL Porting

- [ ] Check struct `camera3_stream_t` layout khác biệt
- [ ] Check `ion_alloc` heap mask compatibility
- [ ] Check `data_space` field handling
- [ ] Check `max_buffers` được set đúng
- [ ] Check `usage` flags compatibility
- [ ] Check `format` support (0x22, 0x23, 0x11...)
- [ ] Verify Wrapper được load thay vì vendor blob trực tiếp
- [ ] Test với logcat verbose để trace flow

---

## Commands hữu ích

### Build Camera Wrapper
```bash
source build/envsetup.sh && lunch lineage_a6lte-userdebug
m camera.samsungexynos7870
```

### Push và Test
```bash
adb root && adb remount
adb push out/target/product/a6lte/vendor/lib/hw/camera.samsungexynos7870.so /vendor/lib/hw/
adb shell "stop vendor.camera-provider-2-4 && start vendor.camera-provider-2-4"
```

### Debug Logs
```bash
# Camera Wrapper logs
adb logcat -d | grep -E "Camera3Wrapper|configure_streams"

# HAL logs
adb logcat -d | grep -E "ExynosCamera|Camera3"

# Crash analysis
adb shell "ls -la /data/tombstones/"
adb pull /data/tombstones/tombstone_XX
```

---

## Tham khảo

- Android Camera HAL3 Interface: https://source.android.com/docs/core/camera/camera3
- ION Memory Allocator: https://www.kernel.org/doc/html/latest/driver-api/dma-buf.html
- Exynos Camera HAL: Samsung proprietary (closed source)

---

## Credits

- Debug session: 2026-01-13
- Device: Samsung Galaxy A6 (a6lte) 
- ROM: LineageOS 18.1 (Android 11)
- Kernel: Exynos 7870

**Thời gian debug:** ~2 giờ intensive debugging
**Số lần build/test:** 15+ iterations
