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
#define ROT_SW    -1    // Switch/Button currently doesnt work

// Audio (MAX98357A I2S Amplifier)
#define I2S_DOUT  13    // Data Out
#define I2S_BCLK  25    // Bit Clock
#define I2S_LRC   12    // Left/Right Clock

// NeoPixel LED Strip
#define LED_PIN   33    // Data pin
#define NUM_LEDS   2    // Number of LEDs
#define BRIGHTNESS 20   // Brightness (0-255)

// Push Buttons
#define BUTTON_BLUE  21 // Blue button pin
#define BUTTON_WHITE 22 // White button pin
#define BUTTON_ACTIVE_STATE LOW  // Buttons are active when pulled to ground

// Firebase Configuration
#define FIREBASE_API_KEY "AIzaSyDeoMrCH0XKwA8cZ1g1KvUplpajqgxneds"
#define FIREBASE_PROJECT_ID "smart-pomodoro-2"
#define FIREBASE_DATABASE_URL "https://smart-pomodoro-2-default-rtdb.firebaseio.com/"
#define FIREBASE_USER_EMAIL "pomodoro@gmail.com"
#define FIREBASE_USER_PASSWORD "pomodoroisastrongpassword"

// Mascot Dialogue Constants
#define MASCOT_CHATBOX_X 20
#define MASCOT_CHATBOX_Y 210
#define MASCOT_CHATBOX_W 440
#define MASCOT_CHATBOX_H 100
#define MASCOT_TEXT_X 110
#define MASCOT_TEXT_Y 230
#define MASCOT_TEXT_MAX_COLS 22
#define MASCOT_TEXT_MAX_ROWS 3
#define MASCOT_FACE_X 35
#define MASCOT_FACE_Y 225
#define MASCOT_FACE_W 64
#define MASCOT_FACE_H 68

#endif // CONFIG_H