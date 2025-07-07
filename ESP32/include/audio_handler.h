#ifndef AUDIO_H
#define AUDIO_H
#pragma once
#include <FS.h>
#include <SPIFFS.h>
#include "config.h"
#include "driver/i2s.h"

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
    fs::File audioFile;
};

#endif