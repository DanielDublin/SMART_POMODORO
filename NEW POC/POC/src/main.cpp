/*
 * ESP32 POC Project
 * Integrates WiFi, Firebase, OLED/TFT displays, buttons, rotary encoder and NeoPixel LEDs
 */

#include <Arduino.h>
#include "config.h"
#include "displays.h"
#include "wifi_manager.h"
#include "firebase_handler.h"
#include "inputs.h"
#include "neopixel_control.h"
#include "audio_handler.h"
#include "screens.h"

Audio audio;
Screens screenManager(audio);
WiFiStatus wifiStatus = WIFI_DISCONNECTED;

static bool lastWhiteButtonState = false;
static Screens::ScreenChoice lastScreen = Screens::CHOOSE_MODE_SCREEN;

void setup() {
  Serial.begin(115200);
  Serial.println("ESP32 POC Starting...");

  setupDisplays();
  setupInputs();
  audio.begin();
  setupWiFi();

  clearTFTScreen();
  displayOLEDText("ESP32 POC Ready", 0, OLED_NEW_LINE * 5, 1, true);
  screenManager.init();
  setupNeoPixel();
}

void handleBlueButtonNavigation(bool& needsUpdate) {
  if (isBlueButtonPressed()) {
    screenManager.updateselectedInputIndex(1);
    needsUpdate = true;
  }
}

void handleRotaryAdjustments(int rotaryChange, bool& needsUpdate) {
  if (rotaryChange != 0 &&
      screenManager.getCurrentScreen() == Screens::OFFLINE_POMODORO_SETTINGS_SCREEN) {
    screenManager.adjustSelectedValue(rotaryChange);
    needsUpdate = true;
  }
}

void handleWhiteButtonSelection(bool& needsUpdate) {
  bool currentWhiteButton = isWhiteButtonPressed();

  if (currentWhiteButton && !lastWhiteButtonState) {
    int choice = screenManager.getChoice();
    if (choice == -1) return;

    Screens::ScreenChoice currentScreen = screenManager.getCurrentScreen();

    switch (currentScreen) {
      case Screens::CHOOSE_MODE_SCREEN:
        if (choice == Screens::ONLINE) {
          screenManager.switchScreen(
            wifiStatus != WIFI_CONNECTED ? Screens::QR_SCREEN : Screens::ONLINE_SESSION_PLANER_SCREEN
          );
        } else if (choice == Screens::OFFLINE) {
          screenManager.switchScreen(Screens::OFFLINE_POMODORO_SETTINGS_SCREEN);
        }
        break;

      case Screens::OFFLINE_POMODORO_SETTINGS_SCREEN:
        if (choice == CONFIRM) {
          audio.playConfirmation(0.7);
          lastScreen = currentScreen;
          screenManager.switchScreen(Screens::POMODORO_TIMER_SCREEN);
        } else if (choice == RETURN) {
          screenManager.switchScreen(Screens::CHOOSE_MODE_SCREEN);
        }
        break;

      case Screens::ONLINE_SESSION_PLANER_SCREEN:
        if (choice == CONFIRM) {
          audio.playConfirmation(0.7);
          lastScreen = currentScreen;
          screenManager.switchScreen(Screens::POMODORO_TIMER_SCREEN);
        } else if (choice == RETURN) {
          screenManager.switchScreen(Screens::CHOOSE_MODE_SCREEN);
        }
        break;

      case Screens::POMODORO_TIMER_SCREEN:
        if (choice == FIRST_OPTION) {
          audio.playConfirmation(0.7);
          screenManager.switchScreen(lastScreen);
        }
        break;

      default:
        break;
    }

    needsUpdate = true;
  }

  lastWhiteButtonState = currentWhiteButton;
}

void updateScreenIfNeeded(bool needsUpdate) {
  Screens::ScreenChoice currentScreen = screenManager.getCurrentScreen();
  if (currentScreen == Screens::POMODORO_TIMER_SCREEN || needsUpdate) {
    screenManager.displayCurrentScreen(needsUpdate);
  }
}

void loop() {
  handleButtons();
  processWiFi();
  processFirebase();

  bool needsUpdate = false;
  int rotaryChange = handleRotaryEncoder();

  handleBlueButtonNavigation(needsUpdate);
  handleRotaryAdjustments(rotaryChange, needsUpdate);
  handleWhiteButtonSelection(needsUpdate);
  updateScreenIfNeeded(needsUpdate);

  delay(10);  // Prevent watchdog timeout
}
