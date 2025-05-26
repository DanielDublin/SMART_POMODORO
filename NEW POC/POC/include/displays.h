#pragma once

#include <Arduino.h>
#include <TFT_eSPI.h>
#include <SPI.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include "config.h"

// Define OLED display dimensions
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
#define TFT_LED 32
#define OLED_NEW_LINE 16
// Define credentials for the ESP32's configuration AP
#define CONFIG_AP_SSID "ESP32_Config" // AP name for configuration portal
#define CONFIG_AP_PASSWORD "config123" // AP password for configuration portal

// Define TFT display dimensions
#define ILI_SCREEN_WIDTH 480
#define ILI_SCREEN_HIEGHT 320

void setupDisplays();
void updateDisplayAnimations();
void displayOLEDText(const String& text, int x, int y, int size = 1, bool clear = true);
void displayTFTText(const String& text, int x, int y, int size = 1, uint16_t color = TFT_WHITE, bool clear = false);
void displayProgressBar(int percentage, bool onOLED = true);
void clearTFTScreen();
void drawTextWithBox(const String& text, int x, int y, int size, uint16_t textColor, uint16_t boxColor);
int centerTextX(const String& text, int textSize);
void drawMenu(const String options[], int numOfOptions, int selected, int startY,  bool redraw);
void drawValues(int values[], int valuesSize, const String options[], int optionsSize, int selected, int startY,  bool redraw);
// Animation functions
void showOLEDAnimation(int animationId);
void showTFTAnimation(int animationId);

// External declarations for SPI instance
extern SPIClass *vspi;
extern Adafruit_SSD1306 oled;
extern TFT_eSPI tft; 