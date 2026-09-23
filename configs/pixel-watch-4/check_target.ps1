Write-Host "=== CPU ABI ==="
adb shell getprop ro.vendor.product.cpu.abilist

Write-Host "`n=== Audio Core modules ==="
adb shell service list | Select-String "audio.core.IModule"

Write-Host "`n=== Bluetooth Audio provider ==="
adb shell service list | Select-String "bluetooth.audio"

Write-Host "`n=== BLE AudioPolicy ==="
adb shell dumpsys media.audio_policy |
    Select-String -Pattern "BLE_HEADSET","bt-le","le audio" -Context 2,5
