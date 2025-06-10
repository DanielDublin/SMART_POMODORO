#ifndef WIFI_MANAGER_H
#define WIFI_MANAGER_H

#include <WiFiManager.h>
#include "config.h"
#include "displays.h"


typedef enum WiFiStatus {
  WIFI_CONNECTED,
  WIFI_DISCONNECTED,
  WIFI_CONNECT_FAILED,
  WIFI_CONNECTION_LOST,
  WIFI_NO_SSID_AVAIL,
  WIFI_IDLE_STATUS,
} WiFiStatus;

// Core WiFi setup and status functions
WiFiStatus setupWiFi();
WiFiStatus setupWiFi2();
bool isWiFiConnected();
String getLocalIP();
String getNetworkName();
void syncTime();
// New background monitoring functions
void startWiFiMonitor();
bool waitForWiFiConnection(uint32_t timeout_ms);


#endif 