#include <Arduino.h>
#include <WiFi.h>
#include <Firebase_ESP_Client.h>

#define WIFI_SSID "MonsterPhone"
#define WIFI_PASSWORD "ggbo4285"
#define FIREBASE_API_KEY "AIzaSyDeoMrCH0XKwA8cZ1g1KvUplpajqgxneds"

FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

void setup() {
    Serial.begin(115200);
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    while (WiFi.status() != WL_CONNECTED) {
        delay(500);
        Serial.print(".");
    }
    Serial.println("WiFi connected");

    config.api_key = FIREBASE_API_KEY;
    config.signer.anonymous = true;
    Firebase.reconnectNetwork(true);
    Firebase.begin(&config, &auth);

    if (Firebase.ready()) {
        Serial.println("Firebase initialized");
    } else {
        Serial.print("Failed: ");
        Serial.println(fbdo.errorReason());
    }
}

void loop() {}