#include "bluetooth_audio.h"
#include "displays.h"
#include "inputs.h"

#define I2S_DOUT 13
#define I2S_BCLK 25
#define I2S_LRC 12
#define MAX_VOLUME 127
#define METADATA_DELAY 500

// Global instance
BluetoothAudio btAudio;
bool bluetoothControlMode = false;

// Static callback helpers
void BluetoothAudio::avrc_metadata_callback_static(uint8_t id, const uint8_t *text) {
    btAudio.avrc_metadata_callback(id, text);
}
void BluetoothAudio::connection_state_changed_static(esp_a2d_connection_state_t state, void *ptr) {
    btAudio.connection_state_changed(state, ptr);
}

BluetoothAudio::BluetoothAudio() : lastMetadataTime(0), currentTitle(""), currentArtist("") {
    // Constructor initializes members
}

void BluetoothAudio::begin(const char* btDeviceName) {
    Serial.begin(115200);
    Serial.println("Initializing Bluetooth...");

    // Initialize Bluetooth Serial
    SerialBT.begin(btDeviceName);
    Serial.println("Bluetooth Serial started. Pair with device: " + String(btDeviceName));

    // Configure I2S for MAX98357A
    i2s_config_t i2s_config = {
        .mode = (i2s_mode_t)(I2S_MODE_MASTER | I2S_MODE_TX),
        .sample_rate = I2S_SAMPLE_RATE,
        .bits_per_sample = I2S_BITS_PER_SAMPLE,
        .channel_format = I2S_CHANNEL_FMT_RIGHT_LEFT,
        .communication_format = I2S_COMM_FORMAT_STAND_I2S,
        .intr_alloc_flags = ESP_INTR_FLAG_LEVEL1,
        .dma_buf_count = 8,
        .dma_buf_len = 64,
        .use_apll = false,
        .tx_desc_auto_clear = true,
        .fixed_mclk = 0
    };

    i2s_pin_config_t pin_config = {
        .bck_io_num = I2S_BCLK,
        .ws_io_num = I2S_LRC,
        .data_out_num = I2S_DOUT,
        .data_in_num = I2S_PIN_NO_CHANGE
    };

    // Initialize A2DP Sink
    a2dp_sink.set_i2s_config(i2s_config);
    a2dp_sink.set_pin_config(pin_config);
    a2dp_sink.set_avrc_metadata_callback(&BluetoothAudio::avrc_metadata_callback_static);
    a2dp_sink.set_on_connection_state_changed(&BluetoothAudio::connection_state_changed_static, nullptr);
    a2dp_sink.set_auto_reconnect(true);
    a2dp_sink.start(btDeviceName);

    Serial.println("Bluetooth A2DP Sink started.");
}

bool BluetoothAudio::isConnected() {
    return SerialBT.hasClient() || a2dp_sink.is_connected();
}

void BluetoothAudio::handleData() {
    // Handle incoming Bluetooth Serial data
    if (SerialBT.available()) {
        receivedData = SerialBT.readStringUntil('\n');
        receivedData.trim();

        if (receivedData.length() > 0) {
            Serial.println("Received: " + receivedData);

            // Parse JSON if the data is in JSON format
            JsonDocument doc;
            DeserializationError error = deserializeJson(doc, receivedData);
            if (!error) {
                Serial.println("Parsed JSON:");
                serializeJsonPretty(doc, Serial);
                Serial.println();

                // Example: Extract specific fields
                if (doc["command"].is<const char*>()) {
                    String command = doc["command"].as<String>();
                    Serial.println("Command: " + command);
                }
            } else {
                Serial.println("Non-JSON data received: " + receivedData);
            }
        }
    }

    // Print song metadata if available
    if (millis() - lastMetadataTime > METADATA_DELAY && (currentTitle != "" || currentArtist != "")) {
        String info = getCurrentSongInfo();
        if (info != "") {
            Serial.println("Now playing: " + info);
        }
    }
}

void BluetoothAudio::setVolume(uint8_t volume) {
    if (volume > MAX_VOLUME) volume = MAX_VOLUME;
    a2dp_sink.set_volume(volume);
    Serial.println("Volume set to: " + String(volume));
}

String BluetoothAudio::getCurrentSongInfo() {
    String info = "";
    if (currentTitle != "") {
        info += "\"" + currentTitle + "\"";
        if (currentArtist != "") info += " by ";
    }
    if (currentArtist != "") info += currentArtist;
    return info;
}

void BluetoothAudio::avrc_metadata_callback(uint8_t id, const uint8_t *text) {
    String textStr = String((char*)text);
    if (textStr.length() > 0) {
        switch (id) {
            case ESP_AVRC_MD_ATTR_TITLE:
                currentTitle = textStr;
                break;
            case ESP_AVRC_MD_ATTR_ARTIST:
                currentArtist = textStr;
                break;
        }
        lastMetadataTime = millis();
    }
}

void BluetoothAudio::connection_state_changed(esp_a2d_connection_state_t state, void *ptr) {
    if (state == ESP_A2D_CONNECTION_STATE_CONNECTED) {
        Serial.println("A2DP Device connected");
        a2dp_sink.set_volume(MAX_VOLUME);
    } else if (state == ESP_A2D_CONNECTION_STATE_DISCONNECTED) {
        Serial.println("A2DP Device disconnected");
        currentTitle = "";
        currentArtist = "";
    }
}

// Global function implementations
void setupBluetoothAudio() {
    btAudio.begin("ESP32_Audio");
}

void processBluetoothData() {
    btAudio.handleData();
}

String getLastReceivedMessage() {
    return btAudio.getCurrentSongInfo();
}

void sendBluetoothCommand(char command) {
    // Implement based on your needs
    switch(command) {
        case 'p': // play/pause
            // Add implementation
            break;
        case 'n': // next
            // Add implementation
            break;
        case '+': // volume up
            // Add implementation
            break;
        case '-': // volume down
            // Add implementation
            break;
    }
}

void handleBluetoothControls() {
    if (bluetoothControlMode) {
        processBluetoothData();
        
        String lastMsg = getLastReceivedMessage();
        if (lastMsg.length() > 0) {
            displayOLEDText("BT Message:", 0, 0);
            displayOLEDText(lastMsg, 0, 12);
        }
        
        if (isWhiteButtonPressed()) {
            sendBluetoothCommand('p');
            displayOLEDText("Sent: Play/Pause", 0, 30);
            delay(200);
        }
        
        if (isBlueButtonPressed()) {
            sendBluetoothCommand('n');
            displayOLEDText("Sent: Next Track", 0, 40);
            delay(200);
        }
        
        static int lastRotaryValue = 0;
        int currentRotaryValue = getRotaryValue();
        
        if (currentRotaryValue > lastRotaryValue) {
            sendBluetoothCommand('+');
            displayOLEDText("Sent: Volume Up", 0, 50);
            lastRotaryValue = currentRotaryValue;
        } else if (currentRotaryValue < lastRotaryValue) {
            sendBluetoothCommand('-');
            displayOLEDText("Sent: Volume Down", 0, 50);
            lastRotaryValue = currentRotaryValue;
        }
    }
}

void toggleBluetoothControlMode() {
    bluetoothControlMode = !bluetoothControlMode;
    if (bluetoothControlMode) {
        displayTFTText("Bluetooth Control Mode", 10, 40, 2, TFT_YELLOW, true);
        displayOLEDText("Bluetooth Control", 0, 0, 1, true);
        displayOLEDText("Use app on phone", 0, 16, 1, false);
        displayOLEDText("White: Play/Pause", 0, 32, 1, false);
        displayOLEDText("Blue: Next Track", 0, 48, 1, false);
    } else {
        displayTFTText("Default Mode", 10, 40, 2, TFT_CYAN, true);
        displayOLEDText("Default Mode", 0, 0, 1, true);
    }
}

bool isBluetoothControlMode() {
    return bluetoothControlMode;
}