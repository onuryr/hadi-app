"""One-shot: render app_icon.svg into the PNGs Flutter needs."""
import io
from pathlib import Path

from PIL import Image
from reportlab.graphics import renderPM
from svglib.svglib import svg2rlg

HERE = Path(__file__).parent
SVG_PATH = HERE / "app_icon.svg"


def render_svg(width: int) -> Image.Image:
    drawing = svg2rlg(str(SVG_PATH))
    scale = width / drawing.width
    drawing.width *= scale
    drawing.height *= scale
    drawing.scale(scale, scale)
    buf = io.BytesIO()
    renderPM.drawToFile(drawing, buf, fmt="PNG")
    buf.seek(0)
    return Image.open(buf).convert("RGBA")


def main():
    # 1) Main icon: white background, 1024×1024
    icon = render_svg(1024)
    bg = Image.new("RGBA", (1024, 1024), (255, 255, 255, 255))
    bg.alpha_composite(icon)
    bg.convert("RGB").save(HERE / "app_icon.png", "PNG")

    # 2) Android adaptive foreground:
    #    1024×1024 transparent, icon scaled to ~66% (safe zone), centered
    fg_size = int(1024 * 0.66)
    fg_icon = render_svg(fg_size)
    fg = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    offset = (1024 - fg_size) // 2
    fg.alpha_composite(fg_icon, (offset, offset))
    fg.save(HERE / "android_foreground.png", "PNG")

    # 3) Transparent full-bleed (in-app use, splash, login)
    render_svg(1024).save(HERE / "app_icon_transparent.png", "PNG")

    print("OK: app_icon.png, android_foreground.png, app_icon_transparent.png")


if __name__ == "__main__":
    main()
