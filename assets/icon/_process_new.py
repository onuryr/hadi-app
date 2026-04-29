"""Take the new wide PNG, crop to icon bounds, square+pad to 1024,
   then produce all variants Flutter / flutter_launcher_icons needs."""
from pathlib import Path
from PIL import Image, ImageOps

HERE = Path(__file__).parent
src_path = HERE / "app_icon.png"
src = Image.open(src_path).convert("RGBA")

# 1) Crop to non-transparent bounding box
bbox = src.getbbox()
cropped = src.crop(bbox)

# 2) Square it on a 1024x1024 transparent canvas (icon centered, ~92% fill)
canvas_size = 1024
target = int(canvas_size * 0.92)
ratio = target / max(cropped.size)
new_size = (int(cropped.size[0] * ratio), int(cropped.size[1] * ratio))
resized = cropped.resize(new_size, Image.LANCZOS)

square = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
offset = ((canvas_size - new_size[0]) // 2, (canvas_size - new_size[1]) // 2)
square.alpha_composite(resized, offset)
square.save(HERE / "app_icon_transparent.png", "PNG")

# 3) White-bg version (used by flutter_launcher_icons + iOS appiconset)
bg = Image.new("RGBA", (canvas_size, canvas_size), (255, 255, 255, 255))
bg.alpha_composite(square)
bg.convert("RGB").save(HERE / "app_icon.png", "PNG")

# 4) Android adaptive foreground: same square scaled to 66% safe zone,
#    centered on 1024 transparent canvas
fg_size = int(canvas_size * 0.66)
fg_icon = square.resize((fg_size, fg_size), Image.LANCZOS)
fg_canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
fg_offset = (canvas_size - fg_size) // 2
fg_canvas.alpha_composite(fg_icon, (fg_offset, fg_offset))
fg_canvas.save(HERE / "android_foreground.png", "PNG")

# 5) Monochrome silhouette for Android themed icons (color stripped, alpha kept)
mono = Image.new("RGBA", square.size, (0, 0, 0, 0))
alpha = square.split()[3]
black_layer = Image.new("RGBA", square.size, (0, 0, 0, 255))
mono.paste(black_layer, mask=alpha)
mono_fg = mono.resize((fg_size, fg_size), Image.LANCZOS)
mono_canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
mono_canvas.alpha_composite(mono_fg, (fg_offset, fg_offset))

mono_out = Path(r"c:/Projects/hadi_app/android/app/src/main/res/drawable/ic_launcher_monochrome.png")
mono_out.parent.mkdir(parents=True, exist_ok=True)
mono_canvas.save(mono_out, "PNG")

print(f"OK — icon size {square.size}, foreground 66% inset, monochrome at {mono_out}")
