"""Compose the wordmark into a square launcher icon."""
from pathlib import Path
from PIL import Image

HERE = Path(__file__).parent
W = 1024
wm = Image.open(HERE / "wordmark_clean.png").convert("RGBA")

# Fit wordmark width to ~88% of canvas (so adaptive 66% mask still leaves
# the wordmark readable when masked)
target_w = int(W * 0.88)
ratio = target_w / wm.size[0]
new_size = (target_w, int(wm.size[1] * ratio))
resized = wm.resize(new_size, Image.LANCZOS)

# 1) Transparent square (in-app + launcher base for transparent bg)
square = Image.new("RGBA", (W, W), (0, 0, 0, 0))
offset = ((W - new_size[0]) // 2, (W - new_size[1]) // 2)
square.alpha_composite(resized, offset)
square.save(HERE / "app_icon_transparent.png", "PNG")

# 2) White-bg version (iOS appiconset wants opaque)
opaque = Image.new("RGBA", (W, W), (255, 255, 255, 255))
opaque.alpha_composite(square)
opaque.convert("RGB").save(HERE / "app_icon.png", "PNG")

# 3) Adaptive foreground — inside 66% safe zone
fg_size = int(W * 0.66)
fg_ratio = fg_size / wm.size[0]
fg_w = fg_size
fg_h = int(wm.size[1] * fg_ratio)
fg_resized = wm.resize((fg_w, fg_h), Image.LANCZOS)
fg_canvas = Image.new("RGBA", (W, W), (0, 0, 0, 0))
fg_off = ((W - fg_w) // 2, (W - fg_h) // 2)
fg_canvas.alpha_composite(fg_resized, fg_off)
fg_canvas.save(HERE / "android_foreground.png", "PNG")

# 4) Monochrome silhouette
alpha = fg_resized.split()[3]
mono = Image.new("RGBA", fg_resized.size, (0, 0, 0, 0))
mono.paste(Image.new("RGBA", fg_resized.size, (0, 0, 0, 255)), mask=alpha)
mono_canvas = Image.new("RGBA", (W, W), (0, 0, 0, 0))
mono_canvas.alpha_composite(mono, fg_off)
mono_out = Path(r"c:/Projects/hadi_app/android/app/src/main/res/drawable/ic_launcher_monochrome.png")
mono_canvas.save(mono_out, "PNG")

print(f"OK: wordmark -> app_icon.png, app_icon_transparent.png, android_foreground.png, monochrome ({fg_w}x{fg_h})")
