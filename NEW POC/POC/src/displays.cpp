#include "displays.h"

// Create shared SPI instance
SPIClass *vspi = NULL;

// Create display instances
Adafruit_SSD1306 oled(SCREEN_WIDTH, SCREEN_HEIGHT, &SPI, OLED_DC, OLED_RES, OLED_CS);
TFT_eSPI tft = TFT_eSPI();

// Animation variables
int animationFrame = 0;
unsigned long lastAnimationUpdate = 0;
const int ANIMATION_SPEED = 100; // ms between frames

// Simple logo bitmap for animation demo
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

void setupDisplays() {
  Serial.println("Setting up displays...");
  
  // Initialize SPI bus that both displays will share
  vspi = new SPIClass(VSPI);
  vspi->begin(TFT_SCLK, -1, TFT_MOSI, -1);    // VSPI for both displays
  
  // Initialize OLED display
  if(!oled.begin(SSD1306_SWITCHCAPVCC)) {
    Serial.println(F("SSD1306 allocation failed"));
    return;
  }
  
  oled.clearDisplay();
  oled.setTextColor(SSD1306_WHITE);
  oled.setTextSize(1);
  oled.setCursor(0, 0);
  oled.println("OLED Ready!");
  oled.display();
  
  // Initialize TFT display
  pinMode(TFT_LED, OUTPUT);
  digitalWrite(TFT_LED, LOW);  // Turn backlight off initially
  
  tft.init();
  tft.setRotation(1); // Landscape mode
  tft.fillScreen(TFT_BLACK);
  tft.setTextColor(TFT_WHITE, TFT_BLACK);  // Set text color with background
  tft.setTextSize(1);
  
  digitalWrite(TFT_LED, HIGH);  // Turn backlight on after initialization
  tft.setCursor(0, 0);
  tft.println("TFT Ready!");
  
  Serial.println("Displays initialized");
}

void updateDisplayAnimations() {
  // Update animations at the specified speed
  if (millis() - lastAnimationUpdate > ANIMATION_SPEED) {
    animationFrame = (animationFrame + 1) % 8; // 8 frames per animation cycle
    lastAnimationUpdate = millis();
    
    // Demo animations
    showOLEDAnimation(animationFrame);
    showTFTAnimation(animationFrame);
  }
}

void displayOLEDText(const String& text, int x, int y, int size, bool clear) {
  if (clear) {
    oled.clearDisplay();
  }
  
  oled.setTextSize(size);
  oled.setCursor(x, y);
  oled.println(text);
  oled.display();
}

void displayTFTText(const String& text, int x, int y, int size, uint16_t color, bool clear) {
  if (clear) {
    tft.fillScreen(TFT_BLACK);
  }
  
  tft.setTextSize(size);
  tft.setTextColor(color);
  tft.setCursor(x, y);
  tft.println(text);
}

void displayProgressBar(int percentage, bool onOLED) {
  percentage = constrain(percentage, 0, 100);
  
  if (onOLED) {
    int barWidth = (percentage * SCREEN_WIDTH) / 100;
    oled.clearDisplay();
    oled.drawRect(0, SCREEN_HEIGHT - 10, SCREEN_WIDTH, 8, SSD1306_WHITE);
    oled.fillRect(0, SCREEN_HEIGHT - 10, barWidth, 8, SSD1306_WHITE);
    oled.setCursor(0, 0);
    oled.print(percentage);
    oled.print("%");
    oled.display();
  } else {
    int barWidth = (percentage * tft.width()) / 100;
    tft.drawRect(0, tft.height() - 10, tft.width(), 8, TFT_WHITE);
    tft.fillRect(0, tft.height() - 10, barWidth, 8, TFT_BLUE);
    tft.setCursor(0, 0);
    tft.print(percentage);
    tft.print("%");
  }
}

void showOLEDAnimation(int frame) {
  oled.clearDisplay();
  
  // Simple animation - spinning bitmap
  int centerX = SCREEN_WIDTH / 2 - 8;
  int centerY = SCREEN_HEIGHT / 2 - 8;
  
  // Adjust position based on frame
  int offsetX = cos(frame * PI / 4) * 10;
  int offsetY = sin(frame * PI / 4) * 10;
  
  oled.drawBitmap(centerX + offsetX, centerY + offsetY, logo_bmp, 16, 16, SSD1306_WHITE);
  oled.display();
}

void showTFTAnimation(int frame) {
  int centerX = tft.width() / 2;
  int centerY = tft.height() / 2;
  int radius = 40;  // Larger radius for larger display
  
  // Erase previous frame with black circle
  tft.fillCircle(centerX, centerY, radius + 5, TFT_BLACK);
  
  // Draw new frame
  switch (frame % 4) {
    case 0:
      tft.fillCircle(centerX, centerY, radius, TFT_RED);
      break;
    case 1:
      tft.fillCircle(centerX, centerY, radius, TFT_GREEN);
      break;
    case 2:
      tft.fillCircle(centerX, centerY, radius, TFT_BLUE);
      break;
    case 3:
      tft.fillCircle(centerX, centerY, radius, TFT_YELLOW);
      break;
  }
} 