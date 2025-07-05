#include "displays.h"
#include <FS.h>
#include <SPIFFS.h>
#include <PNGdec.h>

// Create shared SPI instance
SPIClass *vspi = NULL;

// Create display instances
Adafruit_SSD1306 oled(SCREEN_WIDTH, SCREEN_HEIGHT, &SPI, OLED_DC, OLED_RES, OLED_CS);
TFT_eSPI tft = TFT_eSPI();
uint16_t lineBuffer[MASCOT_FACE_W];
uint16_t rowBuffer[MASCOT_FACE_W];


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

int32_t drawPixel(int32_t x, int32_t y, uint16_t r, uint16_t g, uint16_t b, uint16_t a) {
  if (x < 0 || x >= MASCOT_FACE_W || y < 0 || y >= MASCOT_FACE_H) {
    return 0; // Skip pixels outside the image bounds
  }
  // Convert RGB888 to RGB565
  uint16_t color = ((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3);
  rowBuffer[x] = color;
  return 0;
}


void setupDisplays() {
  Serial.println("Setting up displays...");
  
  vspi = new SPIClass(VSPI);
  vspi->begin(TFT_SCLK, -1, TFT_MOSI, -1);    // VSPI for both displays
  
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
  
  pinMode(TFT_LED, OUTPUT);
  digitalWrite(TFT_LED, LOW);  // Turn backlight off initially
  
  tft.init();
  tft.setRotation(3); // Landscape mode
  tft.fillScreen(TFT_BLACK);
  tft.setTextColor(TFT_WHITE, TFT_BLACK);
  tft.setTextSize(1);
  
  digitalWrite(TFT_LED, HIGH);  // Turn backlight on after initialization
  tft.setCursor(0, 0);
  tft.println("TFT Ready!");
  
  Serial.println("Displays initialized");
}

void updateDisplayAnimations() {
  if (millis() - lastAnimationUpdate > ANIMATION_SPEED) {
    animationFrame = (animationFrame + 1) % 8;
    lastAnimationUpdate = millis();
    
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
    tft.drawRect(0, 200, tft.width(), 8, TFT_WHITE);
    tft.fillRect(0, 200, barWidth, 8, TFT_BLUE);
    tft.setCursor(220, 220);
    tft.print(percentage);
    tft.print("%");
  }
}

void showOLEDAnimation(int frame) {
  oled.clearDisplay();
  
  int centerX = SCREEN_WIDTH / 2 - 8;
  int centerY = SCREEN_HEIGHT / 2 - 8;
  
  int offsetX = cos(frame * PI / 4) * 10;
  int offsetY = sin(frame * PI / 4) * 10;
  
  oled.drawBitmap(centerX + offsetX, centerY + offsetY, logo_bmp, 16, 16, SSD1306_WHITE);
  oled.display();
}

void showTFTAnimation(int frame) {
  int centerX = tft.width() / 2;
  int centerY = tft.height() / 2;
  int radius = 40;
  
  tft.fillCircle(centerX, centerY, radius + 5, TFT_BLACK);
  
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
  tft.setTextSize(size);
  tft.setTextColor(textColor, TFT_BLACK);
  tft.setCursor(x, y);
  tft.println(text);

  int textWidth = text.length() * 6 * size;
  int textHeight = 8 * size;

  tft.drawRect(x - 2, y - 2, textWidth + 4, textHeight + 4, boxColor);
}

int centerTextX(const String& text, int textSize) {
  int charWidth = 6 * textSize;
  return (ILI_SCREEN_WIDTH - text.length() * charWidth) / 2;
}

void drawMenu(const std::vector<String> options, int selected, int startY, bool redraw) {
  static int lastSelected = -1;
  
  int maxWidth = 0;
  int textSize = 2;
  for (int i = 0; i < options.size(); i++) {
    int width = options[i].length() * 6 * textSize;
    if (width > maxWidth) {
      maxWidth = width;
    }
  }
  
  maxWidth += 8;
  
  for (int i = 0; i < options.size(); i++) {
    if (redraw || i == selected || i == lastSelected) {
      uint16_t boxColor = (i == selected) ? TFT_GREEN : TFT_BLACK;
      int x = centerTextX(options[i], textSize);
      
      tft.fillRect(x - 4, startY + i * 30 - 2, maxWidth, textSize * 8 + 4, TFT_BLACK);
      
      drawTextWithBox(options[i], x, startY + i * 30, textSize, TFT_WHITE, boxColor);
    }
  }
  
  lastSelected = selected;
}

void drawValues(int values[], int valuesSize, const std::vector<String> options, int selected, int startY, bool redraw) {
  static int lastSelected = -1;
  
  for (int i = 0; i < valuesSize; i++) {
    if (redraw || i == selected || i == lastSelected) {
      uint16_t boxColor = (i == selected) ? TFT_GREEN : TFT_BLACK;
      tft.fillRect(350 - 4, startY + i * 50 - 2, 100, 24, TFT_BLACK);
      drawTextWithBox(String(values[i], 10), 350, startY + i * 50, 2, TFT_WHITE, boxColor);
    }
  }
  
  for (int i = valuesSize; i < options.size() + valuesSize; i++) {
    if (redraw || i == selected || i == lastSelected) {
      uint16_t boxColor = (i == selected) ? TFT_GREEN : TFT_BLACK;
      int x = centerTextX(options[i - valuesSize], 2);
      tft.fillRect(x - 4, startY + i * 50 - 2, options[i - valuesSize].length() * 12 + 8, 24, TFT_BLACK);
      drawTextWithBox(options[i - valuesSize], x, startY + i * 50, 2, TFT_WHITE, boxColor);
    }
  }
  
  lastSelected = selected;
}

void clearTFTArea(int x, int y, int width, int height) {
  tft.fillRect(x, y, width, height, TFT_BLACK);
}

int getDigitWidth(int textSize) {
  return 6 * textSize;
}

int getDigitHeight(int textSize) {
  return 8 * textSize;
}

void displayTFTDigit(char digit, int x, int y, int size, uint16_t color) {
  clearTFTArea(x, y, getDigitWidth(size), getDigitHeight(size));
  
  tft.setTextSize(size);
  tft.setTextColor(color);
  tft.setCursor(x, y);
  tft.print(digit);
}

void displayTFTTimer(const String& newTime, const String& oldTime, int x, int y, int size, uint16_t color) {
  int digitWidth = getDigitWidth(size);
  int colonWidth = digitWidth;
  
  for (int i = 0; i < newTime.length(); i++) {
    if (oldTime.length() != newTime.length() || oldTime[i] != newTime[i]) {
      int digitX = x + (i * digitWidth);
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

void drawMascotChatbox() {
  tft.fillRect(MASCOT_CHATBOX_X, MASCOT_CHATBOX_Y, MASCOT_CHATBOX_W, MASCOT_CHATBOX_H, TFT_BLACK);
  tft.drawRect(MASCOT_CHATBOX_X, MASCOT_CHATBOX_Y, MASCOT_CHATBOX_W, MASCOT_CHATBOX_H, TFT_WHITE);
}

void updateMascotFace(const uint8_t* imageData) {
  // Clear the display area
  tft.fillRect(MASCOT_FACE_X, MASCOT_FACE_Y, MASCOT_FACE_W, MASCOT_FACE_H, TFT_BLACK);

  // Open the RGB565 binary file
  fs::File file = SPIFFS.open("/resized_mascot.raw", "r");
  if (!file) {
    Serial.println("Failed to open resized_mascot.raw");
    return;
  }

  // Verify file size (64 * 68 * 2 = 8704 bytes)
  if (file.size() != MASCOT_FACE_W * MASCOT_FACE_H * 2) {
    Serial.printf("File size %d bytes, expected %d bytes\n", file.size(), MASCOT_FACE_W * MASCOT_FACE_H * 2);
    file.close();
    return;
  }

  // Buffer for one row (64 pixels × 2 bytes = 128 bytes)
  uint16_t rowBuffer[MASCOT_FACE_W];

  // Read and display each row
  for (int y = 0; y < MASCOT_FACE_H; y++) {
    // Read one row (128 bytes)
    if (file.read((uint8_t*)rowBuffer, MASCOT_FACE_W * 2) != MASCOT_FACE_W * 2) {
      Serial.printf("Error reading row %d from file\n", y);
      break;
    }
    // Push the row to the display
    tft.pushImage(MASCOT_FACE_X, MASCOT_FACE_Y + y, MASCOT_FACE_W, 1, rowBuffer);
  }

  file.close();
  Serial.println("Image displayed successfully");
}

void displayMascotText(const String& text, int charIndex, unsigned long& lastCharTime, Audio& audio) {
  
 
    if (charIndex < text.length()) {
        char currentChar = text[charIndex];

        // Build the word
        wordBuffer += currentChar;
        charIndex++;

        // If it's a space or end of word, try printing the whole wordBuffer
        if (currentChar == ' ' || charIndex == text.length()) {
            int wordPixelWidth = wordBuffer.length() * 15;

            // If word won't fit in current line, move to new line
            if (col * 15 + wordPixelWidth > MASCOT_TEXT_MAX_COLS * 15) {
                row++;
                col = 0;
                if (row >= MASCOT_TEXT_MAX_ROWS) return;
            }

            // Draw each character in wordBuffer
            for (int i = 0; i < wordBuffer.length(); ++i) {
                char c = wordBuffer[i];
                tft.setTextColor(TFT_WHITE);
                tft.setTextSize(2);
                tft.setCursor(MASCOT_TEXT_X + col * 15, MASCOT_TEXT_Y + row * 20);
                tft.print(c);

                if (c != ' ') {
                    bool useDoubleTime = (charIndex % 2 == 1);
                    audio.playCharSound(useDoubleTime, 0.4);
                }

                col++;
                if (col >= MASCOT_TEXT_MAX_COLS) {
                    col = 0;
                    row++;
                    if (row >= MASCOT_TEXT_MAX_ROWS) return;
                }
            }

            wordBuffer = "";  // Clear word buffer after printing
        }
    }
}
