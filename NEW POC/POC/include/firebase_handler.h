#ifndef FIREBASE_HANDLER_H
#define FIREBASE_HANDLER_H

#include <Firebase_ESP_Client.h>

typedef enum FirebaseStatus {
    FIREBASE_STATUS_INITIALIZED,
    FIREBASE_STATUS_CONNECTED,
    FIREBASE_STATUS_DISCONNECTED,
    FIREBASE_STATUS_ERROR
} FirebaseStatus;

// Core functions
FirebaseStatus setupFirebase();
void firebaseLoop();

// Basic Firestore operations
bool writeToFirestore(const String& path, const String& jsonString);
String readFromFirestore(const String& path);
bool deleteFromFirestore(const String& path);

// Status checks
bool isFirebaseReady();
String getLastFirebaseError();

#endif 