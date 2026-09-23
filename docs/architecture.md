# Architecture

```text
Bluetooth LE Audio device
        |
        v
IBluetoothAudioProviderFactory/default
        |
        v
IModule/bluetooth
        |
        v
Android AudioPolicy
        |
        +--> AUDIO_DEVICE_OUT_BLE_HEADSET
        +--> AUDIO_DEVICE_IN_BLE_HEADSET
        |
        v
AudioTrack / AudioRecord
```

The project reuses AOSP `ModuleBluetooth` / `StreamBluetooth`.
