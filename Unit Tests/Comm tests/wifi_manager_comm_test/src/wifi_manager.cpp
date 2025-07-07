#include <Arduino.h>

#include "wifi_manager.h"
#include "firebase_handler.h"

// Initialize global variables
WiFiManager wm;
WiFiState wifiState = WiFiState::DISCONNECTED;
TimeSyncState timeSyncState = TimeSyncState::PENDING;
void (*onTimeSyncedCallback)() = nullptr;
unsigned long portalStartTime = 0;
const unsigned long portalTimeout = 300000; // 300 seconds
bool portalStartLocked = false;

void setupWiFi() {
    Serial.begin(115200);
    WiFi.mode(WIFI_STA);

    // wm.resetSettings(); // Uncomment for testing

    wm.setConfigPortalBlocking(false);
    wm.setConfigPortalTimeout(300);

    // Time sync callback
    onTimeSyncedCallback = []() {
        Serial.println("Time synchronized!");
        time_t now = time(nullptr);
        struct tm timeinfo;
        gmtime_r(&now, &timeinfo);
        Serial.print("Current time: ");
        Serial.println(asctime(&timeinfo));
        timeSyncState = TimeSyncState::SYNCED;
        if (wifiState == WiFiState::CONNECTED) {
            initFirebase();
            timeSyncState = TimeSyncState::READY;
        }
    };

    // WiFi connected event
    WiFi.onEvent([](WiFiEvent_t event, WiFiEventInfo_t info) {
        Serial.println("WiFi connected! :)");
        Serial.print("IP: ");
        Serial.println(WiFi.localIP());
        configTime(3 * 3600, 0, "pool.ntp.org", "time.nist.gov"); // IDT (UTC+3)
        Serial.println("NTP sync initiated...");
        wifiState = WiFiState::CONNECTED;
        portalStartLocked = false;
        if (timeSyncState == TimeSyncState::SYNCED) {
            initFirebase();
            timeSyncState = TimeSyncState::READY;
        }
    }, ARDUINO_EVENT_WIFI_STA_GOT_IP);

    // WiFi disconnected event
    WiFi.onEvent([](WiFiEvent_t event, WiFiEventInfo_t info) {
        Serial.println("WiFi disconnected! :(");
        if (wifiState != WiFiState::PENDING_PORTAL && wifiState != WiFiState::CONFIG_PORTAL) {
            wifiState = WiFiState::PENDING_PORTAL;
        }
        timeSyncState = TimeSyncState::PENDING;
    }, ARDUINO_EVENT_WIFI_STA_DISCONNECTED);

    // Config portal started callback
    wm.setAPCallback([](WiFiManager *wifiManager) {
        Serial.print("Config Portal started. SSID: ");
        Serial.println(wm.getConfigPortalSSID());
        Serial.print("AP IP: ");
        Serial.println(WiFi.softAPIP());
        portalStartTime = millis();
        wifiState = WiFiState::CONFIG_PORTAL;
        portalStartLocked = true;
    });

    // Start WiFiManager
    if (wm.autoConnect("AutoConnectAP")) {
        Serial.println("Connecting to saved WiFi...");
    } else {
        Serial.println("Config portal running");
        wifiState = WiFiState::CONFIG_PORTAL;
        portalStartLocked = true;
    }
}

void processWiFi() {
    wm.process();

    if (wifiState == WiFiState::PENDING_PORTAL && !WiFi.isConnected() && 
        !wm.getWebPortalActive() && !portalStartLocked) {
        Serial.println("Starting Config Portal due to disconnection...");
        wm.startConfigPortal("AutoConnectAP");
    }

    if (wifiState == WiFiState::CONFIG_PORTAL && portalStartTime > 0 && 
        millis() - portalStartTime > portalTimeout && !WiFi.isConnected()) {
        Serial.println("Config portal timed out, restarting...");
        wm.startConfigPortal("AutoConnectAP");
        portalStartTime = millis();
    }

    if (timeSyncState == TimeSyncState::PENDING && WiFi.isConnected()) {
        time_t now = time(nullptr);
        if (now > 8 * 3600) {
            if (onTimeSyncedCallback) onTimeSyncedCallback();
        }
    }

    static unsigned long lastTime = 0;
    if (timeSyncState == TimeSyncState::SYNCED && millis() - lastTime > 5000) {
        time_t now = time(nullptr);
        struct tm timeinfo;
        gmtime_r(&now, &timeinfo);
        Serial.print("Current time: ");
        Serial.println(asctime(&timeinfo));
        lastTime = millis();
    }
}