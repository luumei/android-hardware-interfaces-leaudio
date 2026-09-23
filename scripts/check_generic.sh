#!/bin/bash
set -e

adb shell service list | grep -E 'audio.core.IModule|bluetooth.audio' || true
adb shell dumpsys media.audio_policy | grep -i -E 'BLE_HEADSET|bt-le|le audio' || true
