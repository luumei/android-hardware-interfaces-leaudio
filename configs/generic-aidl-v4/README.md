# Generic AIDL v4 profile

For devices where:

- `android.hardware.audio.core` is AIDL v4
- `android.hardware.bluetooth.audio.IBluetoothAudioProviderFactory/default` exists
- `android.hardware.audio.core.IModule/bluetooth` is missing
- AudioPolicy cannot instantiate BLE headset devices

Verify before use:

```bash
adb shell service list | grep -E 'audio.core.IModule|bluetooth.audio'
adb shell dumpsys media.audio_policy | grep -i -E 'BLE_HEADSET|bt-le|le audio'
```
