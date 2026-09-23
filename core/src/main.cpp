#include <cstdlib>

#include <android-base/logging.h>
#include <android/binder_manager.h>
#include <android/binder_process.h>

#include "core-impl/Configuration.h"
#include "core-impl/Module.h"

using aidl::android::hardware::audio::core::Module;
using aidl::android::hardware::audio::core::internal::getConfiguration;

namespace {
constexpr const char* kInstance =
        "android.hardware.audio.core.IModule/bluetooth";
}

int main() {
    android::base::SetMinimumLogSeverity(android::base::DEBUG);

    ABinderProcess_setThreadPoolMaxThreadCount(8);
    ABinderProcess_startThreadPool();

    LOG(INFO) << "Android Bluetooth Audio Core HAL starting";

    auto config = getConfiguration(Module::Type::BLUETOOTH);
    if (!config) {
        LOG(ERROR) << "Could not create Bluetooth audio module configuration";
        return EXIT_FAILURE;
    }

    auto module = Module::createInstance(
            Module::Type::BLUETOOTH, std::move(config));
    if (!module) {
        LOG(ERROR) << "Could not create ModuleBluetooth";
        return EXIT_FAILURE;
    }

    const binder_status_t status =
            AServiceManager_addService(module->asBinder().get(), kInstance);

    if (status != STATUS_OK) {
        LOG(ERROR) << "Failed to register " << kInstance
                   << ", binder status=" << status;
        return EXIT_FAILURE;
    }

    LOG(INFO) << "Registered " << kInstance;
    ABinderProcess_joinThreadPool();
    return EXIT_FAILURE;
}
