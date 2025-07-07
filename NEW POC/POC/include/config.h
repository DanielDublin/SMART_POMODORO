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
#define ROT_SW    -1    // Switch/Button currently not in use

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

// I2S configuration
#define I2S_NUM              I2S_NUM_0
#define I2S_SAMPLE_RATE      44100
#define I2S_BITS_PER_SAMPLE  I2S_BITS_PER_SAMPLE_16BIT
#define I2S_BCLK             25  // Bit clock pin
#define I2S_LRC              12  // Left/right clock pin
#define I2S_DOUT             13  // Data out pin

// I2S communication format
#define I2S_COMM_FORMAT      I2S_COMM_FORMAT_STAND_I2S

// DMA buffer configuration
#define I2S_DMA_BUF_COUNT    4
#define I2S_DMA_BUF_LEN      1024

// Define OLED display dimensions
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
#define TFT_LED 32
#define OLED_NEW_LINE 16
// Define credentials for the ESP32's configuration AP
#define CONFIG_AP_SSID "AutoConnectAP" // AP name for configuration portal

// Define TFT display dimensions
#define ILI_SCREEN_WIDTH 480
#define ILI_SCREEN_HIEGHT 320

//User choices for the options on the screen
#define FIRST_OPTION 0
#define SECOND_OPTION 1
#define CONFIRM 4
#define RETURN 5

//Intervals for updating screens/checking if data was updated in db
#define FACE_UPDATE_INTERVAL 10000
#define POLLING_INTERVAL 5000
#define UPDATE_TIME 2000


#define ANIMATION_SPEED 100 // ms between frames

#define DEBOUNCE_DELAY 50  //delay so that to roter will read one value at a time

#define PORTAL_TIMEOUT 300000 // 300 seconds to connect to the wifi
#endif // CONFIG_H