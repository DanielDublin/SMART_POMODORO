#pragma once

#include <Arduino.h>
#include <TFT_eSPI.h>
#include <SPI.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <vector>
#include "config.h"
#include "Faces.h"  // Keep for OLED faces
#include "audio_handler.h" 

// LVGL is not used in this version, but can be added later if needed

// Face types for OLED
typedef enum {
    FACE_FOCUSED,  // Use anime_face_girl_1 for focus time
    FACE_TIRED,    // Use anime_face_girl_2 for tired/break time
    NUM_FACES
} FaceType;

void setupDisplays();
void updateDisplayAnimations();
void displayOLEDText(const String& text, int x, int y, int size = 1, bool clear = true);
void displayTFTText(const String& text, int x, int y, int size = 1, uint16_t color = TFT_WHITE, bool clear = false);
void displayProgressBar(int percentage, bool onOLED = true);
void clearTFTScreen();
void drawTextWithBox(const String& text, int x, int y, int size, uint16_t textColor, uint16_t boxColor);
int centerTextX(const String& text, int textSize);
void drawMenu(const std::vector<String> options, int selected, int startY, bool redraw);
void drawValues(int values[], int valuesSize, const std::vector<String> options, int selected, int startY, bool redraw);
void showOLEDAnimation(int animationId);
void showTFTAnimation(int animationId);
void clearTFTArea(int x, int y, int width, int height);
void displayTFTDigit(char digit, int x, int y, int size, uint16_t color);
void displayTFTTimer(const String& newTime, const String& oldTime, int x, int y, int size, uint16_t color);
int getDigitWidth(int textSize);
int getDigitHeight(int textSize);
void clearOLEDScreen();
void displayOLEDFace(FaceType face);
void displayOLEDLogo();

// New functions for mascot dialogue
void drawMascotChatbox();
void updateMascotFace(const uint8_t* imageData);
void displayMascotText(const String& text, int index, unsigned long& lastCharTime, Audio& audio);
void resetMascotTextPosition();

extern SPIClass *vspi;
extern Adafruit_SSD1306 oled;
extern TFT_eSPI tft;

extern int col;
extern int row;
extern String wordBuffer;
