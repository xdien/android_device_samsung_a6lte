# Inherit from those products. Most specific first.

$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

# Inherit from a6lte device
$(call inherit-product, device/samsung/a6lte/device.mk)

# Inherit some common LineageOS stuff.
$(call inherit-product, vendor/lineage/config/common_full_phone.mk)

# Device identifier
PRODUCT_NAME := lineage_a6lte
PRODUCT_DEVICE := a6lte
PRODUCT_BRAND := samsung
PRODUCT_MODEL := SM-A600G
PRODUCT_MANUFACTURER := samsung

# Build fingerprint (from stock Android 10)
PRODUCT_BUILD_PROP_OVERRIDES += \
    PRIVATE_BUILD_DESC="a6ltexx-user 10 QP1A.190711.020 A600GDXUACVB2 release-keys"

BUILD_FINGERPRINT := samsung/a6ltexx/a6lte:10/QP1A.190711.020/A600GDXUACVB2:user/release-keys
