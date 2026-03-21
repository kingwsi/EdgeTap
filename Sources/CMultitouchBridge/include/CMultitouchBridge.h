#ifndef CMultitouchBridge_h
#define CMultitouchBridge_h

#include <stdbool.h>
#include <stdint.h>

typedef struct {
    int32_t identifier;
    int32_t state;
    float x;
    float y;
    float size;
} ETMTTouch;

typedef void (*ETMTFrameHandler)(
    const ETMTTouch *contacts,
    int32_t count,
    double timestamp,
    void *context
);

bool ETMTIsAvailable(void);
bool ETMTStart(ETMTFrameHandler handler, void *context, char *errorBuffer, int32_t errorBufferLength);
void ETMTStop(void);

#endif
