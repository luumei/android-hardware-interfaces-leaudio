Write-Host "=== AUDIO CORE SERVICES ==="
adb shell "service list | grep -e android.hardware.audio.core.IModule -e android.hardware.bluetooth.audio.IBluetoothAudioProviderFactory"

Write-Host ""
Write-Host "=== EXPECTED BLUETOOTH MODULE ==="
adb shell "service list | grep android.hardware.audio.core.IModule/bluetooth"

Write-Host ""
Write-Host "=== VINTF ==="
adb shell "grep -R -n IModule/bluetooth /vendor/etc/vintf 2>/dev/null"

Write-Host ""
Write-Host "=== LE AUDIO BRIDGE LOGS ==="
adb shell "logcat -d -v threadtime | grep LeAudioBridge | tail -100"

Write-Host ""
Write-Host "=== AUDIO POLICY BLE ==="
adb shell "dumpsys media.audio_policy | grep -i -e BLE_HEADSET -e 'BLE Headset' -e 'BLE Speaker'"

Write-Host ""
Write-Host "=== BLUETOOTH STATE ==="
adb shell "dumpsys bluetooth_manager | grep -i -e 'LE Audio' -e mActiveAudioInDevice -e mActiveAudioOutDevice -e currentlyActiveGroupId"

Write-Host ""
Write-Host "=== DONE ==="
