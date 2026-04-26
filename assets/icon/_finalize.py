"""Take the headless-Chrome transparent PNG and produce the launcher variants."""
from pathlib import Path
from PIL import Image

HERE = Path(__file__).parent
src = Image.open(HERE / "app_icon_transparent.png").convert("RGBA")

# 1) Main icon, 1024×1024 white background (general use, iOS, Play Store)
bg = Image.new("RGBA", src.size, (255, 255, 255, 255))
bg.alpha_composite(src)
bg.convert("RGB").save(HERE / "app_icon.png", "PNG")

# 2) Android adaptive foreground: 1024×1024 transparent, icon scaled to ~66% safe zone
fg_size = int(1024 * 0.66)
fg_icon = src.resize((fg_size, fg_size), Image.LANCZOS)
fg = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
offset = (1024 - fg_size) // 2
fg.alpha_composite(fg_icon, (offset, offset))
fg.save(HERE / "android_foreground.png", "PNG")

print("OK: app_icon.png, android_foreground.png, app_icon_transparent.png")
