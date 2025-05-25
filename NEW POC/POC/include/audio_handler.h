#ifndef AUDIO_HANDLER_H
#define AUDIO_HANDLER_H

#include <Arduino.h>
#include <driver/i2s.h>
#include "config.h"

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

void setupI2S();

#endif 