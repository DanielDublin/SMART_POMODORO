## Smart Pomodoro Project
By Daniel Dublin, Nir Meghbein, Keren Guez 
  
## Details about the project:
The project aims to make the Pomodoro learning technique more tangible and accessible. Instead of relying solely on apps or standard timers, the system will integrate a colored lamp, speaker or buzzer, an optional display screen, and physical buttons to help users monitor and manage their study sessions. The system is designed to support learners in staying focused and consistent as they work toward their exam goals.
 
## Folder description :
* ESP32: source code for the esp side (firmware).
* Documentation: wiring diagram + basic operating instructions
* Unit Tests: tests for individual hardware components
* flutter_app : android app for the pomodor timer
* Parameters: contains description of parameters and settings that can be modified IN YOUR CODE
* Assets: Audio files used in this project, images used in the esp app

## Arduino/ESP32 libraries used in this project:
* adafruit/Adafruit NeoPixel - version 1.10.6
* adafruit/Adafruit GFX Library - version 1.10.13
* adafruit/Adafruit SSD1306 - version 2.5.7
* bodmer/TFT_eSPI - version 2.3.70
* madhephaestus/ESP32Encoder - version 0.11.7 
* tzapu/WiFiManager - version 2.0.17
* mobizt/Firebase Arduino Client Library for ESP8266 and ESP32 - version 4.4.17
* bblanchon/ArduinoJson - version 7.4.1
* itbank2/PNGdec - version 1.1.3

## Hardware list
* ESP32 x 1
* RGB LED x 1
* max98357 audio amplifier x 1
* Push buttons x 2
* 2.42 inch 128x64 OLED screen x 1
* 4" SPI ILI9488 320*480 screen x 1
* Rotary Encoder Sensor x 1

## Connection diagram
:![wiring](https://github.com/user-attachments/assets/b1349508-aed7-4ffc-9473-f00f5b5d0ffe)

# Project Poster:
#[3  Smart Pomodoro for Learning Management IOT.pdf](https://github.com/user-attachments/files/21109559/3.Smart.Pomodoro.for.Learning.Management.IOT.pdf)
 
This project is part of ICST - The Interdisciplinary Center for Smart Technologies, Taub Faculty of Computer Science, Technion
https://icst.cs.technion.ac.il/
