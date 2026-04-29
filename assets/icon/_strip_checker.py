"""Remove the baked-in checkerboard background from the icon PNG.
The user's source has the photo-editor checker pattern (alternating
~#CCCCCC / #FFFFFF squares) as actual pixels. We threshold those
out and re-emit with proper alpha."""
from pathlib import Path
from PIL import Image

HERE = Path(__file__).parent
src = Image.open(HERE / "app_icon_transparent.png").convert("RGBA")
w, h = src.size
px = src.load()

# Heuristic: a pixel is "background checker" if it's:
#   - mostly grey (R≈G≈B within 15)
#   - in the 175-255 brightness range (light grey or white)
# and NOT inside an icon shape (we keep the saturated purple/orange).
def is_checker(r, g, b, a):
    if a == 0:
        return True
    # If it has color (saturation), it's part of the icon — keep
    max_c = max(r, g, b)
    min_c = min(r, g, b)
    saturation = max_c - min_c
    if saturation > 25:
        return False
    # Greyscale pixel — checker if light (>175)
    return max_c >= 175

for y in range(h):
    for x in range(w):
        r, g, b, a = px[x, y]
        if is_checker(r, g, b, a):
            px[x, y] = (0, 0, 0, 0)

src.save(HERE / "app_icon_clean.png", "PNG")
print(f"Cleaned -> app_icon_clean.png (size {src.size})")
