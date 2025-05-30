#include "firebase_handler.h"
#include "config.h"
#include "displays.h"
#include <addons/TokenHelper.h>

// Firebase objects
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

// Firebase state
bool firebaseInitialized = false;
String lastErrorMessage = "";

// Helper function to set error message
void setFirebaseError(const String& error) {
    lastErrorMessage = error;
    displayTFTText("Firebase Error: " + error, 10, 10, 1, TFT_RED, true);
    displayOLEDText("FB Error: " + error, 0, OLED_NEW_LINE*4, 1, true);
}

void printMemoryInfo() {
    Serial.printf("Free Heap: %d bytes\n", ESP.getFreeHeap());
    Serial.printf("Minimum Free Heap: %d bytes\n", ESP.getMinFreeHeap());
    Serial.printf("Maximum Alloc Heap: %d bytes\n", ESP.getMaxAllocHeap());
}

FirebaseStatus setupFirebase() {
    Serial.println("Setting up Firebase...");
    displayOLEDText("Firebase Setup...", 0, OLED_NEW_LINE*0, 1, true);
    
    printMemoryInfo();  // Print initial memory state
    
    // Configure Firebase with minimal memory usage
    config.api_key = FIREBASE_API_KEY;
    config.token_status_callback = tokenStatusCallback;
    config.time_zone = 3;
    
    // Set low memory options
    fbdo.setBSSLBufferSize(4096, 1024);  // Reduce SSL buffer size
    fbdo.setResponseSize(1024);  // Reduce response buffer size
    
    printMemoryInfo();  // Print memory state after config
    
    // Attempt Firebase authentication
    displayOLEDText("Auth...", 0, OLED_NEW_LINE*1, 1, false);
    Serial.println("Attempting Firebase authentication...");
    
    if (Firebase.signUp(&config, &auth, "", "")) {
        Serial.println("Firebase Setup - Auth OK");
        displayOLEDText("Auth: OK", 0, OLED_NEW_LINE*1, 1, false);
        firebaseInitialized = true;
    } else {
        String error = String(config.signer.signupError.message.c_str());
        displayOLEDText("Auth: FAILED", 0, OLED_NEW_LINE*1, 1, false);
        Serial.print("Firebase Setup - Auth FAILED, error: ");
        Serial.println(config.signer.signupError.message.c_str());
        delay(5000);
        setFirebaseError("Auth Failed: " + error);
        return FIREBASE_STATUS_ERROR;
    }

    printMemoryInfo();  // Print memory state after auth
    
    // Initialize Firebase with minimal memory settings
    Firebase.begin(&config, &auth);
    Firebase.reconnectNetwork(true);
    
    // Test connection
    if (!Firebase.ready()) {
        setFirebaseError("Connection Failed");
        Serial.println("Firebase Setup - Connection FAILED");
        displayOLEDText("Connection Failed", 0, OLED_NEW_LINE*1, 1, false);
        delay(5000);
        return FIREBASE_STATUS_ERROR;
    }
    return FIREBASE_STATUS_CONNECTED;
}

FirebaseStatus testFireBase() {
    Serial.println("Testing Firestore...");
    displayOLEDText("Testing Firestore...", 0, OLED_NEW_LINE*2, 1, false);

    // Test write - will create or update
    String testDoc = "test_collection/test_doc";
    FirebaseJson payload;
    payload.set("fields/test_value/stringValue", "Test Data " + String(millis()));

    // Step 1: Check document state
    Serial.println("Checking document state... ");
    displayTFTText("Checking document state...", 10, 100, 1, TFT_CYAN, false);
    if (Firebase.Firestore.getDocument(&fbdo, FIREBASE_PROJECT_ID, "", testDoc.c_str(), "")) {
        String payloadMsg = "Doc exists: " + fbdo.payload();
        Serial.println("Doc exists: " + fbdo.payload());
        displayTFTText(payloadMsg, 10, 130, 1, TFT_CYAN, false);
    } else {
        String errorMsg = "Doc read failed: " + fbdo.errorReason();
        Serial.println("Doc read failed: " + fbdo.errorReason());
        displayTFTText(errorMsg, 10, 130, 1, TFT_RED, false);
    }

    // Step 2: Try patch without mask
    displayTFTText("Patch without mask...", 10, 160, 1, TFT_YELLOW, false);
    if (!Firebase.Firestore.patchDocument(&fbdo, FIREBASE_PROJECT_ID, "", testDoc.c_str(), payload.raw(), "")) {
        String errorMsg = "Patch failed: " + fbdo.errorReason();
        displayTFTText("Payload: " + String(payload.raw()), 10, 190, 1, TFT_RED, false);
        displayTFTText("HTTP Code: " + String(fbdo.httpCode()), 10, 220, 1, TFT_RED, false);
        displayTFTText("Error: " + errorMsg, 10, 250, 1, TFT_RED, false);
        displayOLEDText("Write Test: FAILED", 0, OLED_NEW_LINE*1, 1, false);
        delay(5000);
        return FIREBASE_STATUS_ERROR;
    } else {
        displayTFTText("Patch without mask: OK", 10, 190, 1, TFT_GREEN, false);
    }

    // Step 3: Try patch with mask (optional)
    displayTFTText("Patch with mask...", 10, 220, 1, TFT_YELLOW, false);
    if (!Firebase.Firestore.patchDocument(&fbdo, FIREBASE_PROJECT_ID, "", testDoc.c_str(), payload.raw(), "test_value")) {
        String errorMsg = "Patch with mask failed: " + fbdo.errorReason();
        displayTFTText("Payload: " + String(payload.raw()), 10, 250, 1, TFT_RED, false);
        displayTFTText("HTTP Code: " + String(fbdo.httpCode()), 10, 280, 1, TFT_RED, false);
        displayTFTText("Error: " + errorMsg, 10, 310, 1, TFT_RED, false);
    } else {
        displayTFTText("Patch with mask: OK", 10, 250, 1, TFT_GREEN, false);
    }

    displayOLEDText("Firebase Ready!", 0, OLED_NEW_LINE*2, 1, false);
    displayTFTText("Firebase Ready!", 10, 280, 2, TFT_GREEN, false);
    Serial.println("Firebase initialized");
    return FIREBASE_STATUS_CONNECTED;
}

void firebaseLoop() {
    if (!firebaseInitialized) return;
    
    if (!Firebase.ready()) {
        setFirebaseError("Connection Lost");
    }
}

bool writeToFirestore(const String& path, const String& jsonString) {
    if (!firebaseInitialized || !Firebase.ready()) {
        setFirebaseError("Not Ready");
        delay(3000); // Delay to allow for Firebase processing
        return false;
    }

    displayOLEDText("Writing...", 0, OLED_NEW_LINE*3, 1, false);
    displayTFTText("Writing to: " + path, 10, 10, 1, TFT_YELLOW, true);
    delay(5000); // Delay to allow for Firebase processing
    FirebaseJson content;
    content.setJsonData(jsonString);

    if (Firebase.Firestore.patchDocument(&fbdo, FIREBASE_PROJECT_ID, "", path.c_str(), content.raw(), "")) {
        displayOLEDText("Write OK: " + path, 0, OLED_NEW_LINE*3, 1, false);
        displayTFTText("Write OK: " + path, 10, 40, 1, TFT_GREEN, false);
        delay(10000); // Delay to allow for Firebase processing
        return true;
    } else {
        String errorMsg = fbdo.errorReason();
        setFirebaseError("Write Failed: " + errorMsg);
        displayTFTText("Write Failed: " + errorMsg, 10, 40, 1, TFT_RED, false);
        displayTFTText("HTTP Code: " + String(fbdo.httpCode()), 10, 70, 1, TFT_RED, false);
        delay(10000); // Delay to allow for Firebase processing
        return false;
    }
}

String readFromFirestore(const String& path) {
    if (!firebaseInitialized || !Firebase.ready()) {
        setFirebaseError("Not Ready");
        return "";
    }

    displayOLEDText("Reading...", 0, OLED_NEW_LINE*3, 1, false);
    try{
    if (Firebase.Firestore.getDocument(&fbdo, FIREBASE_PROJECT_ID, "", path.c_str(), "")) {
        displayOLEDText("Read OK: " + path, 0, OLED_NEW_LINE*3, 1, false);
        return fbdo.payload().c_str();
    } else {
        String errorMsg = fbdo.errorReason();
        setFirebaseError("Read Failed: " + errorMsg);
        displayTFTText("Read Failed: " + errorMsg, 10, 40, 1, TFT_RED, false);
        displayTFTText("HTTP Code: " + String(fbdo.httpCode()), 10, 70, 1, TFT_RED, false);
        return "";
    }
} catch(const std::exception& e) {
        Serial.printf("Exception: %s" , e.what());
        return "";
}

}

bool deleteFromFirestore(const String& path) {
    if (!firebaseInitialized || !Firebase.ready()) {
        setFirebaseError("Not Ready");
        return false;
    }

    displayOLEDText("Deleting...", 0, OLED_NEW_LINE*3, 1, false);
    displayTFTText("Deleting: " + path, 10, 10, 1, TFT_YELLOW, true);
    if (Firebase.Firestore.deleteDocument(&fbdo, FIREBASE_PROJECT_ID, "", path.c_str())) {
        displayOLEDText("Delete OK: " + path, 0, OLED_NEW_LINE*3, 1, false);
        displayTFTText("Delete OK: " + path, 10, 40, 1, TFT_GREEN, false);
        return true;
    } else {
        String errorMsg = fbdo.errorReason();
        setFirebaseError("Delete Failed: " + errorMsg);
        displayTFTText("Delete Failed: " + errorMsg, 10, 40, 1, TFT_RED, false);
        displayTFTText("HTTP Code: " + String(fbdo.httpCode()), 10, 70, 1, TFT_RED, false);
        return false;
    }
}

bool isFirebaseReady() {
    return firebaseInitialized && Firebase.ready();
}

String getLastFirebaseError() {
    return lastErrorMessage;
}