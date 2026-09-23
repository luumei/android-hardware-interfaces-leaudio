# Porting

Collect:

```bash
adb shell getprop ro.vendor.product.cpu.abilist
adb shell service list | grep -E 'audio.core.IModule|bluetooth.audio'
adb shell dumpsys media.audio_policy | grep -i -E 'BLE_HEADSET|bt-le|le audio'
adb shell find /vendor/lib /vendor/lib64 -name '*bluetooth*audio*' 2>/dev/null
```

Check:

1. Audio Core AIDL version
2. 32-bit vs 64-bit userspace
3. Bluetooth Audio provider presence
4. `IModule/bluetooth` presence
5. required NDK library versions
6. VINTF/init/SELinux integration
