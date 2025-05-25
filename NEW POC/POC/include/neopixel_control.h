#ifndef NEOPIXEL_CONTROL_H
#define NEOPIXEL_CONTROL_H

#include <Adafruit_NeoPixel.h>
#include "config.h"

void setupNeoPixel();
void updateNeoPixelEffects();
void setAllPixels(uint32_t color);
void setPixel(int pixel, uint32_t color);
void rainbowCycle(int wait);
void breatheEffect(uint32_t color, int wait);

#endif // NEOPIXEL_CONTROL_H 