#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <TFT_eSPI.h> // Includes SPI.h internally
#include <PNGdec.h>
#include <ESP32Encoder.h>
#include "images.h"
#include <esp_task_wdt.h>
#include <driver/i2s.h>  // For MAX98357A I2S amplifier support
#include <Adafruit_NeoPixel.h>  // For NeoPixel LED strip

// Memory monitoring
#include <esp_system.h>

// Optional fallback beeper for testing
#define BEEPER_PIN   22   // For direct tone generation

// Pin Definitions
// TFT Display pins need to match User_Setup.h for TFT_eSPI
#define TFT_CS   15  // Must match TFT_eSPI configuration 
#define TFT_LED  32

// OLED Display 
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
#define OLED_SCLK   18  // Shared with TFT
#define OLED_MOSI   23  // Shared with TFT
#define OLED_CS     5
#define OLED_RES    16
#define OLED_DC     17

// Rotary Encoder pins
#define ROT_CLK  26  
#define ROT_DT   27
#define ROT_SW   4   // Adding button pin if needed

// MAX98357A I2S Amplifier
#define I2S_DOUT     13  // DIN of the MAX98357A (connected to GPIO13)
#define I2S_BCLK     25  // Bit Clock (connected to pin 25)
#define I2S_LRC      12  // Left/Right Clock (connected to pin 12)

// NeoPixel LED Strip
#define LED_PIN      33  // Data pin for NeoPixel (connected to GPIO33)
#define LED_COUNT    2   // Number of LEDs in the strip
#define LED_BRIGHTNESS 150 // Increased brightness from 50 to 150 (0-255)

// Push Buttons
#define BUTTON_BLUE  36  // Blue button for audio playback
#define BUTTON_WHITE 39  // White button for LED color change
#define BUTTON_ACTIVE LOW  // Define active state (when button is pressed)

// Configuration
#define MAX_IMAGE_WIDTH 480
#define ANIMATION_RATE 25        // OLED Animation refresh rate (ms)
#define LCD_ANIMATION_RATE 100   // LCD Animation refresh rate (ms)
#define ENCODER_CHECK_RATE 20    // Encoder check interval (ms)
#define BUTTON_CHECK_RATE 50     // Button check interval (ms)

// I2S configuration
#define SAMPLE_RATE     44100    // Audio sample rate in Hz
#define I2S_PORT        I2S_NUM_0

// Global objects
Adafruit_SSD1306 oled(SCREEN_WIDTH, SCREEN_HEIGHT, OLED_MOSI, OLED_SCLK, OLED_DC, OLED_RES, OLED_CS);
TFT_eSPI tft = TFT_eSPI();
PNG png;
ESP32Encoder encoder;
Adafruit_NeoPixel strip(LED_COUNT, LED_PIN, NEO_GRB + NEO_KHZ800);

// Animation variables for OLED
#define NUMFLAKES 10
#define LOGO_HEIGHT 16
#define LOGO_WIDTH 16
#define XPOS   0
#define YPOS   1
#define DELTAY 2
int8_t icons[NUMFLAKES][3];

// State variables
int currentPosition = 0;
int lastPosition = 0;
unsigned long lastOLEDUpdate = 0;
unsigned long lastLCDUpdate = 0;
unsigned long lastEncoderCheck = 0;
unsigned long lastButtonCheck = 0;
int currentColorIndex = 0;
bool buttonBlueState = HIGH;
bool buttonWhiteState = HIGH;
bool lastButtonBlueState = HIGH;
bool lastButtonWhiteState = HIGH;
unsigned long lastButtonBlueChange = 0;
unsigned long lastButtonWhiteChange = 0;
#define DEBOUNCE_TIME 50 // Debounce time in milliseconds

// LED colors array (different colors to cycle through)
uint32_t colors[] = {
  strip.Color(255, 0, 0),      // Red
  strip.Color(0, 255, 0),      // Green
  strip.Color(0, 0, 255),      // Blue
  strip.Color(255, 255, 0),    // Yellow
  strip.Color(0, 255, 255),    // Cyan
  strip.Color(255, 0, 255),    // Magenta
  strip.Color(255, 255, 255),  // White
  strip.Color(127, 127, 127)   // Gray
};
#define NUM_COLORS (sizeof(colors) / sizeof(uint32_t))

// Sound effects for button press
#define NUM_SOUND_EFFECTS 3
const int soundEffectFrequencies[][5] = {
  {262, 330, 392, 330, 262},      // Effect 1: C major chord up and down
  {523, 494, 440, 392, 349},      // Effect 2: Descending scale
  {330, 330, 330, 494, 494}       // Effect 3: Simple melody
};
const int soundEffectDurations[][5] = {
  {100, 100, 100, 100, 125},      // Effect 1 durations - moderate length
  {80, 80, 80, 80, 100},          // Effect 2 durations - moderate length
  {70, 70, 140, 70, 140}          // Effect 3 durations - moderate length
};
int currentSoundEffect = 0;

// Animation frames for LCD/TFT
int currentFrame = 0;
#define MAX_FRAMES 10  // Number of animation frames for TFT

// Audio variables
bool audioEnabled = false;
unsigned long lastAudioUpdate = 0;
uint8_t currentNote = 0;
const int noteFrequencies[] = {262, 294, 330, 349, 392, 440, 494, 523}; // C4 to C5
#define AUDIO_UPDATE_RATE 2000  // Change note every 2 seconds

// Bitmap for OLED animation
static const unsigned char PROGMEM logo_bmp[] = {
  0b00000000, 0b11000000,
  0b00000001, 0b11000000,
  0b00000001, 0b11000000,
  0b00000011, 0b11100000,
  0b11110011, 0b11100000,
  0b11111110, 0b11111000,
  0b01111110, 0b11111111,
  0b00110011, 0b10011111,
  0b00011111, 0b11111100,
  0b00001101, 0b01110000,
  0b00011011, 0b10100000,
  0b00111111, 0b11100000,
  0b00111111, 0b11110000,
  0b01111100, 0b11110000,
  0b01110000, 0b01110000,
  0b00000000, 0b00110000
};

// Function prototypes
void initAnimation();
void updateOLED();
void updateTFT(int frame);
void pngDraw(PNGDRAW *pDraw);
void selectTFT();
void selectOLED();
void checkEncoder();
void initI2S();
void playTone(int frequency, int duration);
void testContinuousTone(int testDuration);
void checkButtons();
void playSoundEffect(int effectIndex);
void updateLEDs(int colorIndex);
void i2s_diagnose();
void directBeepTest();
void testMAX98357A_direct();
void gentleBeep(int count);
void gentleTone(int frequency, int duration);

// Function prototypes for memory reporting
void printMemoryStats();
uint32_t getHeapSize();
uint32_t getFreeMem();
uint32_t getMinFreeMem();
uint8_t getHeapFragmentation();
uint32_t getSketchSize();
uint32_t getFreeSketchSpace();
void simpleToneTest();

// Play a musical scale to test audio
void playMusicScale() {
  Serial.println("Playing musical scale (VERY quiet)...");
  tft.fillRect(10, 10, 220, 30, TFT_BLACK);
  tft.setCursor(10, 10);
  tft.setTextColor(TFT_YELLOW, TFT_BLACK);
  tft.println("PLAYING SCALE (QUIET)");
  
  // Shorter C major scale 
  int notes[] = {262, 330, 392, 523};
  const char* noteNames[] = {"C4", "E4", "G4", "C5"};
  
  // Play the scale with very short durations
  for (int i = 0; i < 4; i++) {
    tft.fillRect(10, 40, 220, 30, TFT_BLACK);
    tft.setCursor(10, 40);
    tft.print("Note: ");
    tft.print(noteNames[i]);
    
    Serial.print("Playing ");
    Serial.print(noteNames[i]);
    Serial.print(" (");
    Serial.print(notes[i]);
    Serial.println("Hz)");
    
    playTone(notes[i], 100); // Very short duration
    delay(50);
  }
  
  tft.fillRect(10, 10, 220, 60, TFT_BLACK);
  tft.setCursor(10, 10);
  tft.setTextColor(TFT_WHITE, TFT_BLACK);
  tft.println("TFT Ready");
}

void setup() {
  // Initialize watchdog
  esp_task_wdt_init(30, false);
  
  Serial.begin(115200);
  delay(1000);
  Serial.println("\n=== BOOT STARTED ===");
  
  // Print initial memory stats
  printMemoryStats();
  
  // Skip problematic I2S tests
  Serial.println("Skipping I2S tests due to audio quality issues");
  
  // Initialize beeper pin
  pinMode(BEEPER_PIN, OUTPUT);
  digitalWrite(BEEPER_PIN, LOW);
  
  // Test gentle beeper
  Serial.println("Testing gentle beeper...");
  gentleBeep(3);
  
  // Set up CS pins
  pinMode(TFT_CS, OUTPUT);
  pinMode(OLED_CS, OUTPUT);
  digitalWrite(TFT_CS, HIGH);
  digitalWrite(OLED_CS, HIGH);
  
  // Initialize encoder - Using the reference code approach
  ESP32Encoder::useInternalWeakPullResistors = puType::up;
  encoder.attachHalfQuad(ROT_DT, ROT_CLK);
  encoder.setCount(0);
  pinMode(ROT_SW, INPUT_PULLUP);
  Serial.println("Encoder initialized");
  
  // Initialize buttons (NOTE: GPIO36 & GPIO39 don't have pull-up resistors!)
  pinMode(BUTTON_BLUE, INPUT);   // No internal pullup available on GPIO36
  pinMode(BUTTON_WHITE, INPUT);  // No internal pullup available on GPIO39
  Serial.println("IMPORTANT: GPIO36 & GPIO39 need EXTERNAL pull-up resistors (~10k ohm)");
  
  // Test buttons at startup
  Serial.println("Button test - Please press each button when prompted");
  
  // Test the blue button
  Serial.println("Press and hold the BLUE button (on GPIO36)...");
  tft.begin();
  tft.fillScreen(TFT_BLACK);
  tft.setTextColor(TFT_WHITE, TFT_BLACK);
  tft.setTextSize(2);
  tft.setCursor(10, 10);
  tft.println("Press BLUE button");
  
  // Wait for button press or timeout
  unsigned long buttonTestStart = millis();
  bool blueTestPassed = false;
  while (millis() - buttonTestStart < 10000) { // 10 second timeout
    if (digitalRead(BUTTON_BLUE) == LOW) {
      blueTestPassed = true;
      tft.fillRect(10, 50, 220, 30, TFT_BLACK);
      tft.setCursor(10, 50);
      tft.setTextColor(TFT_GREEN, TFT_BLACK);
      tft.println("BLUE BUTTON OK!");
      Serial.println("Blue button detected! Test passed.");
      break;
    }
    delay(100);
  }
  
  if (!blueTestPassed) {
    Serial.println("Blue button test timed out. Check connections.");
    tft.fillRect(10, 50, 220, 30, TFT_BLACK);
    tft.setCursor(10, 50);
    tft.setTextColor(TFT_RED, TFT_BLACK);
    tft.println("BLUE BUTTON FAIL!");
  }
  
  delay(1000);
  
  // Test the white button
  Serial.println("Press and hold the WHITE button (on GPIO39)...");
  tft.fillRect(10, 10, 220, 30, TFT_BLACK);
  tft.setCursor(10, 10);
  tft.setTextColor(TFT_WHITE, TFT_BLACK);
  tft.println("Press WHITE button");
  
  // Wait for button press or timeout
  buttonTestStart = millis();
  bool whiteTestPassed = false;
  while (millis() - buttonTestStart < 10000) { // 10 second timeout
    if (digitalRead(BUTTON_WHITE) == LOW) {
      whiteTestPassed = true;
      tft.fillRect(10, 90, 220, 30, TFT_BLACK);
      tft.setCursor(10, 90);
      tft.setTextColor(TFT_GREEN, TFT_BLACK);
      tft.println("WHITE BUTTON OK!");
      Serial.println("White button detected! Test passed.");
      break;
    }
    delay(100);
  }
  
  if (!whiteTestPassed) {
    Serial.println("White button test timed out. Check connections.");
    tft.fillRect(10, 90, 220, 30, TFT_BLACK);
    tft.setCursor(10, 90);
    tft.setTextColor(TFT_RED, TFT_BLACK);
    tft.println("WHITE BUTTON FAIL!");
  }
  
  delay(2000);

  // Additional pull-up strength check - should read HIGH when not pressed
  Serial.print("Button states after test - Blue: ");
  Serial.print(digitalRead(BUTTON_BLUE));
  Serial.print(", White: ");
  Serial.println(digitalRead(BUTTON_WHITE));
  
  // Initialize NeoPixel strip
  strip.begin();
  strip.show(); // Initialize all pixels to 'off'
  strip.setBrightness(LED_BRIGHTNESS);
  
  // Test NeoPixel LEDs with a simple sequence
  Serial.println("Testing NeoPixel LEDs...");
  // Red
  for(int i=0; i<LED_COUNT; i++) {
    strip.setPixelColor(i, strip.Color(255, 0, 0));
  }
  strip.show();
  delay(500);
  // Green
  for(int i=0; i<LED_COUNT; i++) {
    strip.setPixelColor(i, strip.Color(0, 255, 0));
  }
  strip.show();
  delay(500);
  // Blue
  for(int i=0; i<LED_COUNT; i++) {
    strip.setPixelColor(i, strip.Color(0, 0, 255));
  }
  strip.show();
  delay(500);
  
  // Set initial color
  updateLEDs(currentColorIndex);
  Serial.println("NeoPixel initialized and tested");
  
  // Initialize TFT display first
  pinMode(TFT_LED, OUTPUT);
  digitalWrite(TFT_LED, HIGH);
  selectTFT();
  
  Serial.println("Initializing TFT...");
  tft.setRotation(1);
  tft.begin();
  tft.fillScreen(TFT_BLACK);
  tft.setTextColor(TFT_WHITE, TFT_BLACK);
  tft.setTextSize(2);
  tft.setCursor(10, 10);
  tft.println("TFT Ready");
  
  // Start first animation frame on TFT
  updateTFT(0);
  
  // Initialize OLED display second
  Serial.println("Initializing OLED...");
  selectOLED();
  if (!oled.begin(SSD1306_SWITCHCAPVCC)) {
    Serial.println("ERROR: SSD1306 allocation failed");
    while(1) { delay(1000); }
  }
  
  // Initialize I2S for MAX98357A
  Serial.println("Initializing I2S audio...");
  initI2S();
  audioEnabled = true;
  Serial.println("Audio initialized - MODERATE VOLUME");
  
  // Play test tones at moderate volume
  Serial.println("Playing test tones...");
  tft.fillRect(10, 10, 220, 30, TFT_BLACK);
  tft.setCursor(10, 10);
  tft.setTextColor(TFT_CYAN, TFT_BLACK);
  tft.println("TESTING AUDIO");
  
  // Play two test tones
  playTone(440, 150);  // A4
  delay(200);
  playTone(523, 150);  // C5
  
  tft.fillRect(10, 10, 220, 30, TFT_BLACK);
  tft.setCursor(10, 10);
  tft.setTextColor(TFT_WHITE, TFT_BLACK);
  tft.println("TFT Ready");
  
  // Don't play full scale by default - too loud
  // playMusicScale();
  
  // Initialize animation
  initAnimation();
  
  // Show starting animation on OLED
  oled.clearDisplay();
  oled.setTextSize(1);
  oled.setTextColor(SSD1306_WHITE);
  oled.setCursor(0, 0);
  oled.println("Animation starting...");
  oled.display();
  
  // Play a startup tone
  playTone(440, 200);  // A4 note
  delay(100);
  playTone(880, 300);  // A5 note
  
  // Initialize timing
  lastOLEDUpdate = millis();
  lastLCDUpdate = millis();
  lastEncoderCheck = millis();
  lastAudioUpdate = millis();
  lastButtonCheck = millis();
  
  Serial.println("Setup complete - Both animations running");
  Serial.println("Rotate encoder to change animation frame and audio tone");
  Serial.println("Press BLUE button for sound effects");
  Serial.println("Press WHITE button to change LED colors");
}

void loop() {
  unsigned long currentMillis = millis();
  
  // Print memory stats every 30 seconds
  static unsigned long lastMemoryCheck = 0;
  if (currentMillis - lastMemoryCheck >= 30000) {
    lastMemoryCheck = currentMillis;
    printMemoryStats();
  }
  
  // Check buttons with high priority
  if (currentMillis - lastButtonCheck >= BUTTON_CHECK_RATE) {
    lastButtonCheck = currentMillis;
    checkButtons();
  }
  
  // Check encoder with priority and high frequency
  if (currentMillis - lastEncoderCheck >= ENCODER_CHECK_RATE) {
    lastEncoderCheck = currentMillis;
    checkEncoder();
  }
  
  // Update OLED animation
  if (currentMillis - lastOLEDUpdate >= ANIMATION_RATE) {
    lastOLEDUpdate = currentMillis;
    updateOLED();
  }
  
  // Update TFT/LCD animation
  if (currentMillis - lastLCDUpdate >= LCD_ANIMATION_RATE) {
    lastLCDUpdate = currentMillis;
    
    // Advance animation frame
    currentFrame = (currentFrame + 1) % MAX_FRAMES;
    
    // Update TFT with new frame
    selectTFT();
    updateTFT(currentFrame);
    selectOLED(); // Switch back to OLED for snowflake animation
  }
  
  // Update audio tone periodically
  if (audioEnabled && currentMillis - lastAudioUpdate >= AUDIO_UPDATE_RATE) {
    lastAudioUpdate = currentMillis;
    
    // Advance to next note
    currentNote = (currentNote + 1) % 8;
    
    // Play the current note
    playTone(noteFrequencies[currentNote], 500);
    
    // Show the note on TFT display
    selectTFT();
    tft.setTextSize(2);
    tft.setCursor(tft.width() - 80, 10);
    tft.setTextColor(TFT_YELLOW, TFT_BLACK);
    tft.print("Note: ");
    tft.print(currentNote + 1);
    selectOLED();
  }
  
  // Allow other tasks to run
  yield();
}

// Check push buttons and respond to presses
void checkButtons() {
  unsigned long currentMillis = millis();
  
  // Read current button states (LOW when pressed because of INPUT_PULLUP)
  bool rawBlueState = digitalRead(BUTTON_BLUE);
  bool rawWhiteState = digitalRead(BUTTON_WHITE);
  
  // Print for debugging
  static unsigned long lastButtonPrint = 0;
  if (currentMillis - lastButtonPrint > 1000) { // Print every second
    Serial.print("Current button raw states - Blue: ");
    Serial.print(rawBlueState);
    Serial.print(", White: ");
    Serial.println(rawWhiteState);
    lastButtonPrint = currentMillis;
  }
  
  // Debounce blue button
  if (rawBlueState != lastButtonBlueState) {
    lastButtonBlueChange = currentMillis;
    Serial.print("Blue button state changed to: ");
    Serial.println(rawBlueState);
  }
  
  // Debounce white button
  if (rawWhiteState != lastButtonWhiteState) {
    lastButtonWhiteChange = currentMillis;
    Serial.print("White button state changed to: ");
    Serial.println(rawWhiteState);
  }
  
  // Update states after debounce period
  if (currentMillis - lastButtonBlueChange > DEBOUNCE_TIME) {
    // If state is stable for debounce period, update the current state
    if (rawBlueState != buttonBlueState) {
      buttonBlueState = rawBlueState;
      
      // If button was just pressed (transition to ACTIVE state)
      if (buttonBlueState == BUTTON_ACTIVE) {
        Serial.println("*** BLUE BUTTON PRESSED - PLAYING SOUND ***");
        
        // Quick acknowledgment beep
        digitalWrite(BEEPER_PIN, HIGH);
        delay(5);
        digitalWrite(BEEPER_PIN, LOW);
        
        // Play the current sound effect
        playSoundEffect(currentSoundEffect);
        
        // Move to next sound effect for next press
        currentSoundEffect = (currentSoundEffect + 1) % NUM_SOUND_EFFECTS;
        
        // Update display to show which effect was played
        selectTFT();
        tft.fillRect(10, 90, 200, 30, TFT_BLACK);
        tft.setTextColor(TFT_CYAN, TFT_BLACK);
        tft.setTextSize(2);
        tft.setCursor(10, 90);
        tft.print("Effect: ");
        tft.print(currentSoundEffect + 1);
        selectOLED();
      }
    }
  }
  
  if (currentMillis - lastButtonWhiteChange > DEBOUNCE_TIME) {
    // If state is stable for debounce period, update the current state
    if (rawWhiteState != buttonWhiteState) {
      buttonWhiteState = rawWhiteState;
      
      // If button was just pressed (transition to ACTIVE state)
      if (buttonWhiteState == BUTTON_ACTIVE) {
        Serial.println("*** WHITE BUTTON PRESSED - CHANGING COLOR ***");
        
        // Quick acknowledgment beep
        digitalWrite(BEEPER_PIN, HIGH);
        delay(5);
        digitalWrite(BEEPER_PIN, LOW);
        
        // Change LED color
        currentColorIndex = (currentColorIndex + 1) % NUM_COLORS;
        
        Serial.print("New LED color index: ");
        Serial.println(currentColorIndex);
        
        // Force an immediate LED update
        updateLEDs(currentColorIndex);
        
        // Update display to show which color is active
        selectTFT();
        tft.fillRect(10, 130, 200, 30, TFT_BLACK);
        tft.setTextColor(TFT_MAGENTA, TFT_BLACK);
        tft.setTextSize(2);
        tft.setCursor(10, 130);
        tft.print("Color: ");
        tft.print(currentColorIndex + 1);
        selectOLED();
      }
    }
  }
  
  // Save the raw button states for next comparison
  lastButtonBlueState = rawBlueState;
  lastButtonWhiteState = rawWhiteState;
}

// Play one of the predefined sound effects
void playSoundEffect(int effectIndex) {
  Serial.print("Playing sound effect #");
  Serial.print(effectIndex + 1);
  Serial.println(" with MODERATE volume");
  
  if (audioEnabled) {
    // Play the sound effect using I2S at moderate volume
    for (int i = 0; i < 5; i++) {
      int freq = soundEffectFrequencies[effectIndex][i];
      int duration = soundEffectDurations[effectIndex][i]; // Use the full durations
      
      Serial.print(freq);
      Serial.print("Hz ");
      
      playTone(freq, duration);
      delay(30); // Moderate gap between tones
    }
    Serial.println();
  } else {
    // Fallback to GPIO beeps if I2S not available
    Serial.println(" (using GPIO beeper fallback)");
    for (int i = 0; i < 3; i++) {
      gentleTone(262 + (i * 50), 50); // Moderate beeps
      delay(30);
    }
  }
}

// Update all LEDs to a specific color
void updateLEDs(int colorIndex) {
  for (int i = 0; i < LED_COUNT; i++) {
    strip.setPixelColor(i, colors[colorIndex]);
  }
  strip.show();
}

// Initialize the animation flakes positions
void initAnimation() {
  for (int8_t f = 0; f < NUMFLAKES; f++) {
    icons[f][XPOS] = random(1 - LOGO_WIDTH, SCREEN_WIDTH);
    icons[f][YPOS] = -LOGO_HEIGHT;
    icons[f][DELTAY] = random(2, 8);
  }
}

void checkEncoder() {
  // Get the current encoder position using the reference approach
  long rawPos = encoder.getCount();
  
  // Clamp within a reasonable range
  if (rawPos < 0) {
    rawPos = 0;
    encoder.setCount(0);
  } else if (rawPos > 1000) {
    rawPos = 1000;
    encoder.setCount(1000);
  }
  
  // See if position has changed
  if (rawPos != lastPosition) {
    // Position changed, update the display value
    currentPosition = rawPos;
    lastPosition = rawPos;
    
    // Print position to serial
    Serial.print("Encoder position: ");
    Serial.println(currentPosition);
    
    // Force an immediate TFT update with the new position
    selectTFT();
    
    // Display the position on TFT
    tft.setTextSize(2);
    tft.setCursor(10, tft.height() - 30);
    tft.setTextColor(TFT_WHITE, TFT_BLACK);
    tft.print("Pos: ");
    tft.print(currentPosition);
    tft.print("   "); // Clear any remaining digits
    
    // Play moderate feedback at reasonable intervals
    if (rawPos % 10 == 0) { // Every 10 positions (compromise between 5 and 20)
      if (audioEnabled) {
        // Map encoder position to frequency (500-1500 Hz)
        int freq = map(currentPosition, 0, 1000, 500, 1500);
        playTone(freq, 40);  // Moderate duration beep
      } else {
        // Fallback to GPIO beep
        digitalWrite(BEEPER_PIN, HIGH);
        delayMicroseconds(300); // Moderate duration pulse
        digitalWrite(BEEPER_PIN, LOW);
      }
    }
    
    // Return to OLED for animation
    selectOLED();
  }
}

void updateOLED() {
  // Make sure OLED is selected
  selectOLED();
  
  // Update animation positions
  for (int8_t f = 0; f < NUMFLAKES; f++) {
      icons[f][YPOS] += icons[f][DELTAY];
      
    if (icons[f][YPOS] >= SCREEN_HEIGHT) {
      icons[f][XPOS] = random(1 - LOGO_WIDTH, SCREEN_WIDTH);
      icons[f][YPOS] = -LOGO_HEIGHT;
        icons[f][DELTAY] = random(2, 8);
      }
    }
  
  // Draw animation frame
  oled.clearDisplay();
    
  // Draw current encoder position at top
  oled.setTextSize(1);
  oled.setCursor(0, 0);
  oled.print("Pos: ");
  oled.print(currentPosition);
  
  // Draw animation bitmaps
  for (int8_t f = 0; f < NUMFLAKES; f++) {
    oled.drawBitmap(
      icons[f][XPOS], 
      icons[f][YPOS], 
      logo_bmp, 
      LOGO_WIDTH, LOGO_HEIGHT, 
      SSD1306_WHITE
    );
    }
  
  oled.display();
}

void pngDraw(PNGDRAW *pDraw) {
  // Create a line buffer for the PNG image
  static uint16_t lineBuffer[MAX_IMAGE_WIDTH];
  
  // Get the line data from the PNG decoder
  png.getLineAsRGB565(pDraw, lineBuffer, PNG_RGB565_BIG_ENDIAN, 0xffffffff);
  
  // Push the line to the TFT
  tft.pushImage(0, pDraw->y, pDraw->iWidth, 1, lineBuffer);
}

void updateTFT(int frame) {
  // Clear the entire screen with a random color every few frames
  if (frame % 3 == 0) {
    tft.fillScreen(random(0x10000));
  } else {
    // Otherwise just clear animation area
    tft.fillRect(0, 0, tft.width(), tft.height() - 40, TFT_BLACK);
  }
  
  // Try to load PNG image if available (first attempt)
  int16_t rc = png.openFLASH((uint8_t *)images, sizeof(images), pngDraw);
  if (rc == PNG_SUCCESS) {
    tft.startWrite();
    rc = png.decode(NULL, 0);
    tft.endWrite();
  } else {
    // If PNG fails, draw a simple animation pattern
    for (int i = 0; i < 10; i++) {
      int radius = 10 + i * 5;
      int x = tft.width() / 2 + sin((frame + i) * 0.2) * (tft.width() / 4);
      int y = tft.height() / 3 + cos((frame + i) * 0.2) * (tft.height() / 6);
      
      // Alternate colors based on frame
      uint16_t color = ((frame + i) % 2) ? TFT_RED : TFT_BLUE;
      
      tft.fillCircle(x, y, radius, color);
    }
  }

  // Draw the frame number
  tft.setTextSize(2);
  tft.setCursor(10, tft.height() - 60);
  tft.setTextColor(TFT_GREEN, TFT_BLACK);
  tft.print("Frame: ");
  tft.print(frame);
  
  // Draw the encoder position
  tft.setTextSize(2);
  tft.setCursor(10, tft.height() - 30);
  tft.setTextColor(TFT_WHITE, TFT_BLACK);
  tft.print("Pos: ");
  tft.print(currentPosition);
}

// Initialize I2S for MAX98357A
void initI2S() {
  // Print pins being used
  Serial.println("Initializing I2S with correct pins:");
  Serial.print("BCLK: "); Serial.println(I2S_BCLK);
  Serial.print("LRC/WS: "); Serial.println(I2S_LRC);
  Serial.print("DIN/DATA: "); Serial.println(I2S_DOUT);
  
  esp_err_t err;
  
  // Try alternative I2S config for MAX98357A with correct pins
  i2s_config_t i2s_config = {
    .mode = (i2s_mode_t)(I2S_MODE_MASTER | I2S_MODE_TX),
    .sample_rate = 44100,
    .bits_per_sample = I2S_BITS_PER_SAMPLE_16BIT,
    .channel_format = I2S_CHANNEL_FMT_ONLY_LEFT,  // Changed to ONLY_LEFT for MAX98357A
    .communication_format = I2S_COMM_FORMAT_STAND_I2S,
    .intr_alloc_flags = ESP_INTR_FLAG_LEVEL1,
    .dma_buf_count = 8,
    .dma_buf_len = 64,
    .use_apll = false,
    .tx_desc_auto_clear = true,
    .fixed_mclk = 0
  };
  
  // Install driver
  err = i2s_driver_install(I2S_PORT, &i2s_config, 0, NULL);
  if (err != ESP_OK) {
    Serial.print("Failed to install I2S driver: ");
    Serial.println(err);
    return;
  }
  
  // Configure pins
  i2s_pin_config_t pin_config = {
    .bck_io_num = I2S_BCLK,
    .ws_io_num = I2S_LRC,
    .data_out_num = I2S_DOUT,
    .data_in_num = I2S_PIN_NO_CHANGE
  };
  
  // Set pins
  err = i2s_set_pin(I2S_PORT, &pin_config);
  if (err != ESP_OK) {
    Serial.print("Failed to set I2S pins: ");
    Serial.println(err);
    return;
  }
  
  // Set the sample rate
  i2s_set_sample_rates(I2S_PORT, 44100);
  
  // Clear the DMA buffers
  i2s_zero_dma_buffer(I2S_PORT);
  
  Serial.println("I2S initialized successfully with correct pins");
  audioEnabled = true;
}

// Play a tone of the specified frequency for the specified duration
void playTone(int frequency, int duration) {
  // Use only I2S with moderate volume
  if (!audioEnabled) {
    Serial.println("Audio not enabled, using GPIO beeper instead");
    gentleTone(frequency, duration);
    return;
  }
  
  Serial.print("Playing I2S tone (moderate volume): ");
  Serial.print(frequency);
  Serial.println("Hz");
  
  // Using moderate amplitude (3% of maximum)
  int16_t amplitude = 1000; // Increased from 300 to 1000, still much less than maximum (30000)
  
  // Number of samples to generate
  int numSamples = (44100 * duration) / 1000;
  
  // Samples per cycle
  float samplesPerCycle = 44100 / (float)frequency;
  
  // Generate and play the tone
  for (int i = 0; i < numSamples; i++) {
    // Generate a sine wave with moderate amplitude
    float angle = 2.0 * PI * i / samplesPerCycle;
    int16_t sample = amplitude * sin(angle);
    
    // Create stereo sample (same value for both channels)
    int32_t stereoSample = (sample << 16) | (sample & 0xffff);
    
    // Write the sample to the I2S port
    size_t bytesWritten;
    i2s_write(I2S_PORT, &stereoSample, sizeof(stereoSample), &bytesWritten, 0);
  }
}

// Very gentle beep function that won't hurt ears
void gentleBeep(int count) {
  for (int i = 0; i < count; i++) {
    // Very short, gentle beep
    digitalWrite(BEEPER_PIN, HIGH);
    delay(10);
    digitalWrite(BEEPER_PIN, LOW);
    delay(200);
  }
}

// Use GPIO to generate a tone of specified frequency for specified duration
void gentleTone(int frequency, int duration) {
  // Calculate period in microseconds
  int period = 1000000 / frequency;
  int halfPeriod = period / 2;
  
  // Calculate how many cycles to generate
  long cycles = (long)frequency * duration / 1000;
  
  // Limit maximum cycles to avoid blocking too long
  if (cycles > 1000) {
    cycles = 1000;
  }
  
  // Generate square wave at specified frequency
  for (long i = 0; i < cycles; i++) {
    digitalWrite(BEEPER_PIN, HIGH);
    delayMicroseconds(halfPeriod / 4); // 25% duty cycle for quieter sound
    digitalWrite(BEEPER_PIN, LOW);
    delayMicroseconds(halfPeriod * 3 / 4); // 75% off time
  }
}

// Additional diagnostic function to help with the audio issues
void i2s_diagnose() {
  Serial.println("\nI2S Diagnostic Test");
  Serial.println("-----------------");
  
  // Check if pins are correctly set
  Serial.println("Step 1: Verifying pins...");
  if (I2S_DOUT < 0 || I2S_BCLK < 0 || I2S_LRC < 0) {
    Serial.println("ERROR: Invalid pin configuration");
    return;
  }
  Serial.println("Pins appear valid");
  
  // Test if we can write a simple pattern
  Serial.println("Step 2: Testing simple write...");
  int32_t test_sample = 0xAABBCCDD; // Test pattern
  size_t bytes_written = 0;
  
  esp_err_t err = i2s_write(I2S_PORT, &test_sample, sizeof(test_sample), &bytes_written, 100);
  if (err != ESP_OK) {
    Serial.print("ERROR: I2S write failed with error: ");
    Serial.println(err);
  } else {
    Serial.print("Successfully wrote ");
    Serial.print(bytes_written);
    Serial.println(" bytes to I2S");
  }
  
  Serial.println("Step 3: Testing MAX98357A...");
  Serial.println("Playing a 1kHz test tone for 1 second...");
  
  // Generate a 1kHz tone for 1 second
  float sample_rate = SAMPLE_RATE;
  float freq = 1000.0;
  int duration_ms = 1000;
  int num_samples = (sample_rate * duration_ms) / 1000;
  float samples_per_cycle = sample_rate / freq;
  
  for (int i = 0; i < num_samples; i++) {
    float angle = 2.0 * PI * i / samples_per_cycle;
    int16_t sample = 30000 * sin(angle);
    int32_t stereo_sample = (sample << 16) | (sample & 0xffff);
    
    i2s_write(I2S_PORT, &stereo_sample, sizeof(stereo_sample), &bytes_written, 0);
    
    // Print progress every 10% of the way
    if (i % (num_samples / 10) == 0) {
      Serial.print(".");
    }
  }
  
  Serial.println("\nDiagnostic complete");
}

// Test function for continuous tone - useful for troubleshooting
// Duration in milliseconds, will return after that time
void testContinuousTone(int testDuration) {
  Serial.println("Testing with gentle beeps instead of continuous tone");
  tft.fillRect(10, 10, 220, 30, TFT_BLACK);
  tft.setCursor(10, 10);
  tft.setTextColor(TFT_GREEN, TFT_BLACK);
  tft.println("GENTLE BEEP TEST");
  
  // Series of gentle beeps
  int beepCount = 5;
  int beepDuration = testDuration / (beepCount * 2);
  
  for (int i = 0; i < beepCount; i++) {
    digitalWrite(BEEPER_PIN, HIGH);
    delay(5);
    digitalWrite(BEEPER_PIN, LOW);
    delay(beepDuration);
  }
  
  Serial.println("Beep test complete");
}

// Display selection functions with busy wait to ensure completion
void selectTFT() {
  digitalWrite(OLED_CS, HIGH); // Disable OLED
  delayMicroseconds(10);       // Short delay for pin to stabilize
  digitalWrite(TFT_CS, LOW);   // Enable TFT
  delayMicroseconds(10);       // Short delay for pin to stabilize
}

void selectOLED() {
  digitalWrite(TFT_CS, HIGH);  // Disable TFT
  delayMicroseconds(10);       // Short delay for pin to stabilize
  digitalWrite(OLED_CS, LOW);  // Enable OLED
  delayMicroseconds(10);       // Short delay for pin to stabilize
}

// Memory reporting functions
void printMemoryStats() {
  Serial.println("\n=== MEMORY STATS ===");
  Serial.print("Total heap size: ");
  Serial.print(getHeapSize());
  Serial.println(" bytes");
  
  Serial.print("Free heap memory: ");
  Serial.print(getFreeMem());
  Serial.print(" bytes (");
  Serial.print((getFreeMem() * 100.0) / getHeapSize(), 1);
  Serial.println("%)");
  
  Serial.print("Minimum free memory: ");
  Serial.print(getMinFreeMem());
  Serial.println(" bytes");
  
  Serial.print("Heap fragmentation: ");
  Serial.print(getHeapFragmentation());
  Serial.println("%");
  
  Serial.print("Sketch size: ");
  Serial.print(getSketchSize());
  Serial.print(" bytes (");
  Serial.print((getSketchSize() * 100.0) / (getSketchSize() + getFreeSketchSpace()), 1);
  Serial.println("% of flash used)");
  
  Serial.print("Free sketch space: ");
  Serial.print(getFreeSketchSpace());
  Serial.println(" bytes");
  Serial.println("===================\n");
}

uint32_t getHeapSize() {
  multi_heap_info_t info;
  heap_caps_get_info(&info, MALLOC_CAP_INTERNAL);
  return info.total_free_bytes + info.total_allocated_bytes;
}

uint32_t getFreeMem() {
  return heap_caps_get_free_size(MALLOC_CAP_INTERNAL);
}

uint32_t getMinFreeMem() {
  return heap_caps_get_minimum_free_size(MALLOC_CAP_INTERNAL);
}

uint8_t getHeapFragmentation() {
  multi_heap_info_t info;
  heap_caps_get_info(&info, MALLOC_CAP_INTERNAL);
  return 100 - (info.largest_free_block * 100) / info.total_free_bytes;
}

uint32_t getSketchSize() {
  return ESP.getSketchSize();
}

uint32_t getFreeSketchSpace() {
  return ESP.getFreeSketchSpace();
}

// Alternative simpler audio test function
void simpleToneTest() {
  Serial.println("Generating simple square wave test tone...");
  tft.fillRect(10, 10, 220, 30, TFT_BLACK);
  tft.setCursor(10, 10);
  tft.setTextColor(TFT_RED, TFT_BLACK);
  tft.println("SQUARE WAVE TEST");
  
  // Generate a square wave (simpler than sine wave)
  uint16_t sample = 0;
  size_t bytes_written;
  
  Serial.println("Playing 440Hz square wave for 3 seconds");
  unsigned long endTime = millis() + 3000;
  
  // Just generate a simple square wave alternating between max and min values
  while (millis() < endTime) {
    // Simple square wave at ~440Hz
    for (int i = 0; i < 50; i++) {
      // HIGH portion of square wave
      sample = 32767;  // Maximum positive 16-bit value
      i2s_write(I2S_PORT, &sample, sizeof(sample), &bytes_written, 0);
    }
    
    for (int i = 0; i < 50; i++) {
      // LOW portion of square wave
      sample = -32767;  // Maximum negative 16-bit value
      i2s_write(I2S_PORT, &sample, sizeof(sample), &bytes_written, 0);
    }
  }
  
  Serial.println("Square wave test complete");
}

// Direct GPIO beep test as fallback audio method
void directBeepTest() {
  Serial.println("Testing direct GPIO beeper on pin " + String(BEEPER_PIN));
  tft.fillRect(10, 10, 220, 30, TFT_BLACK);
  tft.setCursor(10, 10);
  tft.setTextColor(TFT_YELLOW, TFT_BLACK);
  tft.println("DIRECT BEEP TEST");
  
  // Set up beeper pin
  pinMode(BEEPER_PIN, OUTPUT);
  
  // Play a series of beeps
  for (int i = 0; i < 3; i++) {
    Serial.println("Beep " + String(i+1));
    
    // Generate 500Hz tone for 500ms
    unsigned long endTime = millis() + 500;
    while (millis() < endTime) {
      digitalWrite(BEEPER_PIN, HIGH);
      delayMicroseconds(1000); // 1000us on
      digitalWrite(BEEPER_PIN, LOW);
      delayMicroseconds(1000); // 1000us off
    }
    
    delay(300); // Pause between beeps
  }
  
  Serial.println("Direct beep test complete");
}

// Direct bit-banged I2S test for MAX98357A
void testMAX98357A_direct() {
  Serial.println("Testing MAX98357A with direct bit-banging (reduced volume)");
  Serial.println("Using pins - BCLK: " + String(I2S_BCLK) + 
                 ", LRC: " + String(I2S_LRC) + 
                 ", DATA: " + String(I2S_DOUT));
                 
  // Set up pins manually
  pinMode(I2S_BCLK, OUTPUT);
  pinMode(I2S_LRC, OUTPUT);
  pinMode(I2S_DOUT, OUTPUT);
  
  // Initial state
  digitalWrite(I2S_BCLK, LOW);
  digitalWrite(I2S_LRC, LOW);
  digitalWrite(I2S_DOUT, LOW);
  
  Serial.println("Generating gentle tone pattern...");
  
  // Generate a simple square wave pattern
  // Using a low frequency to allow bit-banging to work
  // 500Hz square wave for 2 seconds
  unsigned long endTime = millis() + 2000;
  
  // Crude bit-banged I2S - but gentler on the ears
  while (millis() < endTime) {
    // Left channel data (MAX98357A will use this)
    digitalWrite(I2S_LRC, LOW);
    
    // Send 16 bits of square wave data with reduced duty cycle for lower volume
    for (int i = 0; i < 16; i++) {
      // Clock low
      digitalWrite(I2S_BCLK, LOW);
      delayMicroseconds(10);
      
      // Send pulse with reduced duty cycle (25% instead of 50%)
      digitalWrite(I2S_DOUT, (i < 4) ? HIGH : LOW);
      
      // Clock high
      digitalWrite(I2S_BCLK, HIGH);
      delayMicroseconds(10);
    }
    
    // Right channel data (MAX98357A will ignore this)
    digitalWrite(I2S_LRC, HIGH);
    
    // Send 16 bits of dummy data
    for (int i = 0; i < 16; i++) {
      // Clock low
      digitalWrite(I2S_BCLK, LOW);
      delayMicroseconds(10);
      
      // Just send zeros
      digitalWrite(I2S_DOUT, LOW);
      
      // Clock high
      digitalWrite(I2S_BCLK, HIGH);
      delayMicroseconds(10);
    }
  }
  
  // Reset pins
  digitalWrite(I2S_BCLK, LOW);
  digitalWrite(I2S_LRC, LOW);
  digitalWrite(I2S_DOUT, LOW);
  
  Serial.println("Direct MAX98357A test complete");
} 