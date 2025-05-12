#include <Arduino.h>
#include <TFT_eSPI.h>
#include <FS.h>
#include <SPIFFS.h>
#include <driver/i2s.h>
#include "Faces.h"

// Declare external PROGMEM image arrays
extern const unsigned char anime_face_girl_1[] PROGMEM;
extern const unsigned char anime_face_girl_2[] PROGMEM;

// TFT_eSPI instance
TFT_eSPI tft = TFT_eSPI();

// I2S configuration for MAX98357A
#define I2S_NUM         I2S_NUM_0
#define I2S_DOUT        27
#define I2S_BCLK        25
#define I2S_LRC         26

// Backlight pin
#define TFT_BL 32

// Button pin for advancing dialogue
#define BUTTON_PIN 35

// WAV file info structure
struct WavHeader {
  char riff[4];
  uint32_t fileSize;
  char wave[4];
  char fmt[4];
  uint32_t fmtSize;
  uint16_t audioFormat;
  uint16_t numChannels;
  uint32_t sampleRate;
  uint32_t byteRate;
  uint16_t blockAlign;
  uint16_t bitsPerSample;
  char data[4];
  uint32_t dataSize;
};

// Audio playback variables
fs::File audioFile;
bool isPlaying = false;
bool soundEnabled = true;

// Dialogue structure
struct DialogueLine {
  const char* text;
  int faceIndex;
};

// Define dialogues
DialogueLine dialogues[] = {
  {"* There are a few puzzles ahead...", 0},
  {"* You'll need to be clever!", 1},
  {"* Don't worry, I'll help you.", 0},
  {"* Are you ready for the challenge?", 1}
};

// Dialogue state variables
int currentDialogue = 0;
int dialogueIndex = 0;
unsigned long lastCharTime = 0;
const int charDelay = 40;
const int pauseDelay = 200;
int soundToggle = 0;
bool dialogueComplete = false;
bool faceAnimationState = false;

// Chatbox dimensions
#define CHATBOX_X 20
#define CHATBOX_Y 200
#define CHATBOX_W 440
#define CHATBOX_H 110
#define TEXT_X 180
#define TEXT_Y 210
#define TEXT_MAX_COLS 18
#define TEXT_MAX_ROWS 3
#define FACE_X 35
#define FACE_Y 210
#define FACE_W 128
#define FACE_H 64

// Function prototypes
void drawChatbox();
void playCharSound(bool useDoubleTime, float volume);
void updateFace(int faceIndex);
void advanceDialogue();
bool checkButtonPress();

void setup() {
  Serial.begin(115200);
  Serial.println("Starting Undertale dialogue system...");

  // Initialize backlight
  pinMode(TFT_BL, OUTPUT);
  digitalWrite(TFT_BL, HIGH);

  // Initialize TFT
  tft.begin();
  tft.setRotation(1);
  tft.fillScreen(TFT_WHITE);

  // Initialize SPIFFS
  if (!SPIFFS.begin(true)) {
    Serial.println("SPIFFS initialization failed!");
    while (1) delay(1000);
  }

  // Check sound files
  if (!SPIFFS.exists("/letter1.wav") || !SPIFFS.exists("/letter2.wav")) {
    Serial.println("Warning: Sound files not found in SPIFFS!");
    Serial.println("Please upload letter1.wav and letter2.wav to SPIFFS");
    soundEnabled = false;
  }

  // Initialize I2S
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
  
  i2s_driver_install(I2S_NUM, &i2s_config, 0, NULL);
  i2s_set_pin(I2S_NUM, &pin_config);

  // Draw initial chatbox
  drawChatbox();
  updateFace(dialogues[currentDialogue].faceIndex);
  
  lastCharTime = millis();
  Serial.println("Setup complete. Press 'n' in Serial Monitor to advance dialogue.");
}

void drawChatbox() {
  tft.fillRect(CHATBOX_X, CHATBOX_Y, CHATBOX_W, CHATBOX_H, TFT_BLACK);
  tft.drawRect(CHATBOX_X, CHATBOX_Y, CHATBOX_W, CHATBOX_H, TFT_WHITE);
}

void updateFace(int faceIndex) {
  // Clear face area
  tft.fillRect(FACE_X, FACE_Y, FACE_W, FACE_H, TFT_BLACK);

  // Select bitmap
  const unsigned char* bitmap = (faceIndex == 0) 
    ? (faceAnimationState ? anime_face_girl_1 : anime_face_girl_2) 
    : (faceAnimationState ? anime_face_girl_2 : anime_face_girl_1);

  // Create a temporary buffer for one row at a time
  uint16_t rowBuffer[FACE_W]; // 128 pixels per row

  // Process each row
  for (int y = 0; y < FACE_H; y++) {
    // Convert one row of bitmap data to pixel colors
    for (int x = 0; x < FACE_W; x++) {
      int srcByte = (y * FACE_W + x) / 8;
      int srcBit = 7 - (x % 8);
      bool pixel = (pgm_read_byte(&bitmap[srcByte]) >> srcBit) & 1;
      rowBuffer[x] = pixel ? TFT_WHITE : TFT_BLACK;
    }
    // Push the row to the display
    tft.pushImage(FACE_X, FACE_Y + y, FACE_W, 1, rowBuffer);
  }
}

void playCharSound(bool useDoubleTime, float volume) {
  if (!soundEnabled) return;

  if (isPlaying) {
    i2s_zero_dma_buffer(I2S_NUM);
    isPlaying = false;
    if (audioFile) audioFile.close();
  }

  const char* wavFile = useDoubleTime ? "/letter2.wav" : "/letter1.wav";
  audioFile = SPIFFS.open(wavFile, "r");
  if (!audioFile) {
    Serial.printf("Failed to open WAV file: %s\n", wavFile);
    return;
  }

  WavHeader header;
  audioFile.read((uint8_t*)&header, sizeof(WavHeader));

  if (strncmp(header.riff, "RIFF", 4) != 0 || 
      strncmp(header.wave, "WAVE", 4) != 0 || 
      strncmp(header.fmt, "fmt ", 4) != 0 ||
      strncmp(header.data, "data", 4) != 0) {
    Serial.println("Invalid WAV file format!");
    audioFile.close();
    return;
  }

  i2s_set_sample_rates(I2S_NUM, header.sampleRate);

  uint32_t samplesPerSecond = header.sampleRate;
  uint16_t bytesPerSample = header.bitsPerSample / 8;
  uint32_t samplesToPlay = samplesPerSecond * 0.05;
  uint32_t bytesToPlay = samplesToPlay * bytesPerSample * header.numChannels;

  if (bytesToPlay > header.dataSize) bytesToPlay = header.dataSize;

  uint8_t buffer[512];
  int16_t sampleBuffer[256];
  size_t bytesRead;
  size_t totalBytesPlayed = 0;

  isPlaying = true;
  while (totalBytesPlayed < bytesToPlay) {
    size_t bytesToRead = min(sizeof(buffer), (size_t)(bytesToPlay - totalBytesPlayed));
    bytesRead = audioFile.read(buffer, bytesToRead);
    if (bytesRead == 0) break;

    size_t sampleCount = bytesRead / 2;
    memcpy(sampleBuffer, buffer, bytesRead);
    for (size_t i = 0; i < sampleCount; i++) {
      sampleBuffer[i] = (int16_t)(sampleBuffer[i] * volume);
    }

    size_t bytesWritten;
    i2s_write(I2S_NUM, sampleBuffer, bytesRead, &bytesWritten, portMAX_DELAY);
    totalBytesPlayed += bytesWritten;
  }

  audioFile.close();
  isPlaying = false;
}

void advanceDialogue() {
  currentDialogue++;
  if (currentDialogue >= sizeof(dialogues) / sizeof(dialogues[0])) {
    currentDialogue = 0;
  }
  
  dialogueIndex = 0;
  soundToggle = 0;
  dialogueComplete = false;
  
  tft.fillRect(CHATBOX_X + 5, CHATBOX_Y + 5, CHATBOX_W - 10, CHATBOX_H - 10, TFT_BLACK);
  updateFace(dialogues[currentDialogue].faceIndex);
}

bool checkButtonPress() {
  if (Serial.available()) {
    char cmd = Serial.read();
    if (cmd == 'n' || cmd == 'N') return true;
  }
  return false;
}

void loop() {
  unsigned long currentTime = millis();

  if (!dialogueComplete && 
      dialogueIndex < strlen(dialogues[currentDialogue].text) && 
      currentTime - lastCharTime >= charDelay) {
    
    int col = dialogueIndex % TEXT_MAX_COLS;
    int row = dialogueIndex / TEXT_MAX_COLS;

    if (row >= TEXT_MAX_ROWS) {
      dialogueComplete = true;
      return;
    }

    char currentChar = dialogues[currentDialogue].text[dialogueIndex];
    
    tft.setTextColor(TFT_WHITE);
    tft.setTextSize(2);
    tft.setCursor(TEXT_X + col * 15, TEXT_Y + row * 20);
    tft.print(currentChar);

    if (currentChar != ' ') {
      bool useDoubleTime = (soundToggle % 2 == 1);
      playCharSound(useDoubleTime, 0.4);
      soundToggle++;
    }

    if (currentChar == ' ') {
      lastCharTime = currentTime;
    } else if (currentChar == '.' || currentChar == ',' || currentChar == '!') {
      lastCharTime = currentTime + pauseDelay - charDelay;
    } else {
      lastCharTime = currentTime;
    }

    dialogueIndex++;
    
    if (dialogueIndex >= strlen(dialogues[currentDialogue].text)) {
      dialogueComplete = true;
      Serial.println("Dialogue complete. Press 'n' to continue.");
      faceAnimationState = !faceAnimationState;
      updateFace(dialogues[currentDialogue].faceIndex);
    }
  }

  if (dialogueComplete && checkButtonPress()) {
    advanceDialogue();
  }
}
