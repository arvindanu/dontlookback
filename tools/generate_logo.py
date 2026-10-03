#!/usr/bin/env python3
"""Renders assets/images/logo.png: the "404: Alive" wordmark. The zero of 404 is an eye that glances
over its shoulder; "Alive" sits underneath in crimson. Requires Pillow + the bundled Gloock font."""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
FONT = os.path.join(ROOT, "assets", "fonts", "Gloock-Regular.ttf")
OUT = os.path.join(ROOT, "assets", "images", "logo.png")
W, H = 2400, 1500
BONE = (238, 230, 224); CRIMSON = (214, 34, 58); INK = (10, 6, 16)

def main():
    big = ImageFont.truetype(FONT, 470)
    small = ImageFont.truetype(FONT, 215)
    # ---- line 1: "404:" in bone, tracked; the 0 becomes an eye
    text1 = "404:"; track1 = 40; x = 0; pos = []
    for ch in text1:
        w = big.getlength(ch); pos.append((ch, x, w)); x += w + track1
    total1 = int(x - track1); ox1 = (W - total1) // 2; y1 = 60
    mask1 = Image.new("L", (W, H), 0); m1 = ImageDraw.Draw(mask1); eyes = []
    zb = big.getbbox("0")
    for ch, cx, w in pos:
        if ch == "0":
            ww = (zb[2] - zb[0]) * 1.06; ex0 = ox1 + cx + (w - ww) / 2
            eyes.append((ex0, y1 + zb[1], ex0 + ww, y1 + zb[3]))
        else:
            m1.text((ox1 + cx, y1), ch, font=big, fill=255)
    # ---- line 2: "Alive" in crimson, tracked, centred under line 1
    text2 = "Alive"; track2 = 54; x = 0; pos2 = []
    for ch in text2:
        w = small.getlength(ch); pos2.append((ch, x, w)); x += w + track2
    total2 = int(x - track2); ox2 = (W - total2) // 2; y2 = 60 + 520
    mask2 = Image.new("L", (W, H), 0); m2 = ImageDraw.Draw(mask2)
    for ch, cx, w in pos2:
        m2.text((ox2 + cx, y2), ch, font=small, fill=255)
    text_mask = ImageChops.lighter(mask1, mask2)
    ed = ImageDraw.Draw(text_mask)
    for (a, b, c, d) in eyes: ed.ellipse((a, b, c, d), fill=255)

    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    glow = Image.new("RGBA", (W, H), CRIMSON + (0,)); glow.putalpha(text_mask.filter(ImageFilter.GaussianBlur(40)).point(lambda v: min(255, int(v * 1.5))))
    img.alpha_composite(glow)
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0)); shadow.putalpha(text_mask.filter(ImageFilter.GaussianBlur(6)).point(lambda v: int(v * 0.85)))
    img.alpha_composite(shadow, (6, 10))
    grad = Image.new("RGBA", (W, H)); gd = ImageDraw.Draw(grad)
    for yy in range(H):
        t = min(1.0, max(0.0, (yy - 60) / 560))
        gd.line([(0, yy), (W, yy)], fill=tuple(int(BONE[i] * (1 - t) + (168, 150, 168)[i] * t) for i in range(3)) + (255,))
    body = Image.new("RGBA", (W, H), (0, 0, 0, 0)); body.paste(grad, (0, 0), mask1)
    img.alpha_composite(body)
    red = Image.new("RGBA", (W, H), (0, 0, 0, 0)); red.paste(Image.new("RGBA", (W, H), CRIMSON + (255,)), (0, 0), mask2)
    img.alpha_composite(red)
    d = ImageDraw.Draw(img)
    for (a, b, c, e) in eyes:
        w, h = c - a, e - b; cxm, cym = (a + c) / 2, (b + e) / 2
        d.ellipse((a, b, c, e), fill=BONE + (255,))
        ins = w * 0.14
        d.ellipse((a + ins, b + ins * 0.9, c - ins, e - ins * 0.9), fill=INK + (255,))
        look = -0.12 * w; ix = cxm + look; ir = w * 0.20          # the eye looks back over its shoulder
        for k in range(6, 0, -1):
            d.ellipse((ix - ir - k * 3, cym - ir - k * 3, ix + ir + k * 3, cym + ir + k * 3), fill=CRIMSON + (int(14 * (7 - k)),))
        d.ellipse((ix - ir, cym - ir, ix + ir, cym + ir), fill=(226, 40, 62, 255))
        d.ellipse((ix - ir * 0.32, cym - ir * 0.95, ix + ir * 0.32, cym + ir * 0.95), fill=(6, 2, 8, 255))
        d.ellipse((ix - ir * 0.55, cym - ir * 0.7, ix - ir * 0.25, cym - ir * 0.4), fill=(255, 255, 255, 220))
    bb = img.getbbox(); yb = bb[3] - 22
    ImageDraw.Draw(img).line([(bb[0] + 330, yb), (bb[2] - 330, yb + 6)], fill=CRIMSON + (200,), width=5)
    img = img.crop(img.getbbox()); pad = 40
    out = Image.new("RGBA", (img.width + pad * 2, img.height + pad * 2), (0, 0, 0, 0)); out.alpha_composite(img, (pad, pad))
    out.save(OUT); print("logo ->", OUT, out.size)

main()
