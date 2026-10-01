#!/usr/bin/env python3
"""Renders assets/images/logo.png: the DON'T LOOK BACK wordmark. The two O's of LOOK are eyes,
the second one glancing over its shoulder. Requires Pillow + the bundled Gloock font."""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
FONT = os.path.join(ROOT, "assets", "fonts", "Gloock-Regular.ttf")
OUT = os.path.join(ROOT, "assets", "images", "logo.png")
W, H = 2700, 900
BONE = (238, 230, 224); CRIMSON = (214, 34, 58); INK = (10, 6, 16)

def tracked(draw_fn, font, text, x, y, track):
    """draw text char by char with tracking; returns list of (char, x, width)"""
    out = []
    for ch in text:
        w = font.getlength(ch)
        out.append((ch, x, w)); draw_fn(ch, x, y); x += w + track
    return out, x

def main():
    big = ImageFont.truetype(FONT, 330)
    small = ImageFont.truetype(FONT, 118)
    mask = Image.new("L", (W, H), 0)     # letter mask (for gradient fill + glow)
    md = ImageDraw.Draw(mask)
    eyes = []                            # eye boxes to paint on top
    # line 1: DON'T (wide tracking, crimson)
    line1 = Image.new("L", (W, H), 0); l1 = ImageDraw.Draw(line1)
    _, x1 = tracked(lambda c, x, y: l1.text((x, y), c, font=small, fill=255), small, "DON'T", 0, 0, 46)
    l1w = int(x1 - 46)
    # line 2: LOOK BACK
    y2 = 170
    text = "LOOK BACK"; track = 34; x = 0; pos = []
    for ch in text:
        w = big.getlength(ch); pos.append((ch, x, w)); x += w + track
    total = int(x - track); ox = (W - total) // 2
    ob = big.getbbox("O")
    for i, (ch, cx, w) in enumerate(pos):
        if ch == "O":
            ww = min(ob[2] - ob[0], w - 8)
            ex0 = ox + cx + (w - ww) / 2
            eyes.append((ex0, y2 + ob[1], ex0 + ww, y2 + ob[3]))
        elif ch != " ":
            md.text((ox + cx, y2), ch, font=big, fill=255)
    # place line 1 centred above
    line1 = line1.crop((0, 0, l1w + 4, 160)); mask.paste(ImageChops.lighter(mask.crop(((W - l1w) // 2, 20, (W - l1w) // 2 + l1w + 4, 180)), line1), ((W - l1w) // 2, 20))
    text_mask = mask.copy()
    ed = ImageDraw.Draw(text_mask)
    for (a, b, c, d) in eyes: ed.ellipse((a, b, c, d), fill=255)   # rings become part of the glow/gradient mask

    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    glow = Image.new("RGBA", (W, H), CRIMSON + (0,)); glow.putalpha(text_mask.filter(ImageFilter.GaussianBlur(38)).point(lambda v: min(255, int(v * 1.5))))
    img.alpha_composite(glow)
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0)); shadow.putalpha(text_mask.filter(ImageFilter.GaussianBlur(6)).point(lambda v: int(v * 0.85)))
    img.alpha_composite(shadow, (6, 10))
    grad = Image.new("RGBA", (W, H))
    gd = ImageDraw.Draw(grad)
    for yy in range(H):
        t = min(1.0, max(0.0, (yy - 20) / 520))
        col = tuple(int(BONE[i] * (1 - t) + (168, 150, 168)[i] * t) for i in range(3))
        gd.line([(0, yy), (W, yy)], fill=col + (255,))
    body = Image.new("RGBA", (W, H), (0, 0, 0, 0)); body.paste(grad, (0, 0), mask)
    # DON'T in crimson: recolour the top band
    band = Image.new("RGBA", (W, H), CRIMSON + (255,)); topmask = Image.new("L", (W, H), 0); topmask.paste(mask.crop((0, 0, W, 175)), (0, 0))
    body.paste(band, (0, 0), topmask)
    img.alpha_composite(body)
    d = ImageDraw.Draw(img)
    for n, (a, b, c, e) in enumerate(eyes):
        w, h = c - a, e - b; cxm, cym = (a + c) / 2, (b + e) / 2
        d.ellipse((a, b, c, e), fill=BONE + (255,))
        ins = w * 0.17
        d.ellipse((a + ins, b + ins * 1.1, c - ins, e - ins * 1.1), fill=INK + (255,))
        look = -0.135 * w if n == 1 else 0.0          # second eye looks back over its shoulder
        ix = cxm + look; ir = w * 0.175
        for k in range(6, 0, -1):                          # soft iris glow
            d.ellipse((ix - ir - k * 3, cym - ir - k * 3, ix + ir + k * 3, cym + ir + k * 3), fill=CRIMSON + (int(14 * (7 - k)),))
        d.ellipse((ix - ir, cym - ir, ix + ir, cym + ir), fill=(226, 40, 62, 255))
        d.ellipse((ix - ir * 0.32, cym - ir * 0.95, ix + ir * 0.32, cym + ir * 0.95), fill=(6, 2, 8, 255))
        d.ellipse((ix - ir * 0.55, cym - ir * 0.7, ix - ir * 0.25, cym - ir * 0.4), fill=(255, 255, 255, 220))
    # scratch under the wordmark
    bb = img.getbbox()
    sc = ImageDraw.Draw(img)
    yb = bb[3] - 26
    sc.line([(bb[0] + 260, yb), (bb[2] - 330, yb + 6)], fill=CRIMSON + (200,), width=5)
    img = img.crop(img.getbbox()); pad = 40
    out = Image.new("RGBA", (img.width + pad * 2, img.height + pad * 2), (0, 0, 0, 0)); out.alpha_composite(img, (pad, pad))
    out.save(OUT); print("logo ->", OUT, out.size)

main()
