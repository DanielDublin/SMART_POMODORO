// #pragma once

// #include <Arduino.h>
// #include <BluetoothSerial.h>
// #include <ArduinoJson.h>
// #include "BluetoothA2DPSink.h"
// #include <esp_a2dp_api.h>
// #include <esp_avrc_api.h>
// #include <esp_bt_main.h>
// #include <esp_bt_device.h>
// #include <esp_gap_bt_api.h>
// #include <driver/i2s.h>
// #include "audio_handler.h"

// // AVRC metadata attributes
// #ifndef ESP_AVRC_MD_ATTR_TITLE
// #define ESP_AVRC_MD_ATTR_TITLE                   0x01
// #define ESP_AVRC_MD_ATTR_ARTIST                  0x02
// #define ESP_AVRC_MD_ATTR_ALBUM                   0x03
// #define ESP_AVRC_MD_ATTR_TRACK_NUM              0x04
// #define ESP_AVRC_MD_ATTR_NUM_TRACKS             0x05
// #define ESP_AVRC_MD_ATTR_GENRE                  0x06
// #define ESP_AVRC_MD_ATTR_PLAYING_TIME           0x07
// #endif

// class BluetoothAudio {
// private:
//     BluetoothSerial SerialBT;
//     BluetoothA2DPSink a2dp_sink;
//     String receivedData;
//     unsigned long lastMetadataTime;
//     String currentTitle;
//     String currentArtist;
//     bool connected;

//     static void avrc_metadata_callback_static(uint8_t id, const uint8_t *text);
//     static void connection_state_changed_static(esp_a2d_connection_state_t state, void *ptr);
//     void avrc_metadata_callback(uint8_t id, const uint8_t *text);
//     void connection_state_changed(esp_a2d_connection_state_t state, void *ptr);
//     void handle_metadata(uint8_t id, const uint8_t* data);

// public:
//     BluetoothAudio();
//     void begin(const char* device_name);
//     void handleData();
//     void stop();
//     bool isConnected();
//     void setVolume(uint8_t volume);
//     String getCurrentSongInfo();
//     String getLastReceivedData() const { return receivedData; }
// };

// // Global control functions
// void setupBluetoothAudio();
// void processBluetoothData();
// String getLastReceivedMessage();
// void sendBluetoothCommand(char command);

// // Control mode functions
// void handleBluetoothControls();
// void toggleBluetoothControlMode();
// bool isBluetoothControlMode(); 