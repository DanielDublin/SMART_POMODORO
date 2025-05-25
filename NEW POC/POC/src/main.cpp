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

// For Bluetooth audio control
extern bool bluetoothControlMode;

void setup() {
  Serial.begin(115200);
  Serial.println("ESP32 POC Starting...");

  // Initialize basic components
  setupInputs();
  setupDisplays();
  
  // Setup WiFi - this now runs the config portal in the background if needed
  WiFiStatus wifiStatus = setupWiFi();
  
  // The rest of setup can continue while WiFi is being configured
  setupBluetoothAudio();
  setupI2S();
  setupNeoPixel();
  
  // Wait for WiFi connection before setting up Firebase
  if (waitForWiFiConnection(10000)) { // Wait up to 10 seconds
    FirebaseStatus firebaseStatus = setupFirebase();
    delay(5000);
    if (firebaseStatus == FIREBASE_STATUS_ERROR) {
      displayTFTText("Firebase setup failed", 10, 10, 2, TFT_RED, true);
      delay(5000);
    }
    
    // Display WiFi status on TFT
    String networkName = getNetworkName();
    displayTFTText("WiFi Status:", 10, 10, 2, TFT_GREEN, true);
    displayTFTText("Connected to:", 10, 40, 2, TFT_WHITE, false);
    displayTFTText(networkName, 10, 70, 3, TFT_CYAN, false);
  } else {
    // Firebase setup skipped - will try again when WiFi connects
    displayTFTText("Waiting for WiFi", 10, 10, 2, TFT_YELLOW, true);
    displayTFTText("Configure via AP:", 10, 40, 2, TFT_WHITE, false);
    displayTFTText(CONFIG_AP_SSID, 10, 70, 2, TFT_CYAN, false);
  }
  
  // Final ready message
  displayTFTText("ESP32 POC Ready", 10, 100, 2, TFT_GREEN, false);
  displayOLEDText("ESP32 POC Ready", 0, OLED_NEW_LINE*5, 1, false);
  
  Serial.println("Setup complete!");
}

void loop() {
  // Handle inputs
  handleButtons();
  handleRotaryEncoder();
  
  // Handle Firebase operations
  firebaseLoop();
  
  // Switch mode with rotary button
  if (isRotaryButtonPressed()) {
    toggleBluetoothControlMode();
  }
  
  if (isBluetoothControlMode()) {
    handleBluetoothControls();
  } else {
    updateDisplayAnimations();
    updateNeoPixelEffects();
  }
  
  // Small delay to prevent watchdog timer issues
  delay(10);
}
