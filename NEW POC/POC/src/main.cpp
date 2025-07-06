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

static bool lastWhiteButtonState = false;
static Screens::ScreenChoice lastScreen = Screens::CHOOSE_MODE_SCREEN;
bool isPaired = false;

void setup() {
  Serial.begin(115200);
  Serial.println("ESP32 POC Starting...");
  if (!SPIFFS.begin(true)) {
  Serial.println("SPIFFS Mount Failed");
}
  setupDisplays();
  setupInputs();
  audio.begin();
  clearTFTScreen();
  delay(1000);  // Allow displays to initialize
  setupWiFi();

  clearTFTScreen();
  displayOLEDText("ESP32 POC Ready", 0, OLED_NEW_LINE * 5, 1, true);
  setupNeoPixel();
  screenManager.init();
}

void handleBlueButtonNavigation(bool& needsUpdate) {
  if (isBlueButtonPressed()) {
    needsUpdate = screenManager.updateselectedInputIndex(1);
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
      Serial.println(currentScreen);
    switch (currentScreen) {
      case Screens::CHOOSE_MODE_SCREEN:
        if (choice == Screens::ONLINE) {
          screenManager.switchScreen(
            wifiState == WiFiState::CONNECTED ? Screens::QR_SCREEN : Screens::WIFI_CONNECTION_SCREEN
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
          screenManager.switchScreen(Screens::USER_PLANS_SCREEN);
        }
        break;

      case Screens::POMODORO_TIMER_SCREEN:
        if (choice == FIRST_OPTION) {
          audio.playConfirmation(0.7);
          screenManager.switchScreen(lastScreen);
        }
        break;

      case Screens::QR_SCREEN:
        if (choice == FIRST_OPTION) {
          screenManager.switchScreen(Screens::CHOOSE_MODE_SCREEN);
        }
        break;

      case Screens::WIFI_CONNECTION_SCREEN:
        if (choice == FIRST_OPTION) {
          screenManager.switchScreen(Screens::CHOOSE_MODE_SCREEN);
        }
        else if (choice == SECOND_OPTION) {
          if (wifiState == WiFiState::CONNECTED) {
            screenManager.switchScreen(Screens::QR_SCREEN);
          }
          else {
            setupWiFi();
          }
        }
        break;

      case Screens::USER_PLANS_SCREEN:
        if (choice != RETURN) {
          screenManager.switchScreen(Screens::ONLINE_SESSION_PLANER_SCREEN);
        }
        else {
          screenManager.switchScreen(Screens::CHOOSE_MODE_SCREEN);
        }
        break;  
      case Screens::SESSION_SUMMARY_SCREEN:
        if (choice == RETURN) {
          screenManager.switchScreen(Screens::CHOOSE_MODE_SCREEN);
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
    // updateNeoPixelEffects();
    searchForPair(isPaired);
    bool needsUpdate = false;
    int rotaryChange = handleRotaryEncoder();
    if (isPaired && screenManager.getCurrentScreen() == Screens::QR_SCREEN) {
        needsUpdate = true;
        isPaired = false;
        screenManager.switchScreen(Screens::USER_PLANS_SCREEN);
    }
    handleBlueButtonNavigation(needsUpdate);
    handleRotaryAdjustments(rotaryChange, needsUpdate);
    handleWhiteButtonSelection(needsUpdate);
    screenManager.updateMascotDialogueContinuous();
    if (screenManager.getCurrentScreen() == Screens::USER_PLANS_SCREEN) {
        screenManager.displayCurrentScreen(needsUpdate);
    } else {
        updateScreenIfNeeded(needsUpdate);
    }
}
