#ifndef CONFIG_H
#define CONFIG_H

// OLED Display
#define OLED_CS   5     // Chip Select
#define OLED_RES  16    // Reset
#define OLED_DC   17    // Data/Command
#define OLED_SCLK 18    // Shared with TFT
#define OLED_MOSI 23    // Shared with TFT

// Rotary Encoder
#define ROT_CLK   26    // Clock
#define ROT_DT    27    // Data
#define ROT_SW    4     // Switch/Button 

// Audio (MAX98357A I2S Amplifier)
#define I2S_DOUT  13    // Data Out
#define I2S_BCLK  25    // Bit Clock
#define I2S_LRC   12    // Left/Right Clock

// NeoPixel LED Strip
#define LED_PIN   33    // Data pin
#define NUM_LEDS  2     // Number of LEDs
#define BRIGHTNESS 0  // Brightness (0-255)

// Push Buttons
#define BUTTON_BLUE  21     //was 36 UN
#define BUTTON_WHITE 22     //was 39 UP
#define BUTTON_ACTIVE_STATE LOW  // Buttons are active when pulled to ground

// Firebase Configuration
#define FIREBASE_API_KEY "XXXXXX"
#define FIREBASE_PROJECT_ID "XXX"
#define FIREBASE_DATABASE_URL "https://XXX-default-rtdb.firebaseio.com/"



#endif // CONFIG_H 