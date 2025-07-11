#ifndef PNG_HANDLER_H
#define PNG_HANDLER_H

#include <PNGdec.h>
#include "qr_code.h"
#include "displays.h"


namespace png_handler {
  void pngDraw(PNGDRAW *pDraw);
  void drawQR();
}

#endif // PNG_HANDLER_H