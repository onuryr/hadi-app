"""Aggressive checker-strip + alpha erosion to kill fringe pixels."""
from pathlib import Path
from PIL import Image, ImageFilter

HERE = Path(__file__).parent
src = Image.open(HERE / "wordmark.png").convert("RGBA")
w, h = src.size
px = src.load()

# Pass 1: drop ANY light-low-saturation pixel — wider net
for y in range(h):
    for x in range(w):
        r, g, b, a = px[x, y]
        if a == 0:
            continue
        sat = max(r, g, b) - min(r, g, b)
        # Bg pixels: low saturation OR very light overall
        is_bg = (sat < 35 and max(r, g, b) >= 160) or (r > 220 and g > 220 and b > 220)
        if is_bg:
            px[x, y] = (0, 0, 0, 0)

# Pass 2: erode soft alpha (<200) — kills anti-aliased halo
alpha = src.split()[3]
# Threshold: any pixel below alpha 100 -> 0
hard_alpha = alpha.point(lambda v: 255 if v >= 110 else 0)
src.putalpha(hard_alpha)

# Pass 3: optional smooth — slight blur on alpha for clean edges
smoothed_alpha = src.split()[3].filter(ImageFilter.GaussianBlur(radius=0.5))
src.putalpha(smoothed_alpha)

# Crop
bbox = src.getbbox()
trimmed = src.crop(bbox)
trimmed.save(HERE / "wordmark_clean.png", "PNG")
print(f"Cleaned -> wordmark_clean.png (size {trimmed.size})")
