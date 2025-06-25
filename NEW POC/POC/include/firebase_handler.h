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

// Global variables
extern PairingState pairingState;
extern String pairedUid;

#endif
