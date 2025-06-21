#include <Arduino.h>
#include "wifi_manager.h"
#include "firebase_handler.h"

void setup() {
    setupWiFi();
}

void loop() {
    processWiFi();
    processFirebase();
}