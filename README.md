# Pixel Watch 4 LE Audio Bluetooth Audio Core Bridge

Experimental Android Audio Core Bluetooth HAL bridge for exposing LE Audio
input/output through:

~~~text
android.hardware.audio.core.IModule/bluetooth
~~~

The project was developed while investigating LE Audio input on a Google
Pixel Watch 4 with Samsung Galaxy Buds3 Pro.

## Tested device

Current development target:

- Google Pixel Watch 4 Wi-Fi
- Device codename: `kenari_btwifi`
- Android 17
- Tested build: `CP3A.260905.002`
- Earbuds: Samsung Galaxy Buds3 Pro

This patchset is specifically based on the firmware and vendor configuration
observed on that build. Other builds or devices may use a different audio HAL
layout.

## Problem

On the tested Pixel Watch 4 firmware, the Bluetooth LE Audio profile itself
connects successfully.

Observed through `dumpsys bluetooth_manager`:

- LE Audio connected
- Buds3 Pro active as LE Audio device
- LE Audio used for the active Bluetooth audio path
- `IBluetoothAudioProviderFactory/default` is available

However, Android Audio Core does not expose:

~~~text
android.hardware.audio.core.IModule/bluetooth
~~~

and AudioPolicy does not instantiate BLE headset input/output devices.

As a result, applications do not receive a normal:

~~~text
AudioDeviceInfo.TYPE_BLE_HEADSET
~~~

input device from the Buds.

The production firmware instead exposes only the built-in watch microphone
and legacy/SCO-style Bluetooth input paths to applications.

## Vendor hook found on Pixel Watch 4

The Qualcomm vendor audio configuration contains an optional Bluetooth audio
plugin entry similar to:

~~~xml
<library
    name="btaudio_sw"
    libraryName="android.hardware.bluetooth.audio_sw.so"
    method="registerIModuleBluetoothSWQti"
    mandatory="false" />
~~~

The referenced shared library is not present on the tested production
firmware.

This repository implements a compatible plugin entry point:

~~~text
registerIModuleBluetoothSWQti
~~~

which creates and registers:

~~~text
android.hardware.audio.core.IModule/bluetooth
~~~

## Architecture

Intended integration path:

~~~text
Galaxy Buds3 Pro
        |
        v
Android Bluetooth LE Audio stack
        |
        v
IBluetoothAudioProviderFactory/default
        |
        v
android.hardware.bluetooth.audio_sw.so
        |
        v
registerIModuleBluetoothSWQti()
        |
        v
android.hardware.audio.core.IModule/bluetooth
        |
        +--> BLE Headset Out
        +--> BLE Speaker Out
        +--> BLE Headset In
~~~

The bridge uses the existing Bluetooth Audio Provider Factory already present
on the system rather than creating a second provider implementation.

## LE Audio configuration patch

The patch in:

~~~text
patches/0001-add-le-audio-ports.patch
~~~

extends the AOSP Bluetooth Audio Core example configuration with LE Audio
device ports and routes.

Added device ports:

~~~text
BLE Headset Out
BLE Speaker Out
BLE Headset In
~~~

Added mix ports:

~~~text
le audio output
le audio input
~~~

The BLE input profile advertises both mono and stereo PCM channel layouts.

That makes two-channel input possible at the Audio Core configuration level.

It does **not** by itself prove that the Samsung Galaxy Buds3 Pro deliver two
independent left/right microphone PCM streams to Android. That still requires
runtime verification on an integrated vendor/test build.

## VINTF

The repository contains:

~~~text
integration/pixel-watch-4/manifest_bluetooth_audio_core.xml
~~~

which declares:

~~~text
android.hardware.audio.core.IModule/bluetooth
~~~

for Audio Core AIDL version 4.

## Plugin source

Plugin entry point:

~~~text
plugin/src/register.cpp
~~~

The exported function is:

~~~text
registerIModuleBluetoothSWQti
~~~

matching the function name expected by the Pixel Watch Qualcomm vendor audio
configuration.

## Building

A manual ARM32 build helper is included:

~~~text
scripts/build_plugin_full_manual.sh
~~~

The tested Pixel Watch 4 userspace is 32-bit ARM, so the generated plugin must
be an ARM32 shared library.

Expected output:

~~~text
android.hardware.bluetooth.audio_sw.so
~~~

The binary itself is intentionally not committed to this repository.

A successful build should contain:

~~~text
registerIModuleBluetoothSWQti

BLE Headset Out
BLE Speaker Out
BLE Headset In
le audio output
le audio input
~~~

Example verification:

~~~bash
file android.hardware.bluetooth.audio_sw.so

readelf -Ws android.hardware.bluetooth.audio_sw.so \
  | grep registerIModuleBluetoothSWQti

strings android.hardware.bluetooth.audio_sw.so \
  | grep -E 'BLE Headset Out|BLE Headset In|BLE Speaker Out|le audio input|le audio output'
~~~

One locally tested build produced:

~~~text
SHA256:
53c35e4afd0d1956322693ca4b0f5cf5bd33382c39b71edac4e83af6bff0cc9d
~~~

This hash is provided only as a reference for that build.

## Expected vendor integration

For a Pixel Watch 4 vendor/test build, the plugin is intended to be installed
as:

~~~text
/vendor/lib/hw/android.hardware.bluetooth.audio_sw.so
~~~

The existing Qualcomm audio HAL loader can then load the library and resolve:

~~~text
registerIModuleBluetoothSWQti
~~~

The exact installation and SELinux policy must be integrated into the device
build. A locked production watch cannot normally replace files under
`/vendor`.

## SELinux

A standalone shell-side test successfully loaded the plugin and resolved the
exported function, but service registration from the `shell` SELinux domain
was denied.

That does not demonstrate that the intended vendor integration will fail.

The intended execution context is the vendor audio HAL process, not `shell`.

Additional SELinux rules should only be added when an integrated device build
produces a specific AVC denial. Broad permissive rules are intentionally not
included.

## Runtime success criteria

### 1. Audio Core Bluetooth module

~~~bash
adb shell "service list | grep android.hardware.audio.core.IModule"
~~~

Expected:

~~~text
android.hardware.audio.core.IModule/bluetooth
~~~

### 2. BLE AudioPolicy devices

~~~bash
adb shell "dumpsys media.audio_policy | grep -i -E 'BLE_HEADSET|BLE Headset|BLE Speaker|le audio'"
~~~

Expected BLE input/output ports should become visible.

### 3. Application device enumeration

A Wear OS application should see:

~~~text
AudioDeviceInfo.TYPE_BLE_HEADSET
~~~

for the Bluetooth input path.

### 4. Stereo capability

Check whether `channelCounts` contains:

~~~text
2
~~~

for the BLE headset input.

### 5. Actual left/right microphone separation

Finally record two-channel PCM and verify that the left and right channels are
actually different signals.

A stereo channel declaration alone is not proof that the earbuds expose two
independent microphone streams.

## Current status

Verified:

- LE Audio profile connects on Pixel Watch 4
- Galaxy Buds3 Pro become the active LE Audio Bluetooth device
- Bluetooth Audio Provider Factory exists
- production firmware does not expose `IModule/bluetooth`
- Qualcomm vendor configuration contains an optional plugin hook
- bridge plugin builds successfully as ARM32
- `registerIModuleBluetoothSWQti` is exported
- BLE input/output configuration is included in the built plugin
- stereo input is declared by the patched Audio Core configuration

Not yet verified on an integrated vendor build:

- successful registration of `IModule/bluetooth` inside the vendor audio HAL
  process
- creation of BLE headset AudioPolicy devices
- Android application access to `TYPE_BLE_HEADSET`
- two-channel `AudioRecord`
- independent left/right Buds3 Pro microphone PCM

## Purpose

The immediate motivation for this work is a low-latency hearing-assistance
application that can process Bluetooth earbud microphone audio in real time.

The bridge itself is generic and is not limited to that application.

## Disclaimer

This is experimental development work.

It modifies the Android vendor audio integration path and is not an official
Google, Qualcomm, Samsung, or AOSP component.

Do not flash binaries or vendor images built for a different device or build.
