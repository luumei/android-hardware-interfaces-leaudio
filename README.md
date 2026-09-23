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

## Pixel Watch 4 production firmware findings

The following behavior was verified directly on the tested Pixel Watch 4
production firmware.

### Audio Core VINTF

The installed Audio Core VINTF manifest declares:

~~~text
IConfig/default
IModule/default
IModule/r_submix
IModule/usb
~~~

It does **not** declare:

~~~text
IModule/bluetooth
~~~

The relevant production manifest is:

~~~text
/vendor/etc/vintf/manifest/manifest_audiocorehal_default.xml
~~~

### Registered services

The running system exposes:

~~~text
android.hardware.audio.core.IModule/default
android.hardware.audio.core.IModule/r_submix
android.hardware.audio.core.IModule/usb
android.hardware.bluetooth.audio.IBluetoothAudioProviderFactory/default
~~~

but no:

~~~text
android.hardware.audio.core.IModule/bluetooth
~~~

This is consistent with the missing Bluetooth Audio Core VINTF declaration.

### Qualcomm vendor plugin hook

The production Qualcomm vendor audio configuration contains:

~~~xml
<library name="btaudio_sw"
         libraryName="android.hardware.bluetooth.audio_sw.so"
         method="registerIModuleBluetoothSWQti"
         mandatory="false" />
~~~

The configuration file is:

~~~text
/vendor/etc/audio/sku_monaco/vendor_audio_interfaces.xml
~~~

The referenced plugin:

~~~text
android.hardware.bluetooth.audio_sw.so
~~~

is not present on the tested production firmware.

The `mandatory="false"` attribute allows the vendor audio HAL to start even
when this optional Bluetooth Audio Core plugin is absent.

### Audio HAL process

The production service runs as:

~~~text
audiohalservice.qti
~~~

under the SELinux domain:

~~~text
u:r:hal_audio_default:s0
~~~

The corresponding init service is:

~~~text
vendor.audio-hal-aidl
~~~

and runs:

~~~text
/vendor/bin/hw/audiohalservice.qti
~~~

### Confirmed integration gap

The production firmware therefore already contains:

~~~text
Bluetooth LE Audio stack
        |
        v
IBluetoothAudioProviderFactory/default
        |
        v
Qualcomm vendor audio HAL
        |
        v
optional btaudio_sw plugin hook
~~~

but is missing both:

~~~text
android.hardware.bluetooth.audio_sw.so
~~~

and:

~~~text
android.hardware.audio.core.IModule/bluetooth
~~~

from the device VINTF manifest.

This repository supplies source for the missing plugin and a matching VINTF
fragment.

### Expected integration sequence

A vendor/test build should integrate the bridge in this order:

~~~text
1. Install android.hardware.bluetooth.audio_sw.so
2. Declare IModule/bluetooth in device VINTF
3. Start audiohalservice.qti
4. Qualcomm loader reads vendor_audio_interfaces.xml
5. Loader resolves registerIModuleBluetoothSWQti()
6. Plugin registers IModule/bluetooth
7. AudioFlinger discovers the declared Bluetooth Audio Core module
8. AudioPolicy receives the BLE headset ports and routes
~~~

The intended plugin location for the tested 32-bit userspace is expected to
be under the vendor library path used by the Qualcomm loader, for example:

~~~text
/vendor/lib/hw/android.hardware.bluetooth.audio_sw.so
~~~

The exact final installation path should be confirmed from the device build
rules used by Google/Qualcomm.

### Remaining runtime validation

After integration, the following still need to be verified on-device:

~~~text
IModule/bluetooth appears in service list
AUDIO_DEVICE_OUT_BLE_HEADSET is instantiated
AUDIO_DEVICE_IN_BLE_HEADSET is instantiated
AudioDeviceInfo.TYPE_BLE_HEADSET becomes visible to apps
channelCounts includes 2
AudioRecord can open the BLE input
left/right microphone PCM streams are actually distinct
~~~

The current production firmware cannot validate these final steps because the
Bluetooth Audio Core plugin and VINTF instance are absent.

## Suggested vendor build integration

This repository contains a minimal example integration for a vendor/test build.

Files:

~~~text
integration/pixel-watch-4/Android.bp
integration/pixel-watch-4/device.mk.example
integration/pixel-watch-4/manifest_bluetooth_audio_core.xml
~~~

The intended build integration is:

~~~text
PRODUCT_PACKAGES += android.hardware.bluetooth.audio_sw
~~~

plus the VINTF fragment declaring:

~~~text
android.hardware.audio.core.IModule/bluetooth
~~~

The plugin is expected to install into the vendor library namespace and be
loaded by the Qualcomm `btaudio_sw` hook already present in:

~~~text
/vendor/etc/audio/sku_monaco/vendor_audio_interfaces.xml
~~~

The plugin emits diagnostic log messages prefixed with:

~~~text
LeAudioBridge:
~~~

so an integrated build can verify whether:

~~~text
registerIModuleBluetoothSWQti()
configuration creation
ModuleBluetooth creation
service registration
~~~

succeed or fail.

### Dependency verification

Run:

~~~bash
scripts/check_plugin_dependencies.sh android.hardware.bluetooth.audio_sw.so
~~~

to verify:

- ARM architecture
- exported Qualcomm entry point
- DT_NEEDED dependencies
- embedded BLE Audio Core port strings
- SHA256

### Runtime verification

On Windows with ADB:

~~~powershell
powershell -ExecutionPolicy Bypass -File integration/pixel-watch-4/test_runtime.ps1
~~~

A successful integration should show:

~~~text
android.hardware.audio.core.IModule/bluetooth
~~~

in the service list and BLE headset input/output ports in AudioPolicy.

The final stereo test must still verify that two advertised input channels
correspond to distinct left/right microphone PCM and are not duplicated mono.

## Suggested vendor build integration

This repository contains a minimal example integration for a vendor/test build.

Files:

~~~text
integration/pixel-watch-4/Android.bp
integration/pixel-watch-4/device.mk.example
integration/pixel-watch-4/manifest_bluetooth_audio_core.xml
~~~

The intended build integration is:

~~~text
PRODUCT_PACKAGES += android.hardware.bluetooth.audio_sw
~~~

plus the VINTF fragment declaring:

~~~text
android.hardware.audio.core.IModule/bluetooth
~~~

The plugin is expected to install into the vendor library namespace and be
loaded by the Qualcomm `btaudio_sw` hook already present in:

~~~text
/vendor/etc/audio/sku_monaco/vendor_audio_interfaces.xml
~~~

The plugin emits diagnostic log messages prefixed with:

~~~text
LeAudioBridge:
~~~

so an integrated build can verify whether:

~~~text
registerIModuleBluetoothSWQti()
configuration creation
ModuleBluetooth creation
service registration
~~~

succeed or fail.

### Dependency verification

Run:

~~~bash
scripts/check_plugin_dependencies.sh android.hardware.bluetooth.audio_sw.so
~~~

to verify:

- ARM architecture
- exported Qualcomm entry point
- DT_NEEDED dependencies
- embedded BLE Audio Core port strings
- SHA256

### Runtime verification

On Windows with ADB:

~~~powershell
powershell -ExecutionPolicy Bypass -File integration/pixel-watch-4/test_runtime.ps1
~~~

A successful integration should show:

~~~text
android.hardware.audio.core.IModule/bluetooth
~~~

in the service list and BLE headset input/output ports in AudioPolicy.

The final stereo test must still verify that two advertised input channels
correspond to distinct left/right microphone PCM and are not duplicated mono.
