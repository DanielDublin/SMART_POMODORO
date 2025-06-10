/*
 * ESP32 POC Project
 * Integrates WiFi, Firebase, OLED/TFT displays, buttons, rotary encoder and NeoPixel LEDs
 */

// Include all component modules
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

void setup() {
  Serial.begin(115200);
  Serial.println("ESP32 POC Starting...");

  // Initialize basic components first
  setupDisplays();  // Initialize displays first
  setupInputs();
  audio.begin();
    
  // Initialize screens after basic components
  clearTFTScreen();
  displayOLEDText("ESP32 POC Ready", 0, OLED_NEW_LINE*5, 1, true);  // Add OLED ready message
  screenManager.init();  // Initialize screens properly
  
  // The rest of setup can continue while WiFi is being configured
  setupNeoPixel();
}

void loadDB() {
    FirebaseStatus firebaseStatus = setupFirebase();
    delay(5000);
    if (firebaseStatus == FIREBASE_STATUS_ERROR) {
      displayTFTText("Firebase setup failed", 10, 10, 2, TFT_RED, true);
      delay(5000);
    }
    else {
      displayTFTText("Data loaded successfully", centerTextX("Data loaded successfully", 2), 200, 2, TFT_GREEN, true);
      delay(500);
    }
}

void setupWifiEsp() {
  // Setup WiFi - this now runs the config portal in the background if needed
  displayTFTText("Connecting to Wifi", centerTextX("Connecting to Wifi", 3), 100, 3, TFT_BLUE, true);
  wifiStatus = setupWiFi2();
  if (wifiStatus == WIFI_CONNECTED) {
    syncTime();
    displayTFTText("Wifi Connected, getting data", centerTextX("Wifi Connected, getting data", 2), 100, 2, TFT_GREEN, true);
    loadDB();
    screenManager.switchScreen(Screens::ONLINE_SESSION_PLANER_SCREEN);
  } else {
    // Connection failed, show error and return to choose mode screen
    displayTFTText("WiFi Connection Failed", centerTextX("WiFi Connection Failed", 2), 100, 2, TFT_RED, true);
    delay(2000);  // Show error message for 2 seconds
    screenManager.switchScreen(Screens::CHOOSE_MODE_SCREEN);
  }
}

void loop() {
  // Handle inputs
  handleButtons();
  int rotaryChange = handleRotaryEncoder();
  bool needsUpdate = false;
  static bool lastWhiteButtonState = false;  // Track last button state
  static Screens::ScreenChoice lastScreen = Screens::CHOOSE_MODE_SCREEN;  // Track the last screen before timer
  
  // Handle blue button for menu navigation
  if (isBlueButtonPressed()) {
    screenManager.updateselectedInputIndex(1);
    needsUpdate = true;
  }
  
  // Handle rotary encoder for value adjustments
  if (rotaryChange != 0) {
    Screens::ScreenChoice currentScreen = screenManager.getCurrentScreen();
    if (currentScreen == Screens::OFFLINE_POMODORO_SETTINGS_SCREEN) {
      screenManager.adjustSelectedValue(rotaryChange);
      needsUpdate = true;
    }
  }
  
  // Handle white button for selection
  bool currentWhiteButton = isWhiteButtonPressed();
  if (currentWhiteButton && !lastWhiteButtonState) {  // Only trigger on button press, not hold
    int choice = screenManager.getChoice();
    if (choice != -1) {
      Screens::ScreenChoice currentScreen = screenManager.getCurrentScreen();
      
      if (currentScreen == Screens::CHOOSE_MODE_SCREEN) {
        if (choice == Screens::ONLINE) {
          if (wifiStatus != WIFI_CONNECTED) {
            screenManager.switchScreen(Screens::QR_SCREEN);
            // screenManager.switchScreen(Screens::WIFI_CONNECTION_SCREEN);
            // setupWifiEsp();
          } else {
            screenManager.switchScreen(Screens::ONLINE_SESSION_PLANER_SCREEN);
          }
        } else if (choice == Screens::OFFLINE) {
          screenManager.switchScreen(Screens::OFFLINE_POMODORO_SETTINGS_SCREEN);
        }
      }
      else if (currentScreen == Screens::OFFLINE_POMODORO_SETTINGS_SCREEN) {
        if (choice == CONFIRM) {
          audio.playConfirmation(0.7);
          lastScreen = currentScreen;  // Remember we came from offline settings
          screenManager.switchScreen(Screens::POMODORO_TIMER_SCREEN);
        } else if (choice == RETURN) {
          screenManager.switchScreen(Screens::CHOOSE_MODE_SCREEN);
        }
      }
      else if (currentScreen == Screens::ONLINE_SESSION_PLANER_SCREEN) {
        if (choice == CONFIRM) {
          audio.playConfirmation(0.7);
          lastScreen = currentScreen;  // Remember we came from online planner
          screenManager.switchScreen(Screens::POMODORO_TIMER_SCREEN);
        } else if (choice == RETURN) {
          screenManager.switchScreen(Screens::CHOOSE_MODE_SCREEN);
        }
      }
      else if (currentScreen == Screens::POMODORO_TIMER_SCREEN) {
        if (choice == FIRST_OPTION) {  // Stop button
          audio.playConfirmation(0.7);
          // Return to the screen we came from
          screenManager.switchScreen(lastScreen);
        }
      }
      needsUpdate = true;
    }
  }
  lastWhiteButtonState = currentWhiteButton;  // Update last button state

  // Only update the screen when needed
  Screens::ScreenChoice currentScreen = screenManager.getCurrentScreen();
  if (currentScreen == Screens::POMODORO_TIMER_SCREEN || needsUpdate) {
    screenManager.displayCurrentScreen(needsUpdate);
  }
  
  // Handle Firebase operations
  firebaseLoop();
  
  // Small delay to prevent watchdog timer issues
  delay(10);
}
