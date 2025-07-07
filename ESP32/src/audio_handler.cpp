#include "audio_handler.h"

Audio::Audio() : isPlaying(false), soundEnabled(true) {}

void Audio::begin() {
    if (!SPIFFS.begin(true)) {
        soundEnabled = false;
        return;
    }
    configureI2S();

    File f = SPIFFS.open("/char.wav", "r");
    if (!f) soundEnabled = false;
    f.close();
}

void Audio::configureI2S() {
    i2s_config_t i2s_config = {
        .mode = (i2s_mode_t)(I2S_MODE_MASTER | I2S_MODE_TX),
        .sample_rate = 16000,
        .bits_per_sample = I2S_BITS_PER_SAMPLE_16BIT,
        .channel_format = I2S_CHANNEL_FMT_RIGHT_LEFT,
        .communication_format = I2S_COMM_FORMAT_STAND_I2S,
        .intr_alloc_flags = ESP_INTR_FLAG_LEVEL1,
        .dma_buf_count = 8,
        .dma_buf_len = 64,
        .use_apll = false,
        .tx_desc_auto_clear = true
    };

    i2s_pin_config_t pin_config = {
        .bck_io_num = I2S_BCLK,
        .ws_io_num = I2S_LRC,
        .data_out_num = I2S_DOUT,
        .data_in_num = I2S_PIN_NO_CHANGE
    };

    i2s_driver_install(I2S_NUM_0, &i2s_config, 0, NULL);
    i2s_set_pin(I2S_NUM_0, &pin_config);
}

void Audio::playWavFile(const char* path, float volume, bool skipHeader, float maxDurationSec) {
    if (!soundEnabled) return;
    if (isPlaying) {
        stop();
    }

    audioFile = SPIFFS.open(path, "r");
    if (!audioFile) {
        Serial.printf("Failed to open file: %s\n", path);
        return;
    }

    WavHeader header;
    if (!skipHeader) {
        if (audioFile.read((uint8_t*)&header, sizeof(WavHeader)) != sizeof(WavHeader) ||
            strncmp(header.riff, "RIFF", 4) || strncmp(header.wave, "WAVE", 4) ||
            strncmp(header.fmt, "fmt ", 4) || strncmp(header.data, "data", 4)) {
            Serial.println("Invalid WAV format");
            audioFile.close();
            return;
        }
        i2s_set_sample_rates(I2S_NUM_0, header.sampleRate);
    } else {
        audioFile.seek(44, SeekSet); // Skip PCM header
    }

    const size_t bufferSize = 512;
    uint8_t buffer[bufferSize];
    int16_t sampleBuffer[bufferSize / 2];

    size_t totalBytesPlayed = 0;
    size_t bytesRead;
    isPlaying = true;

    size_t maxBytes = -1;
    if (!skipHeader && maxDurationSec > 0) {
        maxBytes = header.sampleRate * maxDurationSec * (header.bitsPerSample / 8) * header.numChannels;
        if (maxBytes > header.dataSize) maxBytes = header.dataSize;
    }

    while ((bytesRead = audioFile.read(buffer, bufferSize)) > 0 &&
          (maxDurationSec < 0 || totalBytesPlayed < maxBytes)) {

        memcpy(sampleBuffer, buffer, bytesRead);
        size_t sampleCount = bytesRead / 2;

        for (size_t i = 0; i < sampleCount; ++i) {
            sampleBuffer[i] = (int16_t)(sampleBuffer[i] * volume);
        }

        size_t bytesWritten;
        i2s_write(I2S_NUM_0, sampleBuffer, bytesRead, &bytesWritten, portMAX_DELAY);
        totalBytesPlayed += bytesWritten;
    }

    audioFile.close();
    isPlaying = false;
}

void Audio::playCharSound(bool useDoubleTime, float volume) {
    playWavFile(useDoubleTime ? "/letter2.wav" : "/letter1.wav", volume, false, 0.05f);
}

void Audio::playVibration(float volume) {
    playWavFile("/vibration.wav", volume, true);
}

void Audio::playButton(float volume) {
    playWavFile("/mc_button.wav", volume, true);
}

void Audio::playConfirmation(float volume) {
    playWavFile("/confirm_button.wav", volume, true);
}

void Audio::stop() {
    isPlaying = false;
    if (audioFile) audioFile.close();
    i2s_zero_dma_buffer(I2S_NUM_0);
}
