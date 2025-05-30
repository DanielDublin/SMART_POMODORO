#include <WiFi.h>
#include <WiFiManager.h>
#include "wifi_manager.h"
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>
#include <freertos/event_groups.h>
#include <time.h>

// Event group for WiFi events
static EventGroupHandle_t wifiEventGroup;
#define WIFI_CONNECTED_BIT BIT0
#define WIFI_FAIL_BIT      BIT1

// Task handle for WiFi monitoring
TaskHandle_t wifiMonitorTaskHandle = NULL;

// WiFi event handler
void WiFiEvent(WiFiEvent_t event) {
    switch(event) {
        case SYSTEM_EVENT_STA_GOT_IP:
            xEventGroupSetBits(wifiEventGroup, WIFI_CONNECTED_BIT);
            displayOLEDText("WiFi Connected!", 0, OLED_NEW_LINE*0, 1, true);
            displayOLEDText("IP: " + WiFi.localIP().toString(), 0, OLED_NEW_LINE*1, 1, false);
            break;
        case SYSTEM_EVENT_STA_DISCONNECTED:
            xEventGroupSetBits(wifiEventGroup, WIFI_FAIL_BIT);
            displayOLEDText("WiFi Disconnected", 0, OLED_NEW_LINE*0, 1, true);
            displayOLEDText("Connect to ESP32:", 0, OLED_NEW_LINE*1, 1, false);
            displayOLEDText(CONFIG_AP_SSID, 0, OLED_NEW_LINE*2, 1, false);
            break;
        default:
            break;
    }
}

// WiFi monitoring task
void wifiMonitorTask(void * parameter) {
    for(;;) {
        if(WiFi.status() == WL_CONNECTED) {
            xEventGroupSetBits(wifiEventGroup, WIFI_CONNECTED_BIT);
        } else {
            xEventGroupSetBits(wifiEventGroup, WIFI_FAIL_BIT);
        }
        vTaskDelay(pdMS_TO_TICKS(5000)); // Check every 5 seconds
    }
}

void startWiFiMonitor() {
    // Create event group if it doesn't exist
    if (!wifiEventGroup) {
        wifiEventGroup = xEventGroupCreate();
    }
    
    // Start WiFi monitoring task if not already running
    if (!wifiMonitorTaskHandle) {
        xTaskCreate(
            wifiMonitorTask,
            "WiFiMonitor",
            2048,
            NULL,
            1,
            &wifiMonitorTaskHandle
        );
    }
}

String getNetworkName() {
  return WiFi.SSID();
}

WiFiStatus setupWiFi() {
  Serial.begin(115200);
  Serial.println("Setting up WiFi...");

  // Create event group
  wifiEventGroup = xEventGroupCreate();
  
  // Register event handler
  WiFi.onEvent(WiFiEvent);

  // Explicitly set WiFi mode to Station (client) mode
  WiFi.mode(WIFI_STA);

  // Initialize WiFiManager
  WiFiManager wm;
  wm.setDebugOutput(true);
  wm.setConfigPortalTimeout(0); // Run portal indefinitely until connection successful

  // Display initial setup info
  displayOLEDText("WiFi Setup...", 0, OLED_NEW_LINE*0, 1, true);
  displayOLEDText("Connect to:", 0, OLED_NEW_LINE*1, 1, false);
  displayOLEDText(CONFIG_AP_SSID, 0, OLED_NEW_LINE*2, 1, false);
  displayOLEDText("Pass: " + String(CONFIG_AP_PASSWORD), 0, OLED_NEW_LINE*3, 1, false);

  // Start the monitoring task
  startWiFiMonitor();

  // Try to connect or start config portal
  bool res = wm.autoConnect(CONFIG_AP_SSID, CONFIG_AP_PASSWORD);

  if (!res) {
    return WIFI_CONNECT_FAILED;
  }
  //syncTime();
  return WIFI_CONNECTED;
}

bool waitForWiFiConnection(uint32_t timeout_ms) {
    EventBits_t bits = xEventGroupWaitBits(
        wifiEventGroup,
        WIFI_CONNECTED_BIT | WIFI_FAIL_BIT,
        pdFALSE,
        pdFALSE,
        pdMS_TO_TICKS(timeout_ms)
    );
    return (bits & WIFI_CONNECTED_BIT) != 0;
}

bool isWiFiConnected() {
  return WiFi.status() == WL_CONNECTED;
}

String getLocalIP() {
  return WiFi.localIP().toString();
}

void syncTime() {
  configTime(0, 0, "ntp.technion.ac.il", "pool.ntp.gov");

  Serial.print("Syncing time");
  time_t now = time(nullptr);
  while (now < 100000) {
    delay(500);
    Serial.print(".");
    now = time(nullptr);
  }
  Serial.println("\nTime synced: " + String(ctime(&now)));

  IPAddress ip;
if (WiFi.hostByName("google.com", ip)) {
} else {
  Serial.println("DNS FAILED for google.com");
}

}


#define WIFI_SSID "phone"
#define WIFI_PASSWORD "abc12345"

WiFiStatus setupWiFi2() {
    Serial.println("Setting up WiFi...");
    
    // Set WiFi to low power mode to save memory
    WiFi.setSleep(true);
    // Disable power saving features that consume memory
    esp_wifi_set_ps(WIFI_PS_NONE);
    
    // Set lower TX power to save memory
    esp_wifi_set_max_tx_power(8);
    
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    unsigned long startAttemptTime = millis();
    const unsigned long WIFI_TIMEOUT_MS = 15000;

    while (WiFi.status() != WL_CONNECTED && millis() - startAttemptTime < WIFI_TIMEOUT_MS) {
        Serial.print(".");
        delay(500);
    }
    if (WiFi.status() != WL_CONNECTED) {
        Serial.println("\nWiFi Connection Failed! Check SSID/Password or signal strength.");
        return WIFI_CONNECT_FAILED;
    }

    Serial.println("\nWiFi Connected");
    Serial.print("IP Address: ");
    Serial.println(WiFi.localIP());
    
    // Print memory info after connection
    Serial.printf("Free Heap after WiFi: %d bytes\n", ESP.getFreeHeap());
    
    return WIFI_CONNECTED;
}
