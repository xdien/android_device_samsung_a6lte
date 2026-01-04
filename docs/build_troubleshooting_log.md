# Build Troubleshooting Log - Samsung Galaxy A6 (SM-A600G) LineageOS 18.1

This document tracks issues encountered during the build environment setup and compilation process, along with their solutions.

## 1. Build System Warnings
### Issue: "Trying dependencies-only mode on a non-existing device tree?"
**Symptoms:**  
Warning message appearing during `lunch` or build initialization.
**Cause:**  
LineageOS `roomservice` tool could not find the `a6lte` device tree in the upstream LineageOS repositories or local manifest, as we are using a manually cloned working-in-progress tree.
**Solution:**  
Created `.repo/local_manifests/roomservice.xml` to explicitly declare the local device tree and its dependencies. This tells the build system that the device tree is present and managed locally.

## 2. Resource Constraints
### Issue: Out of Memory (OOM) / Build Process Killed
**Symptoms:**  
Build process abruptly stops with "Got signal: interrupt" or exit code 137/130.
**Cause:**  
The build system defaults to using all available CPU threads. On a 16-thread machine with 32GB RAM, running 16+ heavily parallel jobs consumes more RAM than available (Android 11 build creates memory-hungry java processes).
**Solution:**  
Limited parallel jobs using the `-j` flag.
```bash
mka -j8 bacon
```

## 3. Environment Conflicts
### Issue: JAVAC Version Mismatch
**Symptoms:**  
Build failed with `warning: JAVAC does not match between Make and Soong`.
Make was using system Java (`/home/xdien/.gentoo/...`) while Soong expected LineageOS prebuilt JDK 11.
**Cause:**  
Gentoo system sets `JAVA_HOME` and `JAVAC` environment variables globally, preventing the build system from using its bundled JDK.
**Solution:**  
Unset confusing environment variables before building:
```bash
unset JAVA_HOME JAVAC
```

## 4. Vendor Tree Issues
### Issue: Makefile Syntax Errors (`missing endif`)
**Symptoms:**  
Build failed with `vendor/samsung/.../Android.mk: error: missing endif`.
**Cause:**  
The `extract-files.sh` script (or the templates it uses) generated `ifneq` blocks in multiple `Android.mk` files without closing them with `endif`.
**Solution:**  
Ran a batch fix command to append `endif` to offending makefiles:
```bash
find vendor/samsung -name "Android.mk" -exec sh -c 'if ! grep -q "^endif" "$1"; then echo -e "\nendif" >> "$1"; fi' _ {} \;
```

### Issue: Duplicate Module Definitions
**Symptoms:**  
Build failed with `module "..." already defined`.
**Cause:**  
Repeated runs of `extract-files.sh` without cleaning or manual inclusion of sub-makefiles caused duplicate entries or conflicting definitions in `Android.bp`.
**Solution:**  
Cleaned the `vendor/samsung` directory and re-ran extraction fresh. Checked `Android.bp` for duplicates.

### Issue: Missing Vendor Blobs (`.tlbin`, `.so`)
**Symptoms:**  
Ninja build failed with `missing and no known rule to make target ...`.
Specific missing files:
- `mcRegistry/*.tlbin` (Trustonic TEE applets)
- `libExynosHWCService.so` (Hardware Composer)
**Cause:**  
The proprietary blob list (`proprietary-files.txt`) or the extraction script logic did not account for all file locations in the Samsung stock firmware dump (e.g., some files were in `system/app` instead of `vendor/app`, or `samsung_slsi_oss` modules were skipped).
**Solution:**  
Manually copied missing files from the extracted stock firmware to the vendor tree:
```bash
cp extracted_firmware/system/app/mcRegistry/*.tlbin vendor/samsung/universal7870-common/secapp/proprietary/vendor/app/mcRegistry/
cp extracted_firmware/vendor/lib/libExynosHWCService.so vendor/samsung/universal7870-common/samsung_slsi_oss/proprietary/vendor/lib/
```
