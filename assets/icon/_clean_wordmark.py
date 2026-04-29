"""Strip the photo-editor checkerboard bg from wordmark.png and trim
transparent borders so it sits flush in the UI."""
from pathlib import Path
from PIL import Image

HERE = Path(__file__).parent
src = Image.open(HERE / "wordmark.png").convert("RGBA")
w, h = src.size
px = src.load()

# Same heuristic as the icon strip
for y in range(h):
    for x in range(w):
        r, g, b, a = px[x, y]
        if a == 0:
            continue
        sat = max(r, g, b) - min(r, g, b)
        if sat > 25:
            continue  # part of the colored gradient, keep
        if max(r, g, b) >= 170:
            px[x, y] = (0, 0, 0, 0)

# Crop to non-transparent bounds (trim the empty side margins)
bbox = src.getbbox()
trimmed = src.crop(bbox)
trimmed.save(HERE / "wordmark_clean.png", "PNG")
print(f"Cleaned -> wordmark_clean.png (size {trimmed.size})")
