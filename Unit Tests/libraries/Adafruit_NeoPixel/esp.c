// Implements the RMT peripheral on Espressif SoCs
// Copyright (c) 2020 Lucian Copeland for Adafruit Industries

/* Uses code from Espressif RGB LED Strip demo and drivers
 * Copyright 2015-2020 Espressif Systems (Shanghai) PTE LTD
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#if defined(ESP32)

#include <Arduino.h>

#if defined(ESP_IDF_VERSION)
#if ESP_IDF_VERSION >= ESP_IDF_VERSION_VAL(4, 0, 0)
#define HAS_ESP_IDF_4
#endif
#if ESP_IDF_VERSION >= ESP_IDF_VERSION_VAL(5, 0, 0)
#define HAS_ESP_IDF_5
#endif
#endif


#ifdef HAS_ESP_IDF_5

static SemaphoreHandle_t show_mutex = NULL;

void espShow(uint8_t pin, uint8_t *pixels, uint32_t numBytes, boolean is800KHz) {
  // Note: Because rmtPin is shared between all instances, we will
  //  end up releasing/initializing the RMT channels each time we
  //  invoke on different pins. This is probably ok, just not
  //  efficient. led_data is shared between all instances but will
  //  be allocated with enough space for the largest instance; data
  //  is not used beyond the mutex lock so this should be fine.

#define SEMAPHORE_TIMEOUT_MS 50

  static rmt_data_t *led_data = NULL;
  static uint32_t led_data_size = 0;
  static int rmtPin = -1;

  if (show_mutex && xSemaphoreTake(show_mutex, SEMAPHORE_TIMEOUT_MS / portTICK_PERIOD_MS) == pdTRUE) {
    uint32_t requiredSize = numBytes * 8;
    if (requiredSize > led_data_size) {
      free(led_data);
      if (led_data = (rmt_data_t *)malloc(requiredSize * sizeof(rmt_data_t))) {
        led_data_size = requiredSize;
      } else {
        led_data_size = 0;
      }
    } else if (requiredSize == 0) {
      // To release RMT resources (RMT channels and led_data), call
      //  .updateLength(0) to set number of pixels/bytes to zero,
      //  then call .show() to invoke this code and free resources.
      free(led_data);
      led_data = NULL;
      if (rmtPin >= 0) {
        rmtDeinit(rmtPin);
        rmtPin = -1;
      }
      led_data_size = 0;
    }

    if (led_data_size > 0 && requiredSize <= led_data_size) {
      if (pin != rmtPin) {
        if (rmtPin >= 0) {
          rmtDeinit(rmtPin);
          rmtPin = -1;
        }
        if (!rmtInit(pin, RMT_TX_MODE, RMT_MEM_NUM_BLOCKS_1, 10000000)) {
          log_e("Failed to init RMT TX mode on pin %d", pin);
          return;
        }
        rmtPin = pin;
      }

      if (rmtPin >= 0) {
        int i=0;
        for (int b=0; b < numBytes; b++) {
          for (int bit=0; bit<8; bit++){
            if ( pixels[b] & (1<<(7-bit)) ) {
              led_data[i].level0 = 1;
              led_data[i].duration0 = 8;
              led_data[i].level1 = 0;
              led_data[i].duration1 = 4;
            } else {
              led_data[i].level0 = 1;
              led_data[i].duration0 = 4;
              led_data[i].level1 = 0;
              led_data[i].duration1 = 8;
            }
            i++;
          }
        }

        rmtWrite(pin, led_data, numBytes * 8, RMT_WAIT_FOR_EVER);
      }
    }

    xSemaphoreGive(show_mutex);
  }
}

// To avoid race condition initializing the mutex, all instances of
//  Adafruit_NeoPixel must be constructed before launching and child threads
void espInit() {
  if (!show_mutex) {
    show_mutex = xSemaphoreCreateMutex();
  }
}

#else

#include "driver/rmt.h"


// This code is adapted from the ESP-IDF v3.4 RMT "led_strip" example, altered
// to work with the Arduino version of the ESP-IDF (3.2)

#define WS2812_T0H_NS (400)
#define WS2812_T0L_NS (850)
#define WS2812_T1H_NS (800)
#define WS2812_T1L_NS (450)

#define WS2811_T0H_NS (500)
#define WS2811_T0L_NS (2000)
#define WS2811_T1H_NS (1200)
#define WS2811_T1L_NS (1300)

static uint32_t t0h_ticks = 0;
static uint32_t t1h_ticks = 0;
static uint32_t t0l_ticks = 0;
static uint32_t t1l_ticks = 0;

// Limit the number of RMT channels available for the Neopixels. Defaults to all
// channels (8 on ESP32, 4 on ESP32-S2 and S3). Redefining this value will free
// any channels with a higher number for other uses, such as IR send-and-recieve
// libraries. Redefine as 1 to restrict Neopixels to only a single channel.
#define ADAFRUIT_RMT_CHANNEL_MAX RMT_CHANNEL_MAX

#define RMT_LL_HW_BASE  (&RMT)

bool rmt_reserved_channels[ADAFRUIT_RMT_CHANNEL_MAX];

static void IRAM_ATTR ws2812_rmt_adapter(const void *src, rmt_item32_t *dest, size_t src_size,
        size_t wanted_num, size_t *translated_size, size_t *item_num)
{
    if (src == NULL || dest == NULL) {
        *translated_size = 0;
        *item_num = 0;
        return;
    }
    const rmt_item32_t bit0 = {{{ t0h_ticks, 1, t0l_ticks, 0 }}}; //Logical 0
    const rmt_item32_t bit1 = {{{ t1h_ticks, 1, t1l_ticks, 0 }}}; //Logical 1
    size_t size = 0;
    size_t num = 0;
    uint8_t *psrc = (uint8_t *)src;
    rmt_item32_t *pdest = dest;
    while (size < src_size && num < wanted_num) {
        for (int i = 0; i < 8; i++) {
            // MSB first
            if (*psrc & (1 << (7 - i))) {
                pdest->val =  bit1.val;
            } else {
                pdest->val =  bit0.val;
            }
            num++;
            pdest++;
        }
        size++;
        psrc++;
    }
    *translated_size = size;
    *item_num = num;
}

void espShow(uint8_t pin, uint8_t *pixels, uint32_t numBytes, boolean is800KHz) {
    // Reserve channel
    rmt_channel_t channel = ADAFRUIT_RMT_CHANNEL_MAX;
    for (size_t i = 0; i < ADAFRUIT_RMT_CHANNEL_MAX; i++) {
        if (!rmt_reserved_channels[i]) {
            rmt_reserved_channels[i] = true;
            channel = i;
            break;
        }
    }
    if (channel == ADAFRUIT_RMT_CHANNEL_MAX) {
        // Ran out of channels!
        return;
    }

#if defined(HAS_ESP_IDF_4)
    rmt_config_t config = RMT_DEFAULT_CONFIG_TX(pin, channel);
    config.clk_div = 2;
#else
    // Match default TX config from ESP-IDF version 3.4
    rmt_config_t config = {
        .rmt_mode = RMT_MODE_TX,
        .channel = channel,
        .gpio_num = pin,
        .clk_div = 2,
        .mem_block_num = 1,
        .tx_config = {
            .carrier_freq_hz = 38000,
            .carrier_level = RMT_CARRIER_LEVEL_HIGH,
            .idle_level = RMT_IDLE_LEVEL_LOW,
            .carrier_duty_percent = 33,
            .carrier_en = false,
            .loop_en = false,
            .idle_output_en = true,
        }
    };
#endif
    rmt_config(&config);
    rmt_driver_install(config.channel, 0, 0);

    // Convert NS timings to ticks
    uint32_t counter_clk_hz = 0;

#if defined(HAS_ESP_IDF_4)
    rmt_get_counter_clock(channel, &counter_clk_hz);
#else
    // this emulates the rmt_get_counter_clock() function from ESP-IDF 3.4
    if (RMT_LL_HW_BASE->conf_ch[config.channel].conf1.ref_always_on == RMT_BASECLK_REF) {
        uint32_t div_cnt = RMT_LL_HW_BASE->conf_ch[config.channel].conf0.div_cnt;
        uint32_t div = div_cnt == 0 ? 256 : div_cnt;
        counter_clk_hz = REF_CLK_FREQ / (div);
    } else {
        uint32_t div_cnt = RMT_LL_HW_BASE->conf_ch[config.channel].conf0.div_cnt;
        uint32_t div = div_cnt == 0 ? 256 : div_cnt;
        counter_clk_hz = APB_CLK_FREQ / (div);
    }
#endif

    // NS to tick converter
    float ratio = (float)counter_clk_hz / 1e9;

    if (is800KHz) {
        t0h_ticks = (uint32_t)(ratio * WS2812_T0H_NS);
        t0l_ticks = (uint32_t)(ratio * WS2812_T0L_NS);
        t1h_ticks = (uint32_t)(ratio * WS2812_T1H_NS);
        t1l_ticks = (uint32_t)(ratio * WS2812_T1L_NS);
    } else {
        t0h_ticks = (uint32_t)(ratio * WS2811_T0H_NS);
        t0l_ticks = (uint32_t)(ratio * WS2811_T0L_NS);
        t1h_ticks = (uint32_t)(ratio * WS2811_T1H_NS);
        t1l_ticks = (uint32_t)(ratio * WS2811_T1L_NS);
    }

    // Initialize automatic timing translator
    rmt_translator_init(config.channel, ws2812_rmt_adapter);

    // Write and wait to finish
    rmt_write_sample(config.channel, pixels, (size_t)numBytes, true);
    rmt_wait_tx_done(config.channel, pdMS_TO_TICKS(100));

    // Free channel again
    rmt_driver_uninstall(config.channel);
    rmt_reserved_channels[channel] = false;

    gpio_set_direction(pin, GPIO_MODE_OUTPUT);
}

#endif // ifndef IDF5


#endif // ifdef(ESP32)
