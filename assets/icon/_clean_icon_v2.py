"""Aggressive checker-strip + alpha hardening for app icon."""
from pathlib import Path
from PIL import Image

HERE = Path(__file__).parent
src = Image.open(HERE / "app_icon.png").convert("RGBA")
# Note: app_icon.png currently has white bg from earlier finalize.
# Take from app_icon_transparent.png if exists with the original
# user-supplied icon; otherwise from the unmodified app_icon.png.
src = Image.open(HERE / "app_icon_transparent.png").convert("RGBA")
w, h = src.size
px = src.load()

for y in range(h):
    for x in range(w):
        r, g, b, a = px[x, y]
        if a == 0:
            continue
        sat = max(r, g, b) - min(r, g, b)
        is_bg = (sat < 35 and max(r, g, b) >= 160) or (r > 220 and g > 220 and b > 220)
        if is_bg:
            px[x, y] = (0, 0, 0, 0)

# Hard-threshold alpha to kill the soft fringe
alpha = src.split()[3]
hard_alpha = alpha.point(lambda v: 255 if v >= 110 else 0)
src.putalpha(hard_alpha)

src.save(HERE / "app_icon_clean.png", "PNG")
print(f"Cleaned -> app_icon_clean.png (size {src.size})")
