"""Source of truth: app_icon_clean.png (post checker-strip, transparent bg).
Emits all variants needed by flutter_launcher_icons and in-app usage."""
from pathlib import Path
from PIL import Image

HERE = Path(__file__).parent
src = Image.open(HERE / "app_icon_clean.png").convert("RGBA")

# 1) In-app transparent (login splash, AppBar)
src.save(HERE / "app_icon_transparent.png", "PNG")

# 2) iOS / launcher_icons base — opaque on white
canvas = Image.new("RGBA", src.size, (255, 255, 255, 255))
canvas.alpha_composite(src)
canvas.convert("RGB").save(HERE / "app_icon.png", "PNG")

# 3) Android adaptive foreground — icon at 66% safe zone, transparent bg
W = 1024
fg_size = int(W * 0.66)
fg_icon = src.resize((fg_size, fg_size), Image.LANCZOS)
fg_canvas = Image.new("RGBA", (W, W), (0, 0, 0, 0))
offset = (W - fg_size) // 2
fg_canvas.alpha_composite(fg_icon, (offset, offset))
fg_canvas.save(HERE / "android_foreground.png", "PNG")

# 4) Monochrome silhouette for themed icons
alpha = src.split()[3]
mono = Image.new("RGBA", src.size, (0, 0, 0, 0))
mono.paste(Image.new("RGBA", src.size, (0, 0, 0, 255)), mask=alpha)
mono_fg = mono.resize((fg_size, fg_size), Image.LANCZOS)
mono_canvas = Image.new("RGBA", (W, W), (0, 0, 0, 0))
mono_canvas.alpha_composite(mono_fg, (offset, offset))

mono_out = Path(r"c:/Projects/hadi_app/android/app/src/main/res/drawable/ic_launcher_monochrome.png")
mono_out.parent.mkdir(parents=True, exist_ok=True)
mono_canvas.save(mono_out, "PNG")

print("OK: app_icon.png, app_icon_transparent.png, android_foreground.png, ic_launcher_monochrome.png")
