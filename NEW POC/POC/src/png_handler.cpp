#include "png_handler.h"

PNG png;
int16_t xpos = 0;
int16_t ypos = 0;

void pngDraw(PNGDRAW *pDraw) {
  uint16_t lineBuffer[MAX_IMAGE_WIDTH];
  png.getLineAsRGB565(pDraw, lineBuffer, PNG_RGB565_BIG_ENDIAN, 0xffffffff);
  tft.pushImage(xpos, ypos + pDraw->y, pDraw->iWidth, 1, lineBuffer);
}

void drawQR()
{
  int16_t rc = png.openFLASH((uint8_t *)qr, sizeof(qr), pngDraw);
  if (rc == PNG_SUCCESS) {
    Serial.println("Successfully opened QR file");

    int pngWidth = png.getWidth();
    int pngHeight = png.getHeight();
        
    // Border thickness
    int borderWidth = 3;

    // Calculate center position
    xpos = (ILI_SCREEN_WIDTH - pngWidth - 2 * borderWidth) / 2 + borderWidth;
    ypos = (ILI_SCREEN_HIEGHT - pngHeight - 2 * borderWidth) / 2 + borderWidth;

    tft.fillRect(xpos - borderWidth, ypos - borderWidth, 
                pngWidth + (2 * borderWidth), pngHeight + (2 * borderWidth), 
                TFT_BLACK);
    tft.startWrite();
    uint32_t dt = millis();
    rc = png.decode(NULL, 0);
    tft.endWrite();
    // png.close(); // not needed for memory->memory decode
  }
  else {
    Serial.println("couldn't open QR file");
  }
}