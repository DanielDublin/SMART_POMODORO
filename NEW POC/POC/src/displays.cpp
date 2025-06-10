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
  
  // Initialize OLED display with SPI
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
  tft.setRotation(3); // Landscape mode
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

void clearTFTScreen() {
  tft.fillScreen(TFT_BLACK);
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

void drawTextWithBox(const String& text, int x, int y, int size, uint16_t textColor, uint16_t boxColor) {
  // Set font size
  tft.setTextSize(size);
  tft.setTextColor(textColor, TFT_BLACK); // With background for clean redraw
  tft.setCursor(x, y);
  tft.println(text);

  // Estimate width and height of the text
  int textWidth = text.length() * 6 * size;  // 6 pixels per char at size 1
  int textHeight = 8 * size;                // 8 pixels per line at size 1

  // Draw rectangle around it
  tft.drawRect(x - 2, y - 2, textWidth + 4, textHeight + 4, boxColor);
}

int centerTextX(const String& text, int textSize) {
  int charWidth = 6 * textSize;  // Default 6 pixels wide per char
  return (ILI_SCREEN_WIDTH - text.length() * charWidth) / 2;
}

void drawMenu(const String options[], int numOfOptions, int selected, int startY, bool redraw) {
  static int lastSelected = -1;  // Keep track of last selected item
  
  // Calculate maximum width needed for any option
  int maxWidth = 0;
  int textSize = 2;  // Text size used for menu items
  for (int i = 0; i < numOfOptions; i++) {
    int width = options[i].length() * 6 * textSize;  // 6 pixels per char at size 1
    if (width > maxWidth) {
      maxWidth = width;
    }
  }
  
  // Add padding for the box
  maxWidth += 8;  // 4 pixels padding on each side
  
  for (int i = 0; i < numOfOptions; i++) {
    // Only redraw if it's a full redraw or if this item's selection state has changed
    if (redraw || i == selected || i == lastSelected) {
      uint16_t boxColor = (i == selected) ? TFT_GREEN : TFT_BLACK;
      int x = centerTextX(options[i], textSize);
      
      // Clear only the menu item area
      tft.fillRect(x - 4, startY + i * 30 - 2, maxWidth, textSize * 8 + 4, TFT_BLACK);
      
      // Draw the text and box
      drawTextWithBox(options[i], x, startY + i * 30, textSize, TFT_WHITE, boxColor);
    }
  }
  
  lastSelected = selected;  // Remember current selection for next time
}

void drawValues(int values[], int valuesSize, const String options[], int optionsSize, int selected, int startY, bool redraw) {
  static int lastSelected = -1;  // Keep track of last selected item
  
  // Draw values
  for (int i = 0; i < valuesSize; i++) {
    if (redraw || i == selected || i == lastSelected) {
      uint16_t boxColor = (i == selected) ? TFT_GREEN : TFT_BLACK;
      // Clear only the value area
      tft.fillRect(350 - 4, startY + i * 50 - 2, 100, 24, TFT_BLACK);
      drawTextWithBox(String(values[i], 10), 350, startY + i * 50, 2, TFT_WHITE, boxColor);
    }
  }
  
  // Draw options
  for (int i = valuesSize; i < optionsSize + valuesSize; i++) {
    if (redraw || i == selected || i == lastSelected) {
      uint16_t boxColor = (i == selected) ? TFT_GREEN : TFT_BLACK;
      int x = centerTextX(options[i - valuesSize], 2);
      // Clear only the option area
      tft.fillRect(x - 4, startY + i * 50 - 2, options[i - valuesSize].length() * 12 + 8, 24, TFT_BLACK);
      drawTextWithBox(options[i - valuesSize], x, startY + i * 50, 2, TFT_WHITE, boxColor);
    }
  }
  
  lastSelected = selected;  // Remember current selection for next time
}

void clearTFTArea(int x, int y, int width, int height) {
  tft.fillRect(x, y, width, height, TFT_BLACK);
}

int getDigitWidth(int textSize) {
  return 6 * textSize; // Each digit is approximately 6 pixels wide at size 1
}

int getDigitHeight(int textSize) {
  return 8 * textSize; // Each digit is approximately 8 pixels high at size 1
}

void displayTFTDigit(char digit, int x, int y, int size, uint16_t color) {
  // Clear just the area for this digit
  clearTFTArea(x, y, getDigitWidth(size), getDigitHeight(size));
  
  // Display the new digit
  tft.setTextSize(size);
  tft.setTextColor(color);
  tft.setCursor(x, y);
  tft.print(digit);
}

void displayTFTTimer(const String& newTime, const String& oldTime, int x, int y, int size, uint16_t color) {
  int digitWidth = getDigitWidth(size);
  int colonWidth = digitWidth; // Colon takes approximately same width as a digit
  
  // Only update digits that have changed
  for (int i = 0; i < newTime.length(); i++) {
    if (oldTime.length() != newTime.length() || oldTime[i] != newTime[i]) {
      int digitX = x + (i * digitWidth);
      // If it's the colon position, adjust spacing
      if (i > 1) {
        digitX += colonWidth/2;
      }
      displayTFTDigit(newTime[i], digitX, y, size, color);
    }
  }
}

void clearOLEDScreen() {
  oled.clearDisplay();
  oled.display();
}

void displayOLEDFace(FaceType face) {
  clearOLEDScreen();
  
  switch(face) {
    case FACE_FOCUSED:
      oled.drawBitmap(0, 0, anime_face_girl_1, SCREEN_WIDTH, SCREEN_HEIGHT, SSD1306_WHITE);
      break;
      
    case FACE_TIRED:
      oled.drawBitmap(0, 0, anime_face_girl_2, SCREEN_WIDTH, SCREEN_HEIGHT, SSD1306_WHITE);
      break;
  }
  
  oled.display();
}