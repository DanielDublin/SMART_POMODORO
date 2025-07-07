#ifndef FIREBASE_HANDLER_H
#define FIREBASE_HANDLER_H

#include <Firebase_ESP_Client.h>
#include <WiFi.h>
#include "wifi_manager.h"
#include <time.h>               // For timestamp formatting
#include <ArduinoJson.h>        // ArduinoJson v7
#include <SPIFFS.h>             // For SPIFFS file storage
#include "png_handler.h"          // For QR code
#include "secrets.h"

// Enum for pairing states
enum class PairingState {
    UNPAIRED,
    PENDING,
    PAIRED
};

// Function prototypes
void initFirebase();
String processFirebase();
void handleInitialPairing();
void searchForPair(bool& paired);
String readUserRank(String& uesrId);
bool readSessionData(String& data, const String& userId, const String& sessionId);
bool writeSessionLog(const String& userId, const String& logId, FirebaseJson& json);

// Global variables
extern PairingState pairingState;
extern String pairedUid;

#endif