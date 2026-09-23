# SELinux integration

The Bluetooth Audio Core bridge must not run in the `shell` SELinux domain.

Runtime testing on Pixel Watch 4 showed:

    scontext=u:r:shell:s0
    tcontext=u:object_r:hal_audio_service:s0
    avc: denied { add }

The stock Qualcomm audio HAL runs as:

    u:r:hal_audio_default:s0

Therefore the bridge executable should be labeled:

    u:object_r:hal_audio_default_exec:s0

Suggested file context:

    /vendor/bin/hw/bluetooth\.audio\.core\.service    u:object_r:hal_audio_default_exec:s0

When started by init with the appropriate policy, this allows the process to enter
the standard `hal_audio_default` domain instead of remaining in `shell`.

This requires integration into the device SELinux policy / vendor image.
It cannot be applied persistently from a normal ADB shell on a locked production device.
