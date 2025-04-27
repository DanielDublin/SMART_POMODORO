#include <SPI.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

// Define the SPI pins based on the wiring
#define OLED_MOSI   22  // D1 pin on OLED (MOSI)
#define OLED_CLK    23  // D0 pin on OLED (SCK)
#define OLED_DC     19  // DC pin on OLED
#define OLED_CS     18  // CS pin on OLED
#define OLED_RESET  21  // RES pin on OLED

// Create an SSD1306 display object
Adafruit_SSD1306 display(128, 64, OLED_MOSI, OLED_CLK, OLED_DC, OLED_RESET, OLED_CS);

void setup() {
  // Initialize serial communication for debugging
  Serial.begin(115200);

  // Initialize the OLED display
  if (!display.begin(SSD1306_SWITCHCAPVCC)) {
    Serial.println("SSD1306 allocation failed");
    while (1); // Halt if display initialization fails
  }

  // Clear the display buffer
  display.clearDisplay();

  // Set text size and color
  display.setTextSize(2);      // Text size 2
  display.setTextColor(WHITE); // White text
  display.setCursor(0, 0);     // Start at top-left corner

  // Display a test message
  display.println("Hello, World!");
  display.display(); // Update the display with the buffer content
}

void loop() {
  // Nothing to do here for this test
}