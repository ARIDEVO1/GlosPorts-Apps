"""Generate 64x64 launcher icons for calc and notes."""
import pathlib
from PIL import Image, ImageDraw

out_dir = pathlib.Path(__file__).resolve().parent / ".local/share/icons"
out_dir.mkdir(parents=True, exist_ok=True)

def base():
    img = Image.new("RGBA", (64, 64), (15, 18, 26, 255))
    return img, ImageDraw.Draw(img)

img, d = base()                                     # calculator: display + keypad
d.rounded_rectangle((8, 8, 56, 20), radius=3, fill=(89, 217, 140, 255))
for r in range(3):
    for c in range(3):
        d.rectangle((10 + c * 17, 26 + r * 12, 20 + c * 17, 34 + r * 12), fill=(90, 98, 120, 255))
img.save(out_dir / "calc.png")

img, d = base()                                     # notebook: page with lines
d.rounded_rectangle((12, 6, 52, 58), radius=4, fill=(235, 230, 215, 255))
for y in (18, 27, 36, 45):
    d.line((18, y, 46, y), fill=(120, 120, 140, 255), width=2)
img.save(out_dir / "notes.png")
print("wrote icons to", out_dir)
