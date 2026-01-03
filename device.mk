# Inherit from universal7870-common
$(call inherit-product, device/samsung/universal7870-common/device-common.mk)

# Inherit from vendor blobs (if exists, otherwise it will be skipped or we should create dummy)
$(call inherit-product-if-exists, vendor/samsung/a6lte/a6lte-vendor.mk)

# Screen density
PRODUCT_AAPT_CONFIG := normal
PRODUCT_AAPT_PREF_CONFIG := xhdpi

# Bypass VINTF kernel check for legacy 3.18 kernel
PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS := false

# Device characteristics
PRODUCT_CHARACTERISTICS := phone

# Overlays
DEVICE_PACKAGE_OVERLAYS += $(LOCAL_PATH)/overlay

# Audio
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/configs/audio/audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_policy_configuration.xml

# Display
TARGET_SCREEN_HEIGHT := 1480
TARGET_SCREEN_WIDTH := 720
