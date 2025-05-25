#ifndef INPUTS_H
#define INPUTS_H

#include <Arduino.h>
#include "config.h"

void setupInputs();
void handleButtons();
int handleRotaryEncoder();

// Button states
bool isBlueButtonPressed();
bool isWhiteButtonPressed();
bool isRotaryButtonPressed();

// Rotary encoder values
int getRotaryValue();
void resetRotaryValue();

#endif // INPUTS_H 