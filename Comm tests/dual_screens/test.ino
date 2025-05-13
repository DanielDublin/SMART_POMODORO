#include <SPI.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <TFT_eSPI.h>
#include <PNGdec.h>
#include "images.h" // Make sure to have your images.h file in the same directory

// ILI9488 TFT Display Configuration (VSPI)
#define TFT_CS   15
#define TFT_RST  4
#define TFT_DC   2
#define TFT_LED  32
#define TFT_MOSI 23  // VSPI MOSI
#define TFT_SCLK 18  // VSPI SCK

// OLED Display Configuration (HSPI)
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
#define OLED_SCLK   14  // HSPI SCK
#define OLED_MOSI   13  // HSPI MOSI
#define OLED_CS     5
#define OLED_RES    16
#define OLED_DC     17

// TFT Configuration
#define MAX_IMAGE_WIDTH 480

// Create SPI instances
SPIClass * hspi = NULL;
SPIClass * vspi = NULL;

// Create display instances
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, OLED_MOSI, OLED_SCLK, OLED_DC, OLED_RES, OLED_CS);
TFT_eSPI tft = TFT_eSPI();
PNG png;

// Variables for PNG drawing
int16_t xpos = 0;
int16_t ypos = 0;

// Variables for OLED animation
#define NUMFLAKES     10 // Number of snowflakes in the animation example
#define LOGO_HEIGHT   16
#define LOGO_WIDTH    16
#define XPOS   0 // Indexes into the 'icons' array in function below
#define YPOS   1
#define DELTAY 2

static const unsigned char PROGMEM logo_bmp[] = {
  0b00000000, 0b11000000,
  0b00000001, 0b11000000,
  0b00000001, 0b11000000,
  0b00000011, 0b11100000,
  0b11110011, 0b11100000,
  0b11111110, 0b11111000,
  0b01111110, 0b11111111,
  0b00110011, 0b10011111,
  0b00011111, 0b11111100,
  0b00001101, 0b01110000,
  0b00011011, 0b10100000,
  0b00111111, 0b11100000,
  0b00111111, 0b11110000,
  0b01111100, 0b11110000,
  0b01110000, 0b01110000,
  0b00000000, 0b00110000
};

void testanimate(const uint8_t *bitmap, uint8_t w, uint8_t h);
void updateTFT();

void setup() {
  Serial.begin(115200);
  Serial.println("Starting...");

  // Initialize both SPI buses
  hspi = new SPIClass(HSPI);
  vspi = new SPIClass(VSPI);
  
  hspi->begin(OLED_SCLK, -1, OLED_MOSI, -1);  // HSPI for OLED
  vspi->begin(TFT_SCLK, -1, TFT_MOSI, -1);    // VSPI for TFT
  
  // Initialize OLED
  if(!display.begin(SSD1306_SWITCHCAPVCC)) {
    Serial.println(F("SSD1306 allocation failed"));
    for(;;);
  }
  Serial.println("OLED initialized");

  // Show initial display buffer contents on the screen
  display.clearDisplay();
  display.setTextSize(2);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0,0);
  display.println(F("Test"));
  display.display();
  delay(2000);

  // Draw a test pattern
  display.clearDisplay();
  for(int16_t i=0; i<display.width(); i+=4) {
    display.drawLine(0, 0, i, display.height()-1, SSD1306_WHITE);
    display.display();
    delay(50);
  }
  delay(2000);

  // Initialize TFT
  pinMode(TFT_LED, OUTPUT);
  digitalWrite(TFT_LED, HIGH);
  tft.setRotation(1);
  tft.begin();
  tft.fillScreen(TFT_BLACK);
  Serial.println("TFT initialized");

  // If we got here and saw the test pattern, start the animation
  Serial.println("Starting animation...");
  testanimate(logo_bmp, LOGO_WIDTH, LOGO_HEIGHT);
}

void loop() {
  // Empty - animation runs in testanimate
}

void pngDraw(PNGDRAW *pDraw) {
  uint16_t lineBuffer[MAX_IMAGE_WIDTH];
  png.getLineAsRGB565(pDraw, lineBuffer, PNG_RGB565_BIG_ENDIAN, 0xffffffff);
  tft.pushImage(xpos, ypos + pDraw->y, pDraw->iWidth, 1, lineBuffer);
}

void updateTFT() {
  int16_t rc = png.openFLASH((uint8_t *)images, sizeof(images), pngDraw);
  if (rc == PNG_SUCCESS) {
    tft.startWrite();
    rc = png.decode(NULL, 0);
    tft.endWrite();
  }
  delay(100);
  tft.fillScreen(random(0x10000));
}

void testanimate(const uint8_t *bitmap, uint8_t w, uint8_t h) {
  int8_t f, icons[NUMFLAKES][3];
  unsigned long lastTFTUpdate = 0;
  const unsigned long TFT_INTERVAL = 3000;

  // Initialize 'snowflake' positions
  for(f=0; f< NUMFLAKES; f++) {
    icons[f][XPOS]   = random(1 - LOGO_WIDTH, display.width());
    icons[f][YPOS]   = -LOGO_HEIGHT;
    icons[f][DELTAY] = random(1, 6);
    Serial.print(F("x: "));
    Serial.print(icons[f][XPOS], DEC);
    Serial.print(F(" y: "));
    Serial.print(icons[f][YPOS], DEC);
    Serial.print(F(" dy: "));
    Serial.println(icons[f][DELTAY], DEC);
  }

  for(;;) { // Loop forever...
    display.clearDisplay(); // Clear the display buffer

    // Draw each snowflake:
    for(f=0; f< NUMFLAKES; f++) {
      display.drawBitmap(icons[f][XPOS], icons[f][YPOS], bitmap, w, h, SSD1306_WHITE);
    }

    display.display(); // Show the display buffer on the screen
    delay(200);        // Pause for 1/10 second

    // Then update coordinates of each flake...
    for(f=0; f< NUMFLAKES; f++) {
      icons[f][YPOS] += icons[f][DELTAY];
      // If snowflake is off the bottom of the screen...
      if (icons[f][YPOS] >= display.height()) {
        // Reinitialize to a random position, just off the top
        icons[f][XPOS]   = random(1 - LOGO_WIDTH, display.width());
        icons[f][YPOS]   = -LOGO_HEIGHT;
        icons[f][DELTAY] = random(1, 6);
      }
    }

    // Update TFT if needed
    unsigned long currentMillis = millis();
    if (currentMillis - lastTFTUpdate >= TFT_INTERVAL) {
      updateTFT();
      lastTFTUpdate = currentMillis;
    }
  }
} 