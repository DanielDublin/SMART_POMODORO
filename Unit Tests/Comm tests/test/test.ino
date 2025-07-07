// Include the PNG decoder library
#include <PNGdec.h>
#include "images.h" // Image is stored here in an 8-bit array

PNG png; // PNG decoder instance

#define MAX_IMAGE_WIDTH 480 // Adjust for your images
#define BUTTON_PIN 14 // Pushbutton connected to GPIO 14

int16_t xpos = 0;
int16_t ypos = 0;

// Include the TFT library
#include "SPI.h"
#include <TFT_eSPI.h>              // Hardware-specific library
TFT_eSPI tft = TFT_eSPI();         // Invoke custom library

// Button state variables
bool lastButtonState = HIGH; // Last state of the button (pull-up)
unsigned long lastDebounceTime = 0; // Last time the button was toggled
const unsigned long debounceDelay = 50; // Debounce delay in ms

//====================================================================================
//                                    Setup
//====================================================================================
void setup()
{
  Serial.begin(115200);
  delay(1000); // Give Serial time to connect
  Serial.println("\n\n Using the PNGdec library");

  // Initialize the button pin
  pinMode(BUTTON_PIN, INPUT_PULLUP); // Button with internal pull-up resistor

  // Initialise the TFT
  pinMode(32, OUTPUT);
  digitalWrite(32, HIGH);
  tft.setRotation(1);
  tft.begin();
  tft.fillScreen(TFT_RED); // Test TFT with red screen
  delay(1000);
  tft.fillScreen(TFT_BLACK);

  Serial.println("\r\nInitialisation done.");

  // Display the initial image
  displayImage();
}

//====================================================================================
//                                    Loop
//====================================================================================
void loop()
{
  // Read the button state
  bool reading = digitalRead(BUTTON_PIN);
  Serial.print("Button state: "); // Debug raw state
  Serial.println(reading ? "HIGH" : "LOW");



 
    if (reading == LOW && lastButtonState == HIGH) { // Button pressed (LOW due to pull-up)
      Serial.println("Button Pressed! Triggering screen update");
      tft.fillScreen(random(0x10000)); // Random color fill
      displayImage(); // Redisplay the image
    
  }

  lastButtonState = reading;
  delay(100); // Slow down loop for readable Serial output
}

//====================================================================================
//                                  displayImage
//====================================================================================
void displayImage()
{
  int16_t rc = png.openFLASH((uint8_t *)images, sizeof(images), pngDraw);
  if (rc == PNG_SUCCESS) {
    Serial.println("Successfully opened png file");
    Serial.printf("image specs: (%d x %d), %d bpp, pixel type: %d\n", png.getWidth(), png.getHeight(), png.getBpp(), png.getPixelType());
    tft.startWrite();
    uint32_t dt = millis();
    rc = png.decode(NULL, 0);
    Serial.print(millis() - dt); Serial.println("ms");
    tft.endWrite();
  } else {
    Serial.println("Failed to open PNG file");
  }
}

//====================================================================================
//                                      pngDraw
//====================================================================================
void pngDraw(PNGDRAW *pDraw) {
  uint16_t lineBuffer[MAX_IMAGE_WIDTH];
  png.getLineAsRGB565(pDraw, lineBuffer, PNG_RGB565_BIG_ENDIAN, 0xffffffff);
  tft.pushImage(xpos, ypos + pDraw->y, pDraw->iWidth, 1, lineBuffer);
}