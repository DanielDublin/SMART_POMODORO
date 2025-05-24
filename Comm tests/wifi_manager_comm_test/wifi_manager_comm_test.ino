#include <WiFiManager.h> // https://github.com/tzapu/WiFiManager

void setup() {
    // Initialize Serial with a delay to ensure stability
    Serial.begin(115200);
    delay(1000); // Wait for Serial to initialize
    Serial.println("ESP32 Booting...");

    // Set WiFi to Station mode
    Serial.println("Setting WiFi to Station mode...");
    WiFi.mode(WIFI_STA);

    // Initialize WiFiManager
    Serial.println("Initializing WiFiManager...");
    WiFiManager wm;
    wm.setDebugOutput(true); // Enable debug output

    // Set timeouts and retries
    wm.setConnectTimeout(10); // 10 seconds per connection attempt
    wm.setConnectRetries(2); // 2 retries (~20 seconds total)
    wm.setConfigPortalTimeout(120); // Portal runs for 120 seconds

    // Optional: Uncomment to clear saved credentials (forces config portal)
    // wm.resetSettings();

    // Try to connect to saved WiFi or start config AP
    Serial.println("Attempting to connect to saved WiFi or start AP...");
    bool res = wm.autoConnect("ESP32_Config", "config123"); // Password-protected AP

    if (!res) {
        Serial.println("Failed to connect - Configuration portal running.");
        Serial.println("Connect to AP: ESP32_Config, Password: config123");
        Serial.println("Open http://192.168.4.1 to configure WiFi");
        // Portal runs for 120 seconds, then resets
    } else {
        Serial.println("Connected successfully :)");
        Serial.print("Network: "); Serial.println(WiFi.SSID());
        Serial.print("IP Address: "); Serial.println(WiFi.localIP());
    }
}

void loop() {
    // Add your main code here
    // Optional: Print WiFi status periodically for debugging
    static unsigned long lastPrint = 0;
    if (millis() - lastPrint >= 5000) { // Print every 5 seconds
        if (WiFi.status() == WL_CONNECTED) {
            Serial.println("WiFi still connected to: " + WiFi.SSID());
        } else {
            Serial.println("WiFi disconnected");
        }
        lastPrint = millis();
    }
}