#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include <addons/TokenHelper.h>
#include <addons/RTDBHelper.h>

// Replace with your WiFi credentials
#define WIFI_SSID "X"
#define WIFI_PASSWORD "X"

// Replace with your Firebase credentials
#define FIREBASE_API_KEY "X"
#define FIREBASE_DATABASE_URL "https://X-default-rtdb.firebaseio.com/"
#define FIREBASE_PROJECT_ID "X"

using FirebaseValueCallback = std::function<void(const String&)>;
using FirebaseErrorCallback = std::function<void(const String&)>;

// Firebase objects
FirebaseData fbdo;
FirebaseData streamData;  // Separate object for stream
FirebaseAuth auth;
FirebaseConfig config;

typedef enum FirebaseStatus {
  FIREBASE_STATUS_INITIALIZED,
  FIREBASE_STATUS_CONNECTED,
  FIREBASE_STATUS_DISCONNECTED,
  FIREBASE_STATUS_ERROR
} FirebaseStatus;

// Firebase connection status
bool firebaseInitialized = false;

// Test path
const char* TEST_PATH = "/test/data";

const char* FIRESTORE_COLLECTION = "test_collection";
const char* FIRESTORE_DOCUMENT = "test_doc";

FirebaseStatus setupFirebase() {
  Serial.println("Firebase Setup...");

  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting to WiFi: ");
  unsigned long startAttemptTime = millis();
  const unsigned long WIFI_TIMEOUT_MS = 15000;

  while (WiFi.status() != WL_CONNECTED && millis() - startAttemptTime < WIFI_TIMEOUT_MS) {
    Serial.print(".");
    delay(500);
  }

  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("\nWiFi Connection Failed! Check SSID/Password or signal strength.");
    return FIREBASE_STATUS_ERROR;
  }
  Serial.println("\nWiFi Connected");
  Serial.print("IP Address: ");
  Serial.println(WiFi.localIP());

  Serial.println("Configuring Firebase...");
  config.api_key = FIREBASE_API_KEY;
  config.token_status_callback = tokenStatusCallback;

  Serial.println("Attempting Firebase authentication...");
  if (Firebase.signUp(&config, &auth, "", "")) {
    Serial.println("Auth: OK");
    firebaseInitialized = true;
  } else {
    Serial.printf("Auth Failed: %s\n", config.signer.signupError.message.c_str());
    return FIREBASE_STATUS_ERROR;
  }

  Firebase.begin(&config, &auth);
  Firebase.reconnectNetwork(true);
  Serial.println("Firebase initialized");

  String documentPath = String(FIRESTORE_COLLECTION) + "/" + String(FIRESTORE_DOCUMENT);
  FirebaseJson content;
  content.set("fields/testValue/stringValue", "Test Data " + String(millis()));
  if (Firebase.Firestore.createDocument(&fbdo, FIREBASE_PROJECT_ID, "", documentPath.c_str(), content.raw())) {
    Serial.println("Write to Firestore successful");
  } else {
    Serial.printf("Write to Firestore failed: %s\n", fbdo.errorReason().c_str());
    return FIREBASE_STATUS_ERROR;
  }
  return FIREBASE_STATUS_CONNECTED;
}

void firebaseLoop() {
  if (!firebaseInitialized) {
    Serial.print(".");
    return;
  }
  if (!Firebase.ready()) {
    Serial.println("Firebase not ready");
  }
}

String readFromFirestore(const String& collection, const String& document) {
  if (!firebaseInitialized) {
    Serial.println("Firebase not initialized");
    return "";
  }

  String documentPath = collection + "/" + document;
  if (Firebase.Firestore.getDocument(&fbdo, FIREBASE_PROJECT_ID, "", documentPath.c_str(), "")) {
    String value = fbdo.payload();
    Serial.printf("Read from Firestore: %s\n", value.c_str());
    return value;
  } else {
    Serial.printf("Read from Firestore failed: %s\n", fbdo.errorReason().c_str());
    return "";
  }
}

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("Starting ESP32 Firestore Test...");
  setupFirebase();
}

void loop() {
  firebaseLoop();

  static unsigned long lastRead = 0;
  if (millis() - lastRead > 5000) {
    String value = readFromFirestore(FIRESTORE_COLLECTION, FIRESTORE_DOCUMENT);
    lastRead = millis();
  }
}
