#include <SPI.h>
#include <U8g2lib.h>
#include <ESP32Encoder.h>
#include "Faces.h"

// Screen dimensions
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
#define BYTES_PER_ROW (SCREEN_WIDTH / 8) // 128 / 8 = 16 bytes per row

// Encoder pins
#define ENCODER_CLK 15  // CLK pin (D15)
#define ENCODER_DT  2   // DT pin (D2)
#define ENCODER_SW  4   // SW pin (D4)

// Define the SPI pins based on the wiring
#define OLED_MOSI   22  // D1 pin on OLED (MOSI)
#define OLED_CLK    23  // D0 pin on OLED (SCK)
#define OLED_DC     19  // DC pin on OLED
#define OLED_CS     18  // CS pin on OLED
#define OLED_RESET  21  // RES pin on OLED

// Bitmap array from Faces.h
extern const unsigned char anime_face_girl_1[] PROGMEM;
extern const unsigned char anime_face_girl_2[] PROGMEM;

// Array of 128×64 bitmaps
const unsigned char* bitmaps[] = {
  anime_face_girl_1,
  anime_face_girl_2
};
const int numBitmaps = sizeof(bitmaps) / sizeof(bitmaps[0]);

// Create U8g2 display object for SSD1309 (4-wire SPI)
U8G2_SSD1309_128X64_NONAME0_F_4W_SW_SPI display(U8G2_R0, OLED_CLK, OLED_MOSI, OLED_CS, OLED_DC, OLED_RESET);

ESP32Encoder encoder;
long currentIndex = 0;

void setup() {
  Serial.begin(115200);

  // --- Display init ---
  display.begin();
  display.setContrast(255); // Set maximum contrast (adjust if needed)
  display.clearBuffer();
  display.drawBitmap(0, 0, BYTES_PER_ROW, SCREEN_HEIGHT, bitmaps[currentIndex]);
  display.sendBuffer();

  // --- Encoder init ---
  ESP32Encoder::useInternalWeakPullResistors = puType::up;
  encoder.attachHalfQuad(ENCODER_DT, ENCODER_CLK);
  encoder.setCount(currentIndex);
}

void loop() {
  long pos = encoder.getCount();

  // Clamp within valid range
  if (pos < 0) {
    pos = 0;
    encoder.setCount(pos);
  } else if (pos >= numBitmaps) {
    pos = numBitmaps - 1;
    encoder.setCount(pos);
  }

  // Update display only if position changed
  if (pos != currentIndex) {
    currentIndex = pos;
    Serial.print("Showing frame #");
    Serial.println(currentIndex);

    display.clearBuffer();
    display.drawBitmap(0, 0, BYTES_PER_ROW, SCREEN_HEIGHT, bitmaps[currentIndex]);
    display.sendBuffer();
  }

  delay(50);  // Adjust as needed
}