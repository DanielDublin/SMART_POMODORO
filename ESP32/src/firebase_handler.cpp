#include <Arduino.h>
#include "firebase_handler.h"
#include <addons/TokenHelper.h> // For token callback


// OLED display configuration
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
#define OLED_RESET -1
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

// Firebase objects
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

// Device ID (MAC address)
String deviceId;

// Paired user UID and user_id
String pairedUid = "";
String pairedUserId = "";

// Pairing state
PairingState pairingState = PairingState::UNPAIRED;

// Polling interval (milliseconds)
unsigned long lastPollTime = 0;

void initFirebase() {
    Serial.printf("init FireBase\n");
    if (timeSyncState != TimeSyncState::SYNCED || wifiState != WiFiState::CONNECTED) {
        Serial.println("Cannot init Firebase: WiFi or time not ready");
        return;
    }

    if (pairingState != PairingState::UNPAIRED) {
        Serial.println("Firebase already initialized or pairing in progress");
        return;
    }

    deviceId = WiFi.macAddress();
    deviceId.replace(":", "-");
    Serial.print("Device ID: ");
    Serial.println(deviceId);

    Serial.println("Configuring Firebase...");
    config.api_key = FIREBASE_API_KEY;
    auth.user.email = FIREBASE_USER_EMAIL;
    auth.user.password = FIREBASE_USER_PASSWORD;
    config.token_status_callback = tokenStatusCallback;
    config.timeout.serverResponse = 10000;
    config.timeout.wifiReconnect = 10000;

    fbdo.setBSSLBufferSize(4096, 1024);
    fbdo.setResponseSize(2048);
    Firebase.reconnectNetwork(true);

    displayOLEDText("Starting Firebase.begin...", 0, OLED_NEW_LINE*0, 1, true);

    int retries = 3;
    while (retries-- > 0 && !Firebase.ready()) {
        Firebase.begin(&config, &auth);
        if (Firebase.ready()) {
            displayOLEDText("Firebase.begin completed", 0, OLED_NEW_LINE*1, 1, false);
            displayOLEDText("User sign-in successful", 0, OLED_NEW_LINE*2, 1, false);
            break;
        }
        Serial.println("Firebase.begin failed, retrying...");
        Serial.print("Error: ");
        Serial.println(fbdo.errorReason());
        delay(2000);
    }

    if (!Firebase.ready()) {
        displayOLEDText("Firebase.begin failed after retries", 0, OLED_NEW_LINE*3, 1, false);
        return;
    }
}

void handleInitialPairing() {
    displayOLEDText("Creating pairing request...", 0, OLED_NEW_LINE*0, 1, true);
    Serial.println("Creating pairing request...");
    FirebaseJson json;

    time_t now = time(nullptr);
    char timestamp[30];
    strftime(timestamp, sizeof(timestamp), "%Y-%m-%dT%H:%M:%SZ", gmtime(&now));
    if (strlen(timestamp) == 0) {
        Serial.println("Warning: Timestamp generation failed, using fallback");
        strcpy(timestamp, "2025-06-22T00:00:00Z"); // Fallback timestamp
    }

    json.set("fields/status/stringValue", "pending");
    json.set("fields/deviceId/stringValue", deviceId);
    json.set("fields/createdAt/timestampValue", String(timestamp));

    String path = "pairing_requests/" + deviceId;
    if (Firebase.Firestore.createDocument(&fbdo, FIREBASE_PROJECT_ID, "", path.c_str(), json.raw())) {
        Serial.println("Pairing request created in Firestore");
        pairingState = PairingState::PENDING;
        lastPollTime = millis();
    } else {
        Serial.print("Failed to create pairing request: ");
        Serial.println(fbdo.errorReason());
    }
}

void handlePairedUserId(String userId) {
    // Save user_id to SPIFFS
    File file = SPIFFS.open("/paired_user_id.txt", FILE_WRITE);
    if (!file) {
        Serial.println("Failed to open file for writing");
        return;
    }
    if (file.print(userId)) {
        Serial.println("user_id saved to SPIFFS");
    } else {
        Serial.println("Failed to write user_id to SPIFFS");
    }
    file.close();

    // Display user_id on OLED
    displayOLEDText("User sign-in successful", 0, OLED_NEW_LINE*0, 1, true);
    displayOLEDText("Paired User ID:", 0, OLED_NEW_LINE*1, 1, false);
    displayOLEDText(userId, 0, OLED_NEW_LINE*2, 1, false);
}

void searchForPair(bool& paired) {
    if (timeSyncState != TimeSyncState::READY || wifiState != WiFiState::CONNECTED) {
        return;
    }

    if (!Firebase.ready()) {
        Serial.println("Firebase not ready, reconnecting...");
        Firebase.begin(&config, &auth);
        return;
    }

    if (pairingState != PairingState::PENDING) {
        return;
    }

    if (millis() - lastPollTime >= POLLING_INTERVAL) {
        String path = "pairing_requests/" + deviceId;
        Serial.println("Polling pairing request...");
        Serial.print("Firestore path: ");
        Serial.println(path);

        if (Firebase.Firestore.getDocument(&fbdo, FIREBASE_PROJECT_ID, "", path.c_str(), "")) {
            DynamicJsonDocument doc(2048);
            DeserializationError error = deserializeJson(doc, fbdo.payload());

            if (error) {
                Serial.print("JSON deserialization failed: ");
                Serial.println(error.c_str());
                return;
            }

            // Access the simplified fields
            String status = doc["fields"]["status"]["stringValue"].as<String>();
            String uid = doc["fields"]["uid"]["stringValue"].as<String>();
            String userId = doc["fields"]["user_id"]["stringValue"].as<String>();

            Serial.print("Parsed status: ");
            Serial.println(status);

            if (status == "approved" && !uid.isEmpty() && !userId.isEmpty()) {
                pairingState = PairingState::PAIRED;
                paired = true;
                pairedUid = uid;
                pairedUserId = userId;
                // Handle user_id (save to SPIFFS and display)
                handlePairedUserId(pairedUserId);

                // Delete the pairing request
                if (Firebase.Firestore.deleteDocument(&fbdo, FIREBASE_PROJECT_ID, "", path.c_str())) {
                    Serial.println("Pairing request deleted from Firestore");
                } else {
                    Serial.print("Failed to delete pairing request: ");
                    Serial.println(fbdo.errorReason());
                }
            } else if (status == "rejected") {
                Serial.println("Pairing rejected");
                pairingState = PairingState::UNPAIRED;
            }
            else {
                Serial.println("Status not approved or rejected, continuing to poll...");
            }
        }
        else {
            Serial.print("Failed to get document: ");
            Serial.println(fbdo.errorReason());
        }
        lastPollTime = millis();
    }
}

String processFirebase() {
    if (timeSyncState != TimeSyncState::READY || wifiState != WiFiState::CONNECTED) {
        return "";
    }

    if (!Firebase.ready()) {
        Serial.println("Firebase not ready, reconnecting...");
        Firebase.begin(&config, &auth);
        return "";
    }

    if (pairingState != PairingState::PAIRED) {
        return "";
    }
    String sessionPath = "users/" + pairedUid + "/sessions";
    Serial.print("Fetching session from: ");
    Serial.println(sessionPath);
    if (Firebase.Firestore.getDocument(&fbdo, FIREBASE_PROJECT_ID, "", sessionPath.c_str(), "")) {
        // Serial.print("Session payload: ");
        // Serial.println(fbdo.payload());
        return fbdo.payload();
    } else {
        Serial.print("Failed to fetch session: ");
        Serial.println(fbdo.errorReason());
        return fbdo.errorReason();
    }
}

String readUserRank(String& userId) {
    if (!Firebase.ready() || wifiState != WiFiState::CONNECTED || timeSyncState != TimeSyncState::READY) {
        Serial.println("Cannot read session: Firebase or WiFi not ready");
        return "";
    }
    String path = "users/" + userId;  
    if (Firebase.Firestore.getDocument(&fbdo, FIREBASE_PROJECT_ID, "", path.c_str(), "")) {
        FirebaseJson json;
        json.setJsonData(fbdo.payload());
        FirebaseJsonData rank;
        json.get(rank, "fields/rank/stringValue");
        return rank.stringValue;
    } else {
        Serial.print("Failed to read session: ");
        Serial.println(fbdo.errorReason());
        return "";
    } 
}

bool readSessionData(String& data, const String& userId, const String& sessionId) {
    if (!Firebase.ready() || wifiState != WiFiState::CONNECTED || timeSyncState != TimeSyncState::READY) {
        Serial.println("Cannot read session: Firebase or WiFi not ready");
        return false;
    }

    String path = "users/" + userId + "/sessions/" + sessionId;
    Serial.print("Reading session from: ");
    Serial.println(path);

    if (Firebase.Firestore.getDocument(&fbdo, FIREBASE_PROJECT_ID, "", path.c_str(), "")) {
        data = fbdo.payload();
        // Serial.print("Session data retrieved: ");
        // Serial.println(data);
        return true;
    } else {
        Serial.print("Failed to read session: ");
        Serial.println(fbdo.errorReason());
        return false;
    }
}

bool writeSessionLog(const String& userId, const String& logId, FirebaseJson& json) {
    if (!Firebase.ready() || wifiState != WiFiState::CONNECTED || timeSyncState != TimeSyncState::READY) {
        Serial.println("Cannot write session log: Firebase or WiFi not ready");
        return false;
    }

    String path = "users/" + userId + "/session_logs/";
    Serial.print("Writing session log to: ");
    Serial.println(path);

    if (Firebase.Firestore.createDocument(&fbdo, FIREBASE_PROJECT_ID, "", path.c_str(), json.raw())) {
        Serial.println("Session log written to Firestore");
        return true;
    } else {
        Serial.print("Failed to write session log: ");
        Serial.println(fbdo.errorReason());
        return false;
    }
}

