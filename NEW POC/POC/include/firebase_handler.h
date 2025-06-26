#ifndef FIREBASE_HANDLER_H
#define FIREBASE_HANDLER_H

#include <Firebase_ESP_Client.h>

// Enum for pairing states
enum class PairingState {
    UNPAIRED,
    PENDING,
    PAIRED
};

// Function prototypes
void initFirebase();
void processFirebase();
bool readSessionData(String& data, const String& userId, const String& sessionId);
bool writeSessionLog(const String& userId, const String& logId, FirebaseJson& json);

// Global variables
extern PairingState pairingState;
extern String pairedUid;

#endif