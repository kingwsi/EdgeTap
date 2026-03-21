#include "CMultitouchBridge.h"

#include <dlfcn.h>
#include <stdio.h>
#include <string.h>

typedef void *MTDeviceRef;

typedef struct {
    float x;
    float y;
} MTPoint;

typedef struct {
    MTPoint pos;
    MTPoint vel;
} MTReadout;

typedef struct {
    int32_t frame;
    double timestamp;
    int32_t identifier;
    int32_t state;
    int32_t foo3;
    int32_t foo4;
    MTReadout normalized;
    float size;
    int32_t zero1;
    float angle;
    float majorAxis;
    float minorAxis;
    MTReadout mm;
    int32_t zero2[2];
    float unk2;
} MTContact;

typedef MTDeviceRef (*MTDeviceCreateDefaultFn)(void);
typedef int (*MTContactCallbackFunction)(MTDeviceRef, MTContact *, int32_t, double, int32_t);
typedef void (*MTRegisterContactFrameCallbackFn)(MTDeviceRef, MTContactCallbackFunction);
typedef void (*MTUnregisterContactFrameCallbackFn)(MTDeviceRef, MTContactCallbackFunction);
typedef void (*MTDeviceStartFn)(MTDeviceRef, int32_t);
typedef void (*MTDeviceStopFn)(MTDeviceRef);

static void *gFrameworkHandle = NULL;
static MTDeviceRef gDevice = NULL;
static ETMTFrameHandler gFrameHandler = NULL;
static void *gFrameContext = NULL;
static MTRegisterContactFrameCallbackFn gRegisterCallback = NULL;
static MTUnregisterContactFrameCallbackFn gUnregisterCallback = NULL;
static MTDeviceStartFn gDeviceStart = NULL;
static MTDeviceStopFn gDeviceStop = NULL;

static void writeError(char *errorBuffer, int32_t errorBufferLength, const char *message) {
    if (errorBuffer == NULL || errorBufferLength <= 0) {
        return;
    }

    snprintf(errorBuffer, (size_t)errorBufferLength, "%s", message);
}

static int frameCallback(
    MTDeviceRef device,
    MTContact *contacts,
    int32_t count,
    double timestamp,
    int32_t frame
) {
    (void)device;
    (void)frame;

    if (gFrameHandler == NULL) {
        return 0;
    }

    if (contacts == NULL || count <= 0) {
        gFrameHandler(NULL, 0, timestamp, gFrameContext);
        return 0;
    }

    ETMTTouch translated[16];
    int32_t translatedCount = count > 16 ? 16 : count;

    for (int32_t index = 0; index < translatedCount; index++) {
        translated[index].identifier = contacts[index].identifier;
        translated[index].state = contacts[index].state;
        translated[index].x = contacts[index].normalized.pos.x;
        translated[index].y = contacts[index].normalized.pos.y;
        translated[index].size = contacts[index].size;
    }

    gFrameHandler(translated, translatedCount, timestamp, gFrameContext);
    return 0;
}

static bool loadFramework(char *errorBuffer, int32_t errorBufferLength) {
    if (gFrameworkHandle != NULL) {
        return true;
    }

    const char *paths[] = {
        "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport",
        "/System/Library/PrivateFrameworks/MultitouchSupport.framework/Versions/Current/MultitouchSupport",
        "/System/Library/PrivateFrameworks/MultitouchSupport.framework/Versions/A/MultitouchSupport"
    };

    for (size_t index = 0; index < sizeof(paths) / sizeof(paths[0]); index++) {
        gFrameworkHandle = dlopen(paths[index], RTLD_LAZY | RTLD_LOCAL);
        if (gFrameworkHandle != NULL) {
            break;
        }
    }

    if (gFrameworkHandle == NULL) {
        writeError(
            errorBuffer,
            errorBufferLength,
            "Unable to load MultitouchSupport.framework from known paths."
        );
        return false;
    }

    MTDeviceCreateDefaultFn createDefault = (MTDeviceCreateDefaultFn)dlsym(gFrameworkHandle, "MTDeviceCreateDefault");
    gRegisterCallback = (MTRegisterContactFrameCallbackFn)dlsym(
        gFrameworkHandle,
        "MTRegisterContactFrameCallback"
    );
    gUnregisterCallback = (MTUnregisterContactFrameCallbackFn)dlsym(
        gFrameworkHandle,
        "MTUnregisterContactFrameCallback"
    );
    gDeviceStart = (MTDeviceStartFn)dlsym(gFrameworkHandle, "MTDeviceStart");
    gDeviceStop = (MTDeviceStopFn)dlsym(gFrameworkHandle, "MTDeviceStop");

    if (createDefault == NULL || gRegisterCallback == NULL || gDeviceStart == NULL || gDeviceStop == NULL) {
        writeError(
            errorBuffer,
            errorBufferLength,
            "MultitouchSupport symbols are unavailable on this macOS build."
        );
        dlclose(gFrameworkHandle);
        gFrameworkHandle = NULL;
        gRegisterCallback = NULL;
        gUnregisterCallback = NULL;
        gDeviceStart = NULL;
        gDeviceStop = NULL;
        return false;
    }

    gDevice = createDefault();
    if (gDevice == NULL) {
        writeError(errorBuffer, errorBufferLength, "Failed to acquire the default multitouch device.");
        dlclose(gFrameworkHandle);
        gFrameworkHandle = NULL;
        return false;
    }

    return true;
}

bool ETMTIsAvailable(void) {
    return loadFramework(NULL, 0);
}

bool ETMTStart(ETMTFrameHandler handler, void *context, char *errorBuffer, int32_t errorBufferLength) {
    if (!loadFramework(errorBuffer, errorBufferLength)) {
        return false;
    }

    if (handler == NULL) {
        writeError(errorBuffer, errorBufferLength, "No frame handler was provided.");
        return false;
    }

    ETMTStop();

    gFrameHandler = handler;
    gFrameContext = context;

    gRegisterCallback(gDevice, frameCallback);
    gDeviceStart(gDevice, 0);
    return true;
}

void ETMTStop(void) {
    if (gDevice != NULL && gDeviceStop != NULL) {
        gDeviceStop(gDevice);
    }

    if (gDevice != NULL && gRegisterCallback != NULL && gUnregisterCallback != NULL) {
        gUnregisterCallback(gDevice, frameCallback);
    }

    gFrameHandler = NULL;
    gFrameContext = NULL;
}
