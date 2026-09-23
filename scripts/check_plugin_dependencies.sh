#!/usr/bin/env bash
set -euo pipefail

PLUGIN="${1:-android.hardware.bluetooth.audio_sw.so}"

if [ ! -f "$PLUGIN" ]; then
    echo "Missing plugin: $PLUGIN"
    exit 1
fi

echo "=== FILE ==="
file "$PLUGIN"

echo
echo "=== EXPORTED ENTRY POINT ==="
readelf -Ws "$PLUGIN" | grep registerIModuleBluetoothSWQti || {
    echo "ERROR: registerIModuleBluetoothSWQti not exported"
    exit 2
}

echo
echo "=== NEEDED LIBRARIES ==="
readelf -d "$PLUGIN" | grep NEEDED || true

echo
echo "=== BLE CONFIG STRINGS ==="
strings "$PLUGIN" | grep -E \
'BLE Headset Out|BLE Headset In|BLE Speaker Out|le audio input|le audio output'

echo
echo "=== SHA256 ==="
sha256sum "$PLUGIN"

echo
echo "=== DONE ==="
