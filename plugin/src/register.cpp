#include <cstdint>

#include <android-base/logging.h>
#include <android/binder_manager.h>

#include "core-impl/Configuration.h"
#include "core-impl/Module.h"

using aidl::android::hardware::audio::core::Module;
using aidl::android::hardware::audio::core::internal::getConfiguration;

namespace {
constexpr const char* kInstance =
        "android.hardware.audio.core.IModule/bluetooth";
}

extern "C" int32_t registerIModuleBluetoothSWQti() {
    LOG(INFO) << "registerIModuleBluetoothSWQti called";

    auto config = getConfiguration(Module::Type::BLUETOOTH);
    if (!config) {
        LOG(ERROR) << "Could not create Bluetooth module configuration";
        return -1;
    }

    auto module = Module::createInstance(
            Module::Type::BLUETOOTH, std::move(config));

    if (!module) {
        LOG(ERROR) << "Could not create ModuleBluetooth";
        return -2;
    }

    const binder_status_t status =
            AServiceManager_addService(module->asBinder().get(), kInstance);

    if (status != STATUS_OK) {
        LOG(ERROR) << "Failed to register " << kInstance
                   << ", binder status=" << status;
        return -3;
    }

    LOG(INFO) << "Registered " << kInstance;
    return 0;
}
