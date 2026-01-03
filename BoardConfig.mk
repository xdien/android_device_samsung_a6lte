# Inherit from universal7870-common
include device/samsung/universal7870-common/BoardConfigCommon.mk

DEVICE_PATH := device/samsung/a6lte

# Asserts
TARGET_OTA_ASSERT_DEVICE := a6lte,a6ltedd,a6ltexx,SM-A600G,SM-A600FN

# Kernel
TARGET_KERNEL_CONFIG := exynos7870-a6lte_defconfig

# SELinux permissive for debugging
BOARD_KERNEL_CMDLINE += androidboot.selinux=permissive console=ram androidboot.hardware=samsungexynos7870

# Partitions
BOARD_BOOTIMAGE_PARTITION_SIZE := 33554432
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 39845888
BOARD_SYSTEMIMAGE_PARTITION_SIZE := 3221225472
BOARD_USERDATAIMAGE_PARTITION_SIZE := 27044851712
BOARD_CACHEIMAGE_PARTITION_SIZE := 209715200


# Properties
TARGET_SYSTEM_PROP += $(DEVICE_PATH)/system.prop

# Recovery - Use standard fstab for now
# TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/rootdir/etc/fstab.samsungexynos7870

# SELinux
BOARD_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy/vendor

# VINTF
DEVICE_MANIFEST_FILE := $(DEVICE_PATH)/manifest.xml
