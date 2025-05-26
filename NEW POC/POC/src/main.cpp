/*
 * ESP32 POC Project
 * Integrates WiFi, Bluetooth, Firebase, OLED/TFT displays, buttons, rotary encoder and NeoPixel LEDs
 */

// Include all component modules
#include <Arduino.h>
#include "config.h"
#include "wifi_manager.h"
#include "firebase_handler.h"
#include "displays.h"
#include "inputs.h"
#include "neopixel_control.h"
#include "bluetooth_audio.h"
#include "audio_handler.h"
#include "screens.h"

// For Bluetooth audio control
extern bool bluetoothControlMode;
Screens screenManager;
WiFiStatus wifiStatus = WIFI_DISCONNECTED;
void setup() {
  Serial.begin(115200);
  Serial.println("ESP32 POC Starting...");
  screenManager.init();
  // Initialize basic components
  setupInputs();
  setupDisplays();
  
  // Setup WiFi - this now runs the config portal in the background if needed
  // WiFiStatus wifiStatus = setupWiFi2();
  
  // The rest of setup can continue while WiFi is being configured
  setupBluetoothAudio();
  setupI2S();
  setupNeoPixel();
  
  // // Wait for WiFi connection before setting up Firebase
  // // if (waitForWiFiConnection(10000)) { // Wait up to 10 seconds
  // if (wifiStatus == WIFI_CONNECTED){
  //   syncTime();
  //   FirebaseStatus firebaseStatus = setupFirebase();
  //   delay(5000);
  //   if (firebaseStatus == FIREBASE_STATUS_ERROR) {
  //     displayTFTText("Firebase setup failed", 10, 10, 2, TFT_RED, true);
  //     delay(5000);
  //   }
  //   // Display WiFi status on TFT
  //   String networkName = getNetworkName();
  //   displayTFTText("WiFi Status:", 10, 10, 2, TFT_GREEN, true);
  //   displayTFTText("Connected to:", 10, 40, 2, TFT_WHITE, false);
  //   displayTFTText(networkName, 10, 70, 3, TFT_CYAN, false);
  // } else {
  //   // Firebase setup skipped - will try again when WiFi connects
  //   displayTFTText("Waiting for WiFi", 10, 10, 2, TFT_YELLOW, true);
  //   displayTFTText("Configure via AP:", 10, 40, 2, TFT_WHITE, false);
  //   displayTFTText(CONFIG_AP_SSID, 10, 70, 2, TFT_CYAN, false);
  // }
  
  // // Final ready message
  // displayTFTText("ESP32 POC Ready", 10, 100, 2, TFT_GREEN, false);
  // displayOLEDText("ESP32 POC Ready", 0, OLED_NEW_LINE*5, 1, false);
  
  // Serial.println("Setup complete!");
  // delay(1000);
  // clearTFTScreen();
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

void setupWifi() {
  // Setup WiFi - this now runs the config portal in the background if needed
  displayTFTText("Connecting to Wifi", centerTextX("Connecting to Wifi", 3), 100, 3, TFT_BLUE, true);
  WiFiStatus wifiStatus = setupWiFi2();
  if (wifiStatus == WIFI_CONNECTED) {
    syncTime();
    displayTFTText("Wifi Connected, getting data", centerTextX("Wifi Connected, getting data", 2), 100, 2, TFT_GREEN, true);
    loadDB();
    screenManager.switchScreen(Screens::ONLINE_SESSION_PLANER_SCREEN);
  }
}

void loop() {
  // Handle inputs
  screenManager.displayCurrentScreen(false);
  handleButtons();
  // int rotaryValue = handleRotaryEncoder();
  // if (rotaryValue != 0) {
  //   Serial.printf("value: %d\n", rotaryValue);
  //   screenManager.updateselectedInputIndex(rotaryValue);
  //   screenManager.displayCurrentScreen(true);
  // }
  // else {
  //   screenManager.displayCurrentScreen(false);
  // }
  // Handle Firebase operations
  if(isBlueButtonPressed()) {
    screenManager.updateselectedInputIndex(1);
    screenManager.displayCurrentScreen(true);
  }
  else{
    screenManager.displayCurrentScreen(false);
  }

  if(isWhiteButtonPressed()) {  //maybe rotery button
    int choice = screenManager.getChoice();
    Screens::Screen currentScreen = screenManager.getCurrentScreen();
    if (currentScreen == Screens::CHOOSE_MODE_SCREEN && choice == Screens::ONLINE) {
      if (wifiStatus != WIFI_CONNECTED) {
        screenManager.switchScreen(Screens::WIFI_CONNECTION_SCREEN);
        setupWifi();
      }
    }
    else if (currentScreen == Screens::CHOOSE_MODE_SCREEN && choice == Screens::OFFLINE) {
      screenManager.switchScreen(Screens::OFFLINE_POMODORO_SETTINGS_SCREEN);
        //TODO offline option
    }
    else if (currentScreen == Screens::ONLINE_SESSION_PLANER_SCREEN && choice == FIRST_OPTION) {
      clearTFTScreen();
      screenManager.switchScreen(Screens::CLOCK_SCREEN);
      displayTFTText("THIS IS A CLOCK", centerTextX("THIS IS A CLOCK", 3), 100, 3, TFT_BLUE, false);
        //TODO CLOCK
    }
    else if (currentScreen == Screens::ONLINE_SESSION_PLANER_SCREEN && choice == SECOND_OPTION) {
      screenManager.switchScreen(Screens::CHOOSE_MODE_SCREEN);
    }
  }

  firebaseLoop();
  
  // Switch mode with rotary button
  if (isRotaryButtonPressed()) {
    // toggleBluetoothControlMode();
  }
  
  if (isBluetoothControlMode()) {
    handleBluetoothControls();
  } else {
    // updateDisplayAnimations();
    // updateNeoPixelEffects();
  }
  
  // Small delay to prevent watchdog timer issues
  delay(10);
}
