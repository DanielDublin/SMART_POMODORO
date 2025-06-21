#ifndef WIFI_MANAGER_H
#define WIFI_MANAGER_H

#include <WiFiManager.h>
#include <WiFi.h>
#include <time.h>

// Enum for WiFi connection states
enum class WiFiState {
    DISCONNECTED,
    CONNECTED,
    CONFIG_PORTAL,
    PENDING_PORTAL
};

// Enum for time synchronization states
enum class TimeSyncState {
    PENDING,
    SYNCED,
    READY // Ready for Firebase initialization
};

// Global variables
extern WiFiManager wm;
extern WiFiState wifiState;
extern TimeSyncState timeSyncState;
extern void (*onTimeSyncedCallback)();
extern unsigned long portalStartTime;
extern const unsigned long portalTimeout;
extern bool portalStartLocked;

// Function prototypes
void setupWiFi();
void processWiFi();

#endif