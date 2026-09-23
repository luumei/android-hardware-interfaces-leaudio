#!/usr/bin/env bash
set -euo pipefail

AOSP="${AOSP:-$HOME/aosp}"
OUT="$AOSP/out"

CLANG="$AOSP/prebuilts/clang/host/linux-x86/clang-r563880c/bin/clang++"
AR="$AOSP/prebuilts/clang/host/linux-x86/clang-r563880c/bin/llvm-ar"

SERVICE_DIR="$OUT/soong/.intermediates/vendor/bluetoothaudio/android-bluetooth-audio-core-hal/bluetooth.audio.core.service/android_vendor_arm_armv7-a-neon"
RSP="$SERVICE_DIR/unstripped/bluetooth.audio.core.service.rsp"

REGISTER_OBJ="/tmp/register_plugin.o"

AUDIO_COMMON_DIR="$OUT/soong/.intermediates/hardware/interfaces/audio/aidl/android.hardware.audio.common-V4-ndk/android_vendor_arm_armv7-a-neon_static"
AUDIO_COMMON_A="/tmp/android.hardware.audio.common-V4-ndk.a"

BT_DIR="$OUT/soong/.intermediates/hardware/interfaces/bluetooth/audio/utils/libbluetooth_audio_session_aidl/android_vendor_arm_armv7-a-neon_shared"
BT_A="/tmp/libbluetooth_audio_session_aidl.a"
BT_RUST="$BT_DIR/generated_rust_staticlib/librustlibs.a"

BT_FLAGS="$OUT/soong/.intermediates/hardware/interfaces/bluetooth/audio/flags/btaudiohal_flags_c_lib/android_vendor_arm_armv7-a-neon_static/btaudiohal_flags_c_lib.a"

LC3="$OUT/soong/.intermediates/external/liblc3/liblc3/android_vendor_arm_armv7-a-neon_static/liblc3.a"
OPUS="$OUT/soong/.intermediates/external/opus-experimental/libopus-experimental/android_vendor_arm_armv7-a-neon_static/libopus-experimental.a"

UBSAN_MIN="$AOSP/prebuilts/clang/host/linux-x86/clang-r563880c/lib/clang/21/lib/linux/libclang_rt.ubsan_minimal-arm-android.a"

ALSA_DIR="$OUT/soong/.intermediates/system/media/alsa_utils/libalsautilsv2/android_vendor_arm_armv7-a-neon_static"
TINY_DIR="$OUT/soong/.intermediates/external/tinyalsa_new/libtinyalsav2/android_vendor_arm_armv7-a-neon_static"
NBAIO_DIR="$OUT/soong/.intermediates/frameworks/av/media/libnbaio/libnbaio_mono/android_vendor_arm_armv7-a-neon_shared_cfi"

ALSA_A="/tmp/libalsautilsv2.a"
TINY_A="/tmp/libtinyalsav2.a"
NBAIO_A="/tmp/libnbaio_mono.a"

ACONFIG="$OUT/soong/.intermediates/build/make/tools/aconfig/aconfig_storage_read_api/libaconfig_storage_read_api_cc/android_vendor_arm_armv7-a-neon_shared/libaconfig_storage_read_api_cc.so"

UBSAN_FULL="$OUT/soong/.intermediates/prebuilts/clang/host/linux-x86/libclang_rt.ubsan_standalone/android_vendor_arm_armv7-a-neon_shared/libclang_rt.ubsan_standalone-arm-android.so"

TMP_RSP="/tmp/bluetooth-plugin-pixel-watch.rsp"

OUT_SO="$AOSP/vendor/bluetoothaudio/android-bluetooth-audio-core-hal/android.hardware.bluetooth.audio_sw.so"

echo "[1/6] Checking inputs"

for f in \
    "$REGISTER_OBJ" \
    "$RSP" \
    "$BT_RUST" \
    "$BT_FLAGS" \
    "$LC3" \
    "$OPUS" \
    "$UBSAN_MIN" \
    "$ACONFIG" \
    "$UBSAN_FULL"
do
    test -e "$f" || { echo "Missing: $f"; exit 1; }
done


echo "[2/6] Creating static replacement archives"

rm -f \
    "$AUDIO_COMMON_A" \
    "$BT_A" \
    "$ALSA_A" \
    "$TINY_A" \
    "$NBAIO_A"

find "$AUDIO_COMMON_DIR/obj" -name '*.o' -print0 | \
    xargs -0 "$AR" rcs "$AUDIO_COMMON_A"

find "$BT_DIR/obj" -name '*.o' -print0 | \
    xargs -0 "$AR" rcs "$BT_A"

find "$ALSA_DIR/obj" -name '*.o' -print0 | \
    xargs -0 "$AR" rcs "$ALSA_A"

find "$TINY_DIR/obj" -name '*.o' -print0 | \
    xargs -0 "$AR" rcs "$TINY_A"

find "$NBAIO_DIR/obj" -name '*.o' -print0 | \
    xargs -0 "$AR" rcs "$NBAIO_A"


echo "[3/6] Preparing plugin response file"

tr ' ' '\n' < "$RSP" \
  | grep -v '/core/src/main.o' \
  | grep -v 'android.hardware.bluetooth.audio-V5-ndk.so' \
  | grep -v 'android.hardware.audio.core.sounddose-V3-ndk.so' \
  | grep -v 'android.media.audio.common.types-V4-ndk.so' \
  | grep -v 'libbluetooth_audio_session_aidl.so' \
  | grep -v 'libalsautilsv2.so' \
  | grep -v 'libtinyalsav2.so' \
  | grep -v 'libnbaio_mono.so' \
  > "$TMP_RSP"


echo "[4/6] Locating shared-library CRT"

CRTBEGIN=$(find "$OUT/soong/.intermediates/bionic/libc/crtbegin_so" \
    -name crtbegin_so.o | head -1)

CRTEND=$(find "$OUT/soong/.intermediates/bionic/libc/crtend_so" \
    -name crtend_so.o | head -1)

test -n "$CRTBEGIN"
test -n "$CRTEND"


echo "[5/6] Linking android.hardware.bluetooth.audio_sw.so"

cd "$AOSP"

"$CLANG" \
  --target=armv7a-linux-androideabi36 \
  "$CRTBEGIN" \
  "$REGISTER_OBJ" \
  @"$TMP_RSP" \
  "$AUDIO_COMMON_A" \
  -Wl,--start-group \
  "$BT_A" \
  "$BT_RUST" \
  "$BT_FLAGS" \
  "$LC3" \
  "$OPUS" \
  "$UBSAN_MIN" \
  "$ALSA_A" \
  "$TINY_A" \
  "$NBAIO_A" \
  -Wl,--end-group \
  "$ACONFIG" \
  "$UBSAN_FULL" \
  "$CRTEND" \
  -nostdlib \
  -shared \
  -Wl,--gc-sections \
  -Wl,-z,noexecstack \
  -Wl,-z,relro \
  -Wl,-z,now \
  -Wl,--build-id=md5 \
  -Wl,--hash-style=gnu \
  -Wl,--no-rosegment \
  -Wl,--pack-dyn-relocs=android+relr \
  -o "$OUT_SO"


echo "[6/6] Verification"

file "$OUT_SO"

echo
echo "=== EXPORT ==="
readelf -Ws "$OUT_SO" | grep registerIModuleBluetoothSWQti

echo
echo "=== BLE CONFIGURATION ==="
strings "$OUT_SO" | grep -E \
'BLE Headset Out|BLE Headset In|BLE Speaker Out|le audio input|le audio output'

echo
echo "=== SHA256 ==="
sha256sum "$OUT_SO"

echo
echo "=== NEEDED ==="
readelf -d "$OUT_SO" | grep NEEDED
