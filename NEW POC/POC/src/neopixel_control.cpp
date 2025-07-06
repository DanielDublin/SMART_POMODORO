#include "neopixel_control.h"
#include "inputs.h"

// Create NeoPixel object
Adafruit_NeoPixel strip(NUM_LEDS, LED_PIN, NEO_GRB + NEO_KHZ800);

// Effect variables
int effectMode = 0;
unsigned long lastEffectUpdate = 0;
int effectStep = 0;
boolean effectDirection = true;

void setupNeoPixel() {
  Serial.println("Setting up NeoPixel...");
  
  strip.begin();
  strip.setBrightness(BRIGHTNESS);
  strip.clear();
  strip.show();
  
  // Test all pixels
  for (int i = 0; i < NUM_LEDS; i++) {
    strip.setPixelColor(i, strip.Color(255, 0, 0)); // Red
    strip.show();
    delay(200);
    strip.setPixelColor(i, strip.Color(0, 255, 0)); // Green
    strip.show();
    delay(200);
    strip.setPixelColor(i, strip.Color(0, 0, 255)); // Blue
    strip.show();
    delay(200);
    strip.setPixelColor(i, strip.Color(0, 0, 0)); // Off
    strip.show();
  }
  setAllPixels(0,0,0);
  Serial.println("NeoPixel initialized");
}

void updateNeoPixelEffects() {
  // Change effect mode if rotary button is pressed
  if (isRotaryButtonPressed()) {
    effectMode = (effectMode + 1) % 4; // Cycle through effects
    effectStep = 0;
    // Serial.print("NeoPixel effect changed to: ");
    // Serial.println(effectMode);
    delay(200); // Prevent rapid mode changes
  }
  
  // Apply effects based on mode and current rotary value
  int rotaryVal = getRotaryValue() % 255; // Use rotary for effect parameters
  
  switch (effectMode) {
    case 0: // Solid color based on rotary value
      setAllPixels(strip.Color(rotaryVal, 255 - rotaryVal, 128));
      break;
      
    case 1: // Alternating colors
      if (millis() - lastEffectUpdate > 500) {
        if (effectStep == 0) {
          setPixel(0, strip.Color(255, 0, 0));
          setPixel(1, strip.Color(0, 0, 255));
        } else {
          setPixel(0, strip.Color(0, 0, 255));
          setPixel(1, strip.Color(255, 0, 0));
        }
        effectStep = 1 - effectStep; // Toggle between 0 and 1
        lastEffectUpdate = millis();
      }
      break;
      
    case 2: // Rainbow cycle
      rainbowCycle(20);
      break;
      
    case 3: // Breathing effect
      breatheEffect(strip.Color(0, 0, 255), 5);
      break;
  }
}

void setAllPixels(uint32_t color) {
  for (int i = 0; i < NUM_LEDS; i++) {
    strip.setPixelColor(i, color);
  }
  strip.show();
}

void setAllPixels(int r, int g, int b) {
  for (int i = 0; i < NUM_LEDS; i++) {
    strip.setPixelColor(i, strip.Color(r,g,b));
  }
  strip.show();
}

void setPixel(int pixel, uint32_t color) {
  if (pixel >= 0 && pixel < NUM_LEDS) {
    strip.setPixelColor(pixel, color);
    strip.show();
  }
}

// Slightly different, this makes the rainbow equally distributed throughout
void rainbowCycle(int wait) {
  if (millis() - lastEffectUpdate > wait) {
    for (int i = 0; i < NUM_LEDS; i++) {
      int pixelHue = (i * 65536 / NUM_LEDS + effectStep) % 65536;
      strip.setPixelColor(i, strip.gamma32(strip.ColorHSV(pixelHue)));
    }
    strip.show();
    effectStep = (effectStep + 256) % 65536;
    lastEffectUpdate = millis();
  }
}

void breatheEffect(uint32_t color, int wait) {
  if (millis() - lastEffectUpdate > wait) {
    // Breathing effect
    if (effectDirection) {
      effectStep++;
      if (effectStep >= 255) {
        effectDirection = false;
      }
    } else {
      effectStep--;
      if (effectStep <= 0) {
        effectDirection = true;
      }
    }
    
    // Extract RGB components
    uint8_t r = (uint8_t)(color >> 16);
    uint8_t g = (uint8_t)(color >> 8);
    uint8_t b = (uint8_t)color;
    
    // Scale by brightness
    float brightness = sin(effectStep * PI / 255) * sin(effectStep * PI / 255);
    uint8_t adjustedR = r * brightness;
    uint8_t adjustedG = g * brightness;
    uint8_t adjustedB = b * brightness;
    
    setAllPixels(strip.Color(adjustedR, adjustedG, adjustedB));
    lastEffectUpdate = millis();
  }
} 