#ifndef AUDIO_H
#define AUDIO_H
#pragma once
#include <FS.h>
#include <SPIFFS.h>
#include "driver/i2s.h"

// I2S configuration
#define I2S_NUM              I2S_NUM_0
#define I2S_SAMPLE_RATE      44100
#define I2S_BITS_PER_SAMPLE  I2S_BITS_PER_SAMPLE_16BIT
#define I2S_BCLK             25  // Bit clock pin
#define I2S_LRC              12  // Left/right clock pin
#define I2S_DOUT             13  // Data out pin

// I2S communication format
#define I2S_COMM_FORMAT      I2S_COMM_FORMAT_STAND_I2S

// DMA buffer configuration
#define I2S_DMA_BUF_COUNT    4
#define I2S_DMA_BUF_LEN      1024


struct WavHeader {
    char riff[4];
    uint32_t chunkSize;
    char wave[4];
    char fmt[4];
    uint32_t subchunk1Size;
    uint16_t audioFormat;
    uint16_t numChannels;
    uint32_t sampleRate;
    uint32_t byteRate;
    uint16_t blockAlign;
    uint16_t bitsPerSample;
    char data[4];
    uint32_t dataSize;
};

class Audio {
public:
    Audio();
    void begin();
    void playCharSound(bool useDoubleTime, float volume);
    void playVibration(float volume);
    void playButton(float volume);
    void playConfirmation(float volume);
    void stop();

private:
    void configureI2S();
    void playWavFile(const char* path, float volume, bool skipHeader = false, float maxDurationSec = -1);

    bool isPlaying;
    bool soundEnabled;
    File audioFile;
};

#endif