#include <Arduino.h>

#include "wifi_manager.h"


// Initialize global variables
WiFiManager wm;
WiFiState wifiState = WiFiState::DISCONNECTED;
TimeSyncState timeSyncState = TimeSyncState::PENDING;
void (*onTimeSyncedCallback)() = nullptr;
unsigned long portalStartTime = 0;
bool portalStartLocked = false;

void setupWiFi() {
    Serial.begin(115200);
    WiFi.mode(WIFI_STA);

    setenv("TZ", "IST-3", 1); // IDT is UTC+3
    tzset(); // Apply TZ settings

    // wm.resetSettings(); // Uncomment for testing

    wm.setConfigPortalBlocking(false);
    wm.setConfigPortalTimeout(300);

    displayOLEDText("WiFi Setup...", 0, OLED_NEW_LINE*0, 1, true);
    displayOLEDText("Connect to:", 0, OLED_NEW_LINE*1, 1, false);
    displayOLEDText(CONFIG_AP_SSID, 0, OLED_NEW_LINE*2, 1, false);

    // Time sync callback
    onTimeSyncedCallback = []() {
        Serial.println("Time synchronized!");
        time_t now = time(nullptr);
        struct tm timeinfo;
        localtime_r(&now, &timeinfo);
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
        displayOLEDText("WiFi Connected!", 0, OLED_NEW_LINE*0, 1, true);
        displayOLEDText("IP: " + WiFi.localIP().toString(), 0, OLED_NEW_LINE*1, 1, false);
      
        Serial.println("NTP sync initiated...");
        wifiState = WiFiState::CONNECTED;
        portalStartLocked = false;
        if (timeSyncState == TimeSyncState::SYNCED) {
            initFirebase();
            timeSyncState = TimeSyncState::READY;
        }
        else {
            Serial.println("time not synced");
        }
    }, ARDUINO_EVENT_WIFI_STA_GOT_IP);

    // WiFi disconnected event
    WiFi.onEvent([](WiFiEvent_t event, WiFiEventInfo_t info) {
        displayOLEDText("WiFi Disconnected", 0, OLED_NEW_LINE*0, 1, true);
        displayOLEDText("Connect to ESP32:", 0, OLED_NEW_LINE*1, 1, false);
        displayOLEDText(CONFIG_AP_SSID, 0, OLED_NEW_LINE*2, 1, false);
        if (wifiState != WiFiState::PENDING_PORTAL && wifiState != WiFiState::CONFIG_PORTAL) {
            wifiState = WiFiState::PENDING_PORTAL;
        }
        timeSyncState = TimeSyncState::PENDING;
    }, ARDUINO_EVENT_WIFI_STA_DISCONNECTED);

    // Config portal started callback
    wm.setAPCallback([](WiFiManager *wifiManager) {
        displayOLEDText("Config Portal started. SSID: ", 0, OLED_NEW_LINE*0, 1, true);
        displayOLEDText(wm.getConfigPortalSSID(), 0, OLED_NEW_LINE*1, 1, false);
        displayOLEDText("AP IP: " + WiFi.softAPIP().toString(), 0, OLED_NEW_LINE*2, 1, false);
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
    static unsigned long lastUpdateTime = millis();
    wm.process();

    if (wifiState == WiFiState::PENDING_PORTAL && !WiFi.isConnected() && 
        !wm.getWebPortalActive() && !portalStartLocked) {
        Serial.println("Starting Config Portal due to disconnection...");
        wm.startConfigPortal("AutoConnectAP");
    }

    if (wifiState == WiFiState::CONFIG_PORTAL && portalStartTime > 0 && 
        millis() - portalStartTime > PORTAL_TIMEOUT && !WiFi.isConnected()) {
        Serial.println("Config portal timed out, restarting...");
        wm.startConfigPortal("AutoConnectAP");
        portalStartTime = millis();
    }

    if (timeSyncState == TimeSyncState::PENDING && WiFi.isConnected()) {
        time_t now = time(nullptr);
        // Check if time is beyond a reasonable threshold (e.g., after 2020)
        if (now > 1577836800) { // 2020-01-01 00:00:00 UTC
            if (onTimeSyncedCallback) onTimeSyncedCallback();
        } else if (millis() - lastUpdateTime >= UPDATE_TIME) {
            // Optionally retry NTP sync
            configTime(3 * 3600, 0, "il.pool.ntp.org", "time.google.com", "pool.ntp.org");
            lastUpdateTime = millis();
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