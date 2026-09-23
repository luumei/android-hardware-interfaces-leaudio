#include <aidl/android/hardware/audio/core/IModule.h>
#include <android/binder_manager.h>
#include <android/binder_process.h>
#include <android-base/logging.h>

#include "Configuration.h"
#include "Module.h"

using aidl::android::hardware::audio::core::IModule;
using aidl::android::hardware::audio::core::Module;
using aidl::android::hardware::audio::core::internal::getConfiguration;

namespace {

constexpr const char* kInstance =
        "android.hardware.audio.core.IModule/bluetooth";

}

extern "C" int32_t registerIModuleBluetoothSWQti() {
    LOG(INFO) << "LeAudioBridge: registerIModuleBluetoothSWQti called";

    if (AServiceManager_isDeclared(kInstance)) {
        ndk::SpAIBinder existing(AServiceManager_checkService(kInstance));

        if (existing.get() != nullptr) {
            LOG(INFO) << "LeAudioBridge: " << kInstance
                      << " already registered";
            return 0;
        }

        LOG(INFO) << "LeAudioBridge: " << kInstance
                  << " declared in VINTF and not yet registered";
    } else {
        LOG(WARNING) << "LeAudioBridge: " << kInstance
                     << " is not declared in VINTF";
    }

    LOG(INFO) << "LeAudioBridge: creating Bluetooth module configuration";

    auto config = getConfiguration(Module::Type::BLUETOOTH);
    if (!config) {
        LOG(ERROR) << "LeAudioBridge: could not create Bluetooth configuration";
        return -1;
    }

    LOG(INFO) << "LeAudioBridge: Bluetooth configuration created";

    auto module = Module::createInstance(
            Module::Type::BLUETOOTH,
            std::move(config));

    if (!module) {
        LOG(ERROR) << "LeAudioBridge: could not create ModuleBluetooth";
        return -2;
    }

    LOG(INFO) << "LeAudioBridge: ModuleBluetooth instance created";
    LOG(INFO) << "LeAudioBridge: registering " << kInstance;

    const binder_status_t status =
            AServiceManager_addService(module->asBinder().get(), kInstance);

    if (status != STATUS_OK) {
        LOG(ERROR) << "LeAudioBridge: registration failed for "
                   << kInstance
                   << ", binder status=" << status;
        return -3;
    }

    LOG(INFO) << "LeAudioBridge: registration successful for "
              << kInstance;

    return 0;
}
