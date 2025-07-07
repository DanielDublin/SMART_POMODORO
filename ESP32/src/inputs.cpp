#include "inputs.h"
#include <ESP32Encoder.h>

// Button states
volatile bool blueButtonState = false;
volatile bool whiteButtonState = false;
volatile bool rotaryButtonState = false;

// Debounce variables
unsigned long lastBlueDebounceTime = 0;
unsigned long lastWhiteDebounceTime = 0;
unsigned long lastRotaryDebounceTime = 0;

// Rotary encoder
ESP32Encoder encoder;
volatile int rotaryValue = 0;
int lastRotaryPosition = 0;

void setupInputs() {
  Serial.println("Setting up inputs...");
  
  // Setup buttons with internal pullup resistors
  pinMode(BUTTON_BLUE, INPUT_PULLUP);
  pinMode(BUTTON_WHITE, INPUT_PULLUP);
  pinMode(ROT_SW, INPUT_PULLUP);
  
  // Setup rotary encoder 
  // Set encoder pins with explicit pullups
  pinMode(ROT_CLK, INPUT_PULLUP);
  pinMode(ROT_DT, INPUT_PULLUP);
  
  encoder.attachHalfQuad(ROT_CLK, ROT_DT);
  encoder.setCount(0);
  
  Serial.println("Inputs initialized");
}

void handleButtons() {
  // Read button states (active LOW because of pull-up resistors)
  int blueCurrent = digitalRead(BUTTON_BLUE);
  int whiteCurrent = digitalRead(BUTTON_WHITE);
  int rotarySwitchCurrent = digitalRead(ROT_SW);
  
  // Handle blue button with debounce
  if ((millis() - lastBlueDebounceTime) > DEBOUNCE_DELAY) {
    if (blueCurrent == BUTTON_ACTIVE_STATE && !blueButtonState) {
      blueButtonState = true;
      Serial.println("Blue button pressed");
      // Add your action here
    } else if (blueCurrent != BUTTON_ACTIVE_STATE && blueButtonState) {
      blueButtonState = false;
      Serial.println("Blue button released");
    }
    lastBlueDebounceTime = millis();
  }
  
  // Handle white button with debounce
  if ((millis() - lastWhiteDebounceTime) > DEBOUNCE_DELAY) {
    if (whiteCurrent == BUTTON_ACTIVE_STATE && !whiteButtonState) {
      whiteButtonState = true;
      Serial.println("White button pressed");
      // Add your action here
    } else if (whiteCurrent != BUTTON_ACTIVE_STATE && whiteButtonState) {
      whiteButtonState = false;
      Serial.println("White button released");
    }
    lastWhiteDebounceTime = millis();
  }
  
  // Handle rotary button with debounce
  if ((millis() - lastRotaryDebounceTime) > DEBOUNCE_DELAY) {
    // Serial.printf("rotarySwitchCurrent: %d\n", rotarySwitchCurrent);
    // Serial.printf("rotaryButtonState: %d\n", rotaryButtonState);
    if (rotarySwitchCurrent == BUTTON_ACTIVE_STATE && !rotaryButtonState) {
      rotaryButtonState = true;
      Serial.println("Rotary button pressed");
      // Add your action here
    } else if (rotarySwitchCurrent != BUTTON_ACTIVE_STATE && rotaryButtonState) {
      rotaryButtonState = false;
      Serial.println("Rotary button released");
    }
    lastRotaryDebounceTime = millis();
  }
}

int handleRotaryEncoder() {
  // Get encoder position
  int currentPosition = encoder.getCount();
  
  // Check if position changed
  if (currentPosition != lastRotaryPosition) {
    // Calculate change
    int change = currentPosition - lastRotaryPosition;
    if (abs(change) >= 2) {
    rotaryValue += change / 2;
    
    Serial.print("Rotary encoder value: ");
    Serial.println(rotaryValue);
    
    // Update stored position
    lastRotaryPosition = currentPosition;
    return change / 2;
    }
  }
  return 0;
}

bool isBlueButtonPressed() {
  return blueButtonState;
}

bool isWhiteButtonPressed() {
  return whiteButtonState;
}

bool isRotaryButtonPressed() {
  return rotaryButtonState;
}

int getRotaryValue() {
  return rotaryValue;
}

void resetRotaryValue() {
  rotaryValue = 0;
  encoder.setCount(0);
  lastRotaryPosition = 0;
} 