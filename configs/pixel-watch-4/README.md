# Pixel Watch 4 target profile

Original bring-up target.

Observed characteristics:

- Audio Core AIDL v4
- 32-bit Android userspace
- existing `IBluetoothAudioProviderFactory/default`
- missing `IModule/bluetooth`
- BLE Audio profile can connect
- AudioPolicy cannot create BLE headset input/output devices

Keep Pixel-specific changes in this directory, not in `core/`.
