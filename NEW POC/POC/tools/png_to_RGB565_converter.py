from PIL import Image
import struct

input_image = "resized_mascot.png"
output_raw = "resized_mascot.raw"
width, height = 64, 68

img = Image.open(input_image).convert("RGB").resize((width, height))
with open(output_raw, "wb") as f:
    for y in range(height):
        for x in range(width):
            r, g, b = img.getpixel((x, y))
            # Convert to RGB565
            rgb565 = ((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3)
            f.write(struct.pack(">H", rgb565))  # Big endian (ILI9488)
