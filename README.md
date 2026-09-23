# Android Audio Core Bluetooth HAL Bridge

Experimental AOSP-derived Android Audio Core Bluetooth HAL bridge for exposing Bluetooth / LE Audio through:

android.hardware.audio.core.IModule/bluetooth

The project was created while investigating LE Audio input support on the Google Pixel Watch 4.

## Pixel Watch 4 test device

- Google Pixel Watch 4 Wi-Fi
- Device: kenari_btwifi
- Android 17
- Build: CP3A.260905.002
- Samsung Galaxy Buds3 Pro

## Findings

The Pixel Watch 4 successfully establishes LE Audio and exposes:

android.hardware.bluetooth.audio.IBluetoothAudioProviderFactory/default

The Bluetooth Audio provider is declared as AIDL version 3.

However, the shipping device VINTF configuration does not expose:

android.hardware.audio.core.IModule/bluetooth

The Audio Core V4 device manifest contains:

- IModule/default
- IModule/r_submix
- IModule/usb

but not:

- IModule/bluetooth

The installed Android framework compatibility matrices explicitly include the bluetooth IModule instance.

## Runtime proof

An ARM32 Audio Core Bluetooth bridge was built and executed on a production Pixel Watch 4.

Observed log:

    Android Bluetooth Audio Core HAL starting
    Using existing IBluetoothAudioProviderFactory/default
    Failed to register android.hardware.audio.core.IModule/bluetooth, binder status=-1

This proves that the bridge:

- loads on the Pixel Watch 4
- resolves its runtime dependencies
- creates ModuleBluetooth
- reaches the existing Bluetooth Audio provider
- reaches Binder service registration

Registration from ADB fails because the process runs in the shell SELinux domain.

The binary was rebuilt using `scripts/build_pixel_watch_manual.sh`, and the rebuilt binary reproduced the same runtime behavior on the Pixel Watch 4.

Observed denial:

    avc: denied { add }
    scontext=u:r:shell:s0
    tcontext=u:object_r:hal_audio_service:s0
    tclass=service_manager
    permissive=0

The shipping Qualcomm Audio HAL runs instead as:

    u:r:hal_audio_default:s0

## Missing integration

Current observed path:

    Bluetooth / LE Audio stack
              |
              v
    IBluetoothAudioProviderFactory/default
              |
              v
    IModule/bluetooth                 MISSING
              |
              v
    AudioPolicy BLE devices           MISSING
              |
              v
    AudioRecord / AudioTrack

The production Pixel Watch 4 configuration also does not expose the required BLE AudioPolicy device ports, including:

- AUDIO_DEVICE_OUT_BLE_HEADSET
- AUDIO_DEVICE_OUT_BLE_SPEAKER
- AUDIO_DEVICE_IN_BLE_HEADSET

The existing Qualcomm bluetooth_qti AudioPolicy configuration contains classic A2DP and Hearing Aid ports, but no BLE_HEADSET input path.

## Bridge modification

The AOSP reference ModuleBluetooth implementation normally creates a Bluetooth Audio provider in-process.

The Pixel Watch 4 already provides:

android.hardware.bluetooth.audio.IBluetoothAudioProviderFactory/default

Therefore this project changes ModuleBluetooth to use the existing provider instead of creating a second provider.

The relevant behavior is:

    ModuleBluetooth::ModuleBluetooth(
            std::unique_ptr<Module::Configuration>&& config)
        : Module(Type::BLUETOOTH, std::move(config)) {
        LOG(INFO) << "Using existing IBluetoothAudioProviderFactory/default";
    }

## Required system integration

A complete device integration requires at least:

1. android.hardware.audio.core.IModule/bluetooth
2. Audio Core V4 vendor VINTF declaration
3. init service running in the appropriate Audio HAL SELinux domain
4. BLE AudioPolicy input/output ports
5. AUDIO_DEVICE_IN_BLE_HEADSET routing

An experimental VINTF fragment, init service and LE Audio policy configuration are included in this repository.

## Project layout

    core/
      src/
      init/
      vintf/
      policy/

    configs/
      generic-aidl-v4/
      pixel-watch-4/

    docs/
    scripts/

## Current status

- ARM32 bridge compilation: working
- Pixel Watch 4 executable loading: working
- Runtime library compatibility: verified
- ModuleBluetooth initialization: working
- Existing Bluetooth AIDL provider reuse: configured
- Binder registration from ADB shell: blocked by SELinux
- Device VINTF integration: missing on production firmware
- BLE headset input exposure: not yet testable
- Stereo L/R microphone PCM validation: not yet testable

## Goal

The next milestone is to run the bridge as a properly integrated Audio HAL service.

If integration succeeds, the tests are:

1. android.hardware.audio.core.IModule/bluetooth registers successfully
2. AUDIO_DEVICE_IN_BLE_HEADSET is instantiated
3. Android exposes TYPE_BLE_HEADSET to applications
4. channelCounts includes 2
5. AudioRecord can capture the Bluetooth LE Audio input
6. left and right earbud microphones are verified as distinct PCM channels

## Pixel Watch 4 test binary

A locally built ARM32 test binary has already been executed successfully on the watch up to Binder service registration.

Known SHA-256:

    7ee7f2ba4a8b85e92912b67684e7535425272eae4032a4bc0dab4796c309bca0

Build artifacts are intentionally excluded from this repository.

## Important

This project is experimental interoperability research.

No proprietary Google, Qualcomm or Samsung vendor binaries are included in this repository.

## License

See LICENSE.
