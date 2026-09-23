#!/bin/bash
set -euo pipefail

source build/envsetup.sh
m bluetooth.audio.core.service -j"$(nproc)"
