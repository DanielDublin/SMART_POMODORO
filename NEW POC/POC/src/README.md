# ESP32 Proof of Concept

A modular ESP32 project demonstrating integration of WiFi, Bluetooth, Firebase, displays, buttons, rotary encoder, and NeoPixel LEDs.

## Hardware Requirements

- ESP32 DevKit v1
- OLED Display (SSD1306)
- ILI9488 TFT Display
- 2 Push Buttons (Blue and White)
- Rotary Encoder
- NeoPixel LED Strip (2 LEDs)
- MAX98357A I2S Amplifier (optional for audio)

## Pin Connections

### Display Pins:
- **TFT Display (ILI9488):**
  - TFT_CS: GPIO 15 (Chip Select)
  - TFT_DC: GPIO 2 (Data/Command)
  - TFT_RST: GPIO 4 (Reset)
  - TFT_LED: GPIO 32 (Backlight control)
  - TFT_SCLK: GPIO 18 (Shared clock with OLED)
  - TFT_MOSI: GPIO 23 (Shared data with OLED)

- **OLED Display (SSD1306):**
  - OLED_CS: GPIO 5 (Chip Select)
  - OLED_RES: GPIO 16 (Reset)
  - OLED_DC: GPIO 17 (Data/Command)
  - OLED_SCLK: GPIO 18 (Shared with TFT)
  - OLED_MOSI: GPIO 23 (Shared with TFT)

### Input Pins:
- **Rotary Encoder:**
  - ROT_CLK: GPIO 26 (Clock)
  - ROT_DT: GPIO 27 (Data)
  - ROT_SW: GPIO 4 (Switch/Button)

- **Push Buttons:**
  - BUTTON_BLUE: GPIO 36
  - BUTTON_WHITE: GPIO 39

### NeoPixel LED Strip:
- LED_PIN: GPIO 33 (Data pin)

### Audio max98375(Optional):
- I2S_DOUT: GPIO 13 (Data Out)
- I2S_BCLK: GPIO 25 (Bit Clock)
- I2S_LRC: GPIO 12 (Left/Right Clock)

## Required Libraries

- WiFiManager by tzapu
- Firebase ESP Client by mobizt
- Adafruit GFX Library
- Adafruit SSD1306
- TFT_eSPI by Bodmer
- Adafruit NeoPixel
- ESP32Encoder by Kevin Harrington

## TFT_eSPI Configuration

This project uses the TFT_eSPI library for the ILI9488 display. The necessary configuration files are included:
- `User_Setup.h`: Configures the pins and features for the ILI9488 display
- `user_setup_select.h`: Selects the appropriate setup file for the display

These configuration files should be placed in the TFT_eSPI library folder. Alternatively, you can modify your existing configuration files to match the pin definitions in this project.

## Setup Instructions

1. Connect the hardware according to the pin mapping above
2. Install all required libraries using the Arduino Library Manager
3. Configure the TFT_eSPI library (see above)
4. Update the Firebase configuration in `config.h` if needed
5. Upload the code to your ESP32

## WiFi Configuration

On first boot, the ESP32 will create a WiFi access point named "ESP32_POC".
Connect to this network and navigate to 192.168.4.1 to configure your WiFi credentials.

## Usage

- **Blue Button**: Toggle between display modes
- **White Button**: Toggle between Firebase read/write modes
- **Rotary Encoder Rotation**: Adjust values (affects NeoPixel color, display animations)
- **Rotary Encoder Button**: Cycle through NeoPixel effects

## Project Structure

- `POC.ino`: Main Arduino sketch file
- `config.h`: Pin definitions and configuration
- `wifi_manager.h/cpp`: WiFi and Bluetooth functionality
- `firebase_handler.h/cpp`: Firebase integration
- `displays.h/cpp`: OLED and TFT display handling
- `inputs.h/cpp`: Buttons and rotary encoder handling
- `neopixel_control.h/cpp`: NeoPixel LED control

## Display Setup

This project uses a shared SPI bus for both displays:
- Both displays share the same SCLK (GPIO 18) and MOSI (GPIO 23) pins
- Each display has its own CS pin to enable/disable it when needed
- The TFT display uses the VSPI bus of the ESP32

## Firebase Integration

The project connects to Firebase Realtime Database for data storage and retrieval.
To use your own Firebase project, update the configuration in `config.h`.

## Notes

- Both displays share the same SPI bus (SCLK and MOSI pins) but have separate CS pins
- Press the rotary encoder button to cycle through different NeoPixel effects
- Use the blue and white buttons to trigger different functions
- The ESP32 will reconnect to WiFi automatically if the connection is lost 