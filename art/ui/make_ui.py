"""Draws the HUD's textures into ui/*.png, in a hand-painted signwriter style:
a stained wooden plaque, a sheet of paper, painted boards for buttons (cut
corners, no gloss), a hanging price tag, a progress bar in a carved slot, the
round phone buttons, and a set of inked icons (ui/icon/*.png) that replace
the emoji in the HUD. Everything is drawn 4x large and scaled down for clean
edges. Grey parts are tinted in the game, so one image does every colour.

    pip install pillow && python art/ui/make_ui.py
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "ui")
S = 4   # supersampling
INK = (58, 36, 22, 255)
CREAM = (255, 245, 220, 255)


def save(img, name):
    img = img.resize((img.width // S, img.height // S), Image.LANCZOS)
    path = os.path.join(OUT, name + ".png")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print("wrote ui/%s.png %dx%d" % (name, img.width, img.height))


def cut_rect(w, h, c, inset, seed, amp=0.8, steps=6):
    """Points round a rectangle with cut (chamfered) corners and a slightly
    hand-sawn edge: every side is split into a few points nudged in or out."""
    rng = random.Random(seed)
    x0, y0, x1, y1 = inset, inset, w - inset, h - inset
    corners = [(x0 + c, y0), (x1 - c, y0), (x1, y0 + c), (x1, y1 - c), (x1 - c, y1), (x0 + c, y1), (x0, y1 - c),
               (x0, y0 + c)]
    pts = []
    for k in range(len(corners)):
        a = corners[k]
        b = corners[(k + 1) % len(corners)]
        n = steps if k % 2 == 0 else 2   # long sides get more wobble points
        for j in range(n):
            t = j / n
            x = a[0] + (b[0] - a[0]) * t
            y = a[1] + (b[1] - a[1]) * t
            if j > 0:
                # nudge across the edge
                dx, dy = b[0] - a[0], b[1] - a[1]
                ln = math.hypot(dx, dy) or 1.0
                off = rng.uniform(-amp, amp) * S
                x += -dy / ln * off
                y += dx / ln * off
            pts.append((x, y))
    return pts


def shadow(base, pts, offset, blur, alpha):
    sh = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(sh)
    d.polygon([(x + offset[0], y + offset[1]) for x, y in pts], fill=(0, 0, 0, alpha))
    if blur > 0:
        sh = sh.filter(ImageFilter.GaussianBlur(blur))
    return Image.alpha_composite(sh, base)


def mask_from(pts, size):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).polygon(pts, fill=255)
    return m


def grain(size, base, tones, seed, lines=70, wavy=5):
    """A board's worth of wood grain: long streaks in a few close tones."""
    w, h = size
    wood = Image.new("RGBA", (w, h), base + (255,))
    d = ImageDraw.Draw(wood)
    rng = random.Random(seed)
    for _ in range(lines):
        y = rng.uniform(0, h)
        c = rng.choice(tones)
        pts = []
        for k in range(9):
            x = w * k / 8
            pts.append((x, y + math.sin(k * 0.9 + y) * wavy * S * rng.uniform(0.2, 1.0)))
        d.line(pts, fill=c + (255,), width=int(rng.uniform(1, 2.5) * S))
    # a couple of knots
    for _ in range(2):
        kx, ky = rng.uniform(w * 0.2, w * 0.8), rng.uniform(h * 0.25, h * 0.75)
        for r in (7, 5, 3):
            d.ellipse([kx - r * 1.8 * S, ky - r * S, kx + r * 1.8 * S, ky + r * S], outline=tones[0] + (255,), width=S)
    return wood


# =====================================================================================
# Panels and buttons
# =====================================================================================
def wood_sign():
    """The water plaque: a dark stained board with cut corners and two nails."""
    w, h = 160 * S, 96 * S
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    pts = cut_rect(w, h, 12 * S, 5 * S, 1, amp=0.7)
    wood = grain((w, h), (122, 76, 44), [(98, 60, 34), (138, 88, 52), (110, 68, 39)], 3)
    d = ImageDraw.Draw(wood)
    # a bevel: lighter top edge, darker bottom edge, painted on before the mask
    d.line([(0, 9 * S), (w, 9 * S)], fill=(160, 108, 66, 255), width=3 * S)
    d.line([(0, h - 9 * S), (w, h - 9 * S)], fill=(80, 48, 26, 255), width=4 * S)
    img.paste(wood, (0, 0), mask_from(pts, (w, h)))
    d = ImageDraw.Draw(img)
    d.line(pts + [pts[0]], fill=INK, width=3 * S, joint="curve")
    for nx in (17, w // S - 17):
        cx, cy = nx * S, 17 * S
        d.ellipse([cx - 4 * S, cy - 4 * S, cx + 4 * S, cy + 4 * S], fill=(84, 82, 86, 255), outline=INK, width=S)
        d.line([(cx - 2 * S, cy - 2 * S), (cx + 1 * S, cy - 2 * S)], fill=(170, 168, 172, 255), width=S)
    img = shadow(img, pts, (0, 4 * S), 0, 90)   # hard shadow, like a cut-out
    save(img, "wood_sign")


def paper():
    """A sheet of cream paper with a deckled edge and a slightly darker rim
    (no tape: it tiled into a row of strips along wide cards)."""
    w, h = 160 * S, 160 * S
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    rng = random.Random(5)
    pts = cut_rect(w, h, 4 * S, 8 * S, 5, amp=0.7, steps=10)
    sheet = Image.new("RGBA", (w, h), (247, 237, 212, 255))
    d = ImageDraw.Draw(sheet)
    for _ in range(600):   # paper fibres
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        a = rng.uniform(0, math.pi)
        ln = rng.uniform(2, 6) * S
        c = rng.choice([(240, 228, 201), (251, 243, 222), (243, 232, 207)])
        d.line([(x, y), (x + math.cos(a) * ln, y + math.sin(a) * ln)], fill=c + (255,), width=S)
    # darker rim, soft inside
    rim = Image.new("L", (w, h), 0)
    ImageDraw.Draw(rim).polygon(pts, fill=255)
    inner = rim.filter(ImageFilter.GaussianBlur(10 * S))
    tint = Image.new("RGBA", (w, h), (214, 190, 150, 255))
    sheet = Image.composite(sheet, tint, inner.point(lambda v: min(255, int(v * 1.25))))
    img.paste(sheet, (0, 0), mask_from(pts, (w, h)))
    d = ImageDraw.Draw(img)
    d.line(pts + [pts[0]], fill=(122, 88, 56, 255), width=2 * S, joint="curve")
    img = shadow(img, pts, (3 * S, 5 * S), 2 * S, 110)
    save(img, "paper")


def button(pressed):
    """A painted board (tinted in game): cut corners, faint brush streaks, a
    thick dark edge underneath instead of a glossy lip, an ink outline."""
    w, h = 96 * S, 72 * S
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    depth = 2 * S if pressed else 6 * S
    top = (4 if not pressed else 8) * S
    body = cut_rect(w, h - 10 * S, 10 * S, 3 * S, 11, amp=0.5)
    body = [(x, y + top - 3 * S) for x, y in body]
    under = [(x, y + depth) for x, y in body]
    d = ImageDraw.Draw(img)
    d.polygon(under, fill=(96, 96, 96, 255))
    d.line(under + [under[0]], fill=INK, width=3 * S, joint="curve")
    paint = Image.new("RGBA", (w, h), (214, 214, 214, 255))
    pd = ImageDraw.Draw(paint)
    rng = random.Random(21)
    for _ in range(26):   # brush strokes, left to right
        y = rng.uniform(0, h)
        c = rng.choice([(208, 208, 208), (220, 220, 220), (211, 211, 211)])
        pd.line([(rng.uniform(-20, 10) * S, y), (w + rng.uniform(-10, 20) * S, y + rng.uniform(-3, 3) * S)],
                fill=c + (255,), width=int(rng.uniform(1.5, 4) * S))
    img.paste(paint, (0, 0), mask_from(body, (w, h)))
    d = ImageDraw.Draw(img)
    ys = min(p[1] for p in body)
    # a thin painted highlight just under the top edge (not a gloss band)
    d.line([(14 * S, ys + 5 * S), (w - 14 * S, ys + 5 * S)], fill=(236, 236, 236, 255), width=2 * S)
    d.line(body + [body[0]], fill=INK, width=3 * S, joint="curve")
    save(img, "button_down" if pressed else "button")


def tag():
    """A hanging price tag (tinted in game): pointed left end with a string
    hole, cut corners on the right, ink outline."""
    w, h = 112 * S, 64 * S
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    i = 4 * S
    pts = [(i, h * 0.5), (26 * S, i), (w - i - 8 * S, i), (w - i, i + 8 * S), (w - i, h - i - 8 * S - 4 * S),
           (w - i - 8 * S, h - i - 4 * S), (26 * S, h - i - 4 * S)]
    under = [(x, y + 4 * S) for x, y in pts]
    d = ImageDraw.Draw(img)
    d.polygon(under, fill=(92, 92, 92, 255))
    d.line(under + [under[0]], fill=INK, width=3 * S, joint="curve")
    d.polygon(pts, fill=(216, 216, 216, 255))
    d.line([(28 * S, i + 5 * S), (w - i - 10 * S, i + 5 * S)], fill=(236, 236, 236, 255), width=2 * S)
    d.line(pts + [pts[0]], fill=INK, width=3 * S, joint="curve")
    # the string hole, with a brass eyelet
    cx, cy = 17 * S, h * 0.5 - 2 * S
    d.ellipse([cx - 6 * S, cy - 6 * S, cx + 6 * S, cy + 6 * S], fill=(196, 152, 70, 255), outline=INK, width=S * 2)
    d.ellipse([cx - 3 * S, cy - 3 * S, cx + 3 * S, cy + 3 * S], fill=(40, 26, 16, 255))
    save(img, "tag")


def bar():
    """Frame: a carved slot with cut corners. Fill: a grey (tinted) bar with
    hand-hatched diagonal strokes, drawn so it tiles side to side."""
    w, h = 64 * S, 32 * S
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    pts = cut_rect(w, h, 6 * S, 2 * S, 31, amp=0.3, steps=3)
    d = ImageDraw.Draw(img)
    d.polygon(pts, fill=(48, 32, 22, 235))
    d.line([(8 * S, 7 * S), (w - 8 * S, 7 * S)], fill=(0, 0, 0, 90), width=3 * S)
    d.line(pts + [pts[0]], fill=INK, width=3 * S, joint="curve")
    save(img, "bar_frame")
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).polygon(cut_rect(w, h, 5 * S, 0, 32, amp=0.0, steps=1), fill=255)
    fill = Image.new("RGBA", (w, h), (222, 222, 222, 255))
    d = ImageDraw.Draw(fill)
    for k in range(-2, 6):   # 16 px period: four strokes across the 64 px tile
        x = k * 16 * S
        d.line([(x, h), (x + h, 0)], fill=(196, 196, 196, 255), width=4 * S)
    d.rectangle([0, h - 7 * S, w, h], fill=(176, 176, 176, 255))
    d.line([(0, 5 * S), (w, 5 * S)], fill=(246, 246, 246, 255), width=2 * S)
    img.paste(fill, (0, 0), m)
    save(img, "bar_fill")


def disc():
    """The round phone buttons: a painted wooden token (tinted in game) with a
    carved inner ring and a thick edge underneath. No gloss."""
    n = 256 * S
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = n // 2
    r = 112 * S
    depth = 9 * S
    d.ellipse([c - r, c - r + depth, c + r, c + r + depth], fill=(92, 92, 92, 255), outline=INK, width=5 * S)
    face = Image.new("RGBA", (n, n), (212, 212, 212, 255))
    fd = ImageDraw.Draw(face)
    rng = random.Random(41)
    for _ in range(40):   # brush strokes
        y = rng.uniform(0, n)
        col = rng.choice([(202, 202, 202), (222, 222, 222), (207, 207, 207)])
        fd.line([(0, y), (n, y + rng.uniform(-6, 6) * S)], fill=col + (255,), width=int(rng.uniform(2, 6) * S))
    m = Image.new("L", (n, n), 0)
    ImageDraw.Draw(m).ellipse([c - r, c - r, c + r, c + r], fill=255)
    img.paste(face, (0, 0), m)
    d = ImageDraw.Draw(img)
    # carved ring: dark groove with a light lip under it
    ri = r - 16 * S
    d.ellipse([c - ri, c - ri + 2 * S, c + ri, c + ri + 2 * S], outline=(240, 240, 240, 255), width=3 * S)
    d.ellipse([c - ri, c - ri, c + ri, c + ri], outline=(150, 150, 150, 255), width=3 * S)
    d.ellipse([c - r, c - r, c + r, c + r], outline=INK, width=5 * S)
    save(img, "disc")
    # The joystick: a stitched leather ring, see-through in the middle.
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([c - r, c - r, c + r, c + r], fill=(30, 20, 12, 70), outline=INK, width=5 * S)
    d.ellipse([c - r + 5 * S, c - r + 5 * S, c + r - 5 * S, c + r - 5 * S], outline=(128, 84, 50, 220), width=16 * S)
    d.ellipse([c - r + 21 * S, c - r + 21 * S, c + r - 21 * S, c + r - 21 * S], outline=INK, width=4 * S)
    rs = r - 13 * S
    for k in range(36):   # stitches
        a0 = k * math.tau / 36
        a1 = a0 + math.tau / 36 * 0.5
        d.arc([c - rs, c - rs, c + rs, c + rs], math.degrees(a0), math.degrees(a1), fill=(245, 230, 200, 230), width=3 * S)
    for k in range(4):   # arrow notches
        a = k * math.pi / 2
        tip = (c + math.cos(a) * (r - 34 * S), c + math.sin(a) * (r - 34 * S))
        b1 = (c + math.cos(a + 0.13) * (r - 50 * S), c + math.sin(a + 0.13) * (r - 50 * S))
        b2 = (c + math.cos(a - 0.13) * (r - 50 * S), c + math.sin(a - 0.13) * (r - 50 * S))
        d.polygon([tip, b1, b2], fill=(245, 230, 200, 200), outline=INK)
    save(img, "stick_ring")


def rule():
    """A hand-inked divider for popups and the catalogue: a wavy line with a
    diamond in the middle. 512 x 32."""
    w, h = 512 * S, 32 * S
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cy = h * 0.5
    for side in (-1, 1):
        pts = []
        for k in range(61):
            t = k / 60
            x = w * 0.5 + side * (24 * S + t * (w * 0.5 - 40 * S))
            pts.append((x, cy + math.sin(t * 18) * 2.2 * S * (1 - t * 0.6)))
        d.line(pts, fill=(122, 82, 50, 255), width=3 * S, joint="curve")
        ex = w * 0.5 + side * (w * 0.5 - 30 * S)
        d.ellipse([ex - 4 * S, cy - 4 * S, ex + 4 * S, cy + 4 * S], fill=(122, 82, 50, 255))
    dm = [(w * 0.5, cy - 11 * S), (w * 0.5 + 11 * S, cy), (w * 0.5, cy + 11 * S), (w * 0.5 - 11 * S, cy)]
    d.polygon(dm, fill=(190, 70, 46, 255), outline=INK)
    d.line(dm + [dm[0]], fill=INK, width=2 * S)
    save(img, "rule")


# =====================================================================================
# Icons: 96 x 96, flat colour, thick ink outline
# =====================================================================================
N = 96 * S
OW = 5 * S   # outline width


def canvas():
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def P(*xy):
    """Points given on a 96-grid."""
    return [(x * S, y * S) for x, y in xy]


def ink_poly(d, pts, fill):
    d.polygon(pts, fill=fill)
    d.line(pts + [pts[0]], fill=INK, width=OW, joint="curve")


def ink_ellipse(d, box, fill, width=OW):
    d.ellipse([v * S for v in box], fill=fill, outline=INK, width=width)


def stroke(d, pts, color, w):
    """A thick coloured line with an ink border."""
    d.line(pts, fill=INK, width=int(w + 2 * OW * 0.8), joint="curve")
    for p in (pts[0], pts[-1]):
        r = (w + 2 * OW * 0.8) / 2
        d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=INK)
    d.line(pts, fill=color, width=int(w), joint="curve")
    for p in (pts[0], pts[-1]):
        r = w / 2
        d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=color)


def arc_pts(cx, cy, r, a0, a1, n=24, ry=None):
    ry = r if ry is None else ry
    return [((cx + math.cos(math.radians(a0 + (a1 - a0) * k / n)) * r) * S,
             (cy + math.sin(math.radians(a0 + (a1 - a0) * k / n)) * ry) * S) for k in range(n + 1)]


def drop_pts(cx, cy, r, tip):
    return arc_pts(cx, cy, r, -30, 210, 30) + [(cx * S, (cy - tip) * S)]


def icon_drop():
    img, d = canvas()
    ink_poly(d, drop_pts(48, 58, 27, 50), (84, 168, 228, 255))
    d.line(arc_pts(48, 58, 17, 120, 175, 10), fill=(220, 242, 255, 255), width=5 * S)
    save(img, "icon/drop")


def icon_flame():
    img, d = canvas()
    outer = P((48, 6), (60, 24), (74, 34), (80, 54), (76, 72), (64, 86), (48, 90), (32, 86), (20, 72), (16, 54),
              (24, 38), (32, 46), (34, 28), (42, 20))
    ink_poly(d, outer, (240, 112, 38, 255))
    inner = P((50, 40), (60, 56), (62, 70), (56, 82), (48, 84), (39, 81), (34, 70), (37, 58), (44, 62))
    d.polygon(inner, fill=(255, 210, 74, 255))
    save(img, "icon/flame")


def icon_book():
    img, d = canvas()
    ink_poly(d, P((6, 30), (48, 36), (90, 30), (90, 82), (48, 88), (6, 82)), (176, 58, 42, 255))   # cover
    ink_poly(d, P((12, 20), (46, 26), (46, 78), (12, 72)), (250, 240, 214, 255))
    ink_poly(d, P((50, 26), (84, 20), (84, 72), (50, 78)), (250, 240, 214, 255))
    for k in range(4):
        y = 36 + k * 9
        d.line(P((18, y), (40, y + 3)), fill=(150, 120, 90, 255), width=2 * S)
        d.line(P((56, y + 3), (78, y)), fill=(150, 120, 90, 255), width=2 * S)
    save(img, "icon/book")


def icon_house():
    img, d = canvas()
    ink_poly(d, P((18, 46), (78, 46), (78, 88), (18, 88)), (246, 232, 200, 255))
    ink_poly(d, P((48, 8), (90, 50), (78, 54), (48, 26), (18, 54), (6, 50)), (196, 64, 44, 255))
    ink_poly(d, P((40, 62), (56, 62), (56, 88), (40, 88)), (120, 76, 44, 255))
    ink_poly(d, P((64, 14), (74, 14), (74, 32), (64, 24)), (150, 110, 80, 255))   # chimney
    save(img, "icon/house")


def icon_jump():
    img, d = canvas()
    for y0 in (14, 44):
        ink_poly(d, P((48, y0), (84, y0 + 32), (68, y0 + 40), (48, y0 + 22), (28, y0 + 40), (12, y0 + 32)), CREAM)
    save(img, "icon/jump")


def icon_lock():
    img, d = canvas()
    d.line(arc_pts(48, 40, 20, 180, 360, 20), fill=INK, width=14 * S)
    d.line(arc_pts(48, 40, 20, 180, 360, 20), fill=(170, 170, 176, 255), width=6 * S)
    d.line(P((28, 40), (28, 48)), fill=INK, width=14 * S)
    d.line(P((68, 40), (68, 48)), fill=INK, width=14 * S)
    d.line(P((28, 40), (28, 48)), fill=(170, 170, 176, 255), width=6 * S)
    d.line(P((68, 40), (68, 48)), fill=(170, 170, 176, 255), width=6 * S)
    ink_poly(d, P((16, 46), (80, 46), (80, 88), (16, 88)), (226, 176, 60, 255))
    ink_ellipse(d, (42, 58, 54, 70), INK, 1)
    d.line(P((48, 66), (48, 78)), fill=INK, width=5 * S)
    save(img, "icon/lock")


def icon_check():
    img, d = canvas()
    stroke(d, P((16, 52), (38, 74), (82, 22)), (92, 176, 84, 255), 12 * S)
    save(img, "icon/check")


def _tv(d, screen=(110, 190, 230, 255)):
    d.line(P((36, 8), (48, 24), (62, 6)), fill=INK, width=4 * S)
    ink_poly(d, P((8, 24), (88, 24), (88, 82), (8, 82)), (150, 96, 56, 255))
    ink_poly(d, P((16, 32), (70, 32), (70, 74), (16, 74)), screen)
    ink_ellipse(d, (74, 36, 84, 46), (220, 200, 160, 255), 2 * S)
    ink_ellipse(d, (74, 54, 84, 64), (220, 200, 160, 255), 2 * S)
    d.line(P((20, 82), (16, 90)), fill=INK, width=5 * S)
    d.line(P((76, 82), (80, 90)), fill=INK, width=5 * S)


def icon_tv():
    img, d = canvas()
    _tv(d)
    ink_poly(d, P((36, 42), (54, 53), (36, 64)), CREAM)
    save(img, "icon/tv")


def icon_noads():
    img, d = canvas()
    _tv(d, (150, 180, 196, 255))
    d.ellipse([10 * S, 10 * S, 86 * S, 86 * S], outline=INK, width=15 * S)
    d.ellipse([10 * S + 4 * S, 14 * S, 82 * S, 82 * S], outline=(210, 50, 40, 255), width=7 * S)
    stroke(d, P((24, 24), (72, 72)), (210, 50, 40, 255), 7 * S)
    save(img, "icon/noads")


def icon_dryer():
    img, d = canvas()
    gold = (240, 190, 60, 255)
    ink_poly(d, P((44, 54), (58, 54), (64, 90), (46, 90)), (214, 160, 44, 255))   # handle
    ink_poly(d, P((10, 22), (60, 22), (60, 58), (10, 58)), gold)
    ink_ellipse(d, (44, 16, 88, 64), gold)
    ink_ellipse(d, (56, 28, 76, 52), (150, 100, 30, 255), 3 * S)
    d.line(P((16, 30), (40, 30)), fill=(255, 240, 180, 255), width=4 * S)
    for sx, sy, r in ((14, 76, 8), (30, 8, 6)):
        ink_poly(d, P((sx, sy - r), (sx + r * 0.3, sy - r * 0.3), (sx + r, sy), (sx + r * 0.3, sy + r * 0.3), (sx, sy + r),
                      (sx - r * 0.3, sy + r * 0.3), (sx - r, sy), (sx - r * 0.3, sy - r * 0.3)), (255, 236, 140, 255))
    save(img, "icon/dryer")


def icon_restore():
    img, d = canvas()
    col = (92, 150, 210, 255)
    for a0 in (200, 20):
        pts = arc_pts(48, 48, 30, a0, a0 + 130, 20)
        stroke(d, pts, col, 10 * S)
        end = pts[-1]
        a = math.radians(a0 + 130)
        tx, ty = -math.sin(a), math.cos(a)   # tangent
        nx, ny = math.cos(a), math.sin(a)
        L = 14 * S
        tri = [(end[0] + tx * L, end[1] + ty * L), (end[0] + nx * L * 0.8, end[1] + ny * L * 0.8),
               (end[0] - nx * L * 0.8, end[1] - ny * L * 0.8)]
        ink_poly(d, tri, col)
    save(img, "icon/restore")


def icon_shield():
    img, d = canvas()
    ink_poly(d, P((48, 6), (84, 18), (82, 50), (70, 72), (48, 90), (26, 72), (14, 50), (12, 18)), (84, 132, 196, 255))
    ink_poly(d, P((48, 18), (72, 26), (70, 50), (48, 76)), (130, 176, 228, 255))
    save(img, "icon/shield")


def icon_page():
    img, d = canvas()
    ink_poly(d, P((18, 8), (62, 8), (80, 26), (80, 90), (18, 90)), (250, 242, 220, 255))
    ink_poly(d, P((62, 8), (80, 26), (62, 26)), (220, 204, 170, 255))
    for k in range(5):
        y = 38 + k * 10
        d.line(P((28, y), (70 - (k % 2) * 10, y)), fill=(150, 120, 90, 255), width=3 * S)
    save(img, "icon/page")


def icon_note():
    img, d = canvas()
    col = (120, 80, 170, 255)
    ink_poly(d, P((38, 16), (80, 8), (80, 22), (38, 30)), col)
    d.line(P((38, 22), (38, 72)), fill=INK, width=11 * S)
    d.line(P((80, 14), (80, 64)), fill=INK, width=11 * S)
    d.line(P((38, 22), (38, 72)), fill=col, width=4 * S)
    d.line(P((80, 14), (80, 64)), fill=col, width=4 * S)
    ink_ellipse(d, (14, 62, 42, 84), col)
    ink_ellipse(d, (56, 54, 84, 76), col)
    save(img, "icon/note")


def icon_bell():
    img, d = canvas()
    ink_ellipse(d, (40, 78, 56, 92), (200, 140, 40, 255))
    ink_poly(d, P((48, 10), (60, 16), (68, 36), (70, 58), (84, 76), (12, 76), (26, 58), (28, 36), (36, 16)),
             (240, 190, 60, 255))
    d.line(P((36, 32), (34, 56)), fill=(255, 238, 170, 255), width=4 * S)
    save(img, "icon/bell")


def _speaker(d):
    ink_poly(d, P((8, 36), (26, 36), (48, 16), (48, 80), (26, 60), (8, 60)), (226, 214, 190, 255))


def icon_mute():
    img, d = canvas()
    _speaker(d)
    stroke(d, P((60, 34), (84, 62)), (210, 60, 44, 255), 7 * S)
    stroke(d, P((84, 34), (60, 62)), (210, 60, 44, 255), 7 * S)
    save(img, "icon/mute")


def icon_speaker():
    img, d = canvas()
    _speaker(d)
    for r in (14, 26):
        d.line(arc_pts(50, 48, r, -45, 45, 12), fill=INK, width=9 * S)
        d.line(arc_pts(50, 48, r, -45, 45, 12), fill=(226, 214, 190, 255), width=3 * S)
    save(img, "icon/speaker")


def icon_penguin():
    img, d = canvas()
    ink_ellipse(d, (20, 14, 76, 90), (40, 44, 58, 255))
    ink_ellipse(d, (30, 34, 66, 86), (248, 244, 232, 255), 3 * S)
    ink_ellipse(d, (36, 26, 44, 34), (255, 255, 255, 255), 2 * S)
    ink_ellipse(d, (52, 26, 60, 34), (255, 255, 255, 255), 2 * S)
    ink_poly(d, P((42, 36), (54, 36), (48, 46)), (246, 150, 40, 255))
    ink_poly(d, P((30, 88), (44, 88), (40, 94), (26, 94)), (246, 150, 40, 255))
    ink_poly(d, P((52, 88), (66, 88), (70, 94), (56, 94)), (246, 150, 40, 255))
    save(img, "icon/penguin")


def icon_clock():
    img, d = canvas()
    ink_poly(d, P((40, 4), (56, 4), (56, 14), (40, 14)), (200, 160, 70, 255))
    ink_ellipse(d, (12, 14, 84, 86), (250, 242, 220, 255))
    d.line(P((48, 50), (48, 28)), fill=INK, width=5 * S)
    d.line(P((48, 50), (64, 58)), fill=(200, 60, 44, 255), width=5 * S)
    ink_ellipse(d, (44, 46, 52, 54), INK, 1)
    save(img, "icon/clock")


def icon_cube():
    img, d = canvas()
    ink_poly(d, P((48, 8), (86, 26), (48, 44), (10, 26)), (222, 244, 255, 255))
    ink_poly(d, P((10, 26), (48, 44), (48, 90), (10, 70)), (150, 206, 238, 255))
    ink_poly(d, P((48, 44), (86, 26), (86, 70), (48, 90)), (110, 176, 222, 255))
    d.line(P((20, 40), (20, 56)), fill=(240, 252, 255, 255), width=4 * S)
    save(img, "icon/cube")


def icon_vase():
    img, d = canvas()
    ink_poly(d, P((36, 8), (60, 8), (58, 18), (70, 30), (76, 52), (68, 76), (58, 90), (38, 90), (28, 76), (20, 52),
                  (26, 30), (38, 18)), (212, 120, 62, 255))
    d.line(P((24, 46), (72, 46)), fill=INK, width=4 * S)
    d.line(P((26, 60), (70, 60)), fill=INK, width=4 * S)
    for x in (34, 46, 58):
        ink_ellipse(d, (x - 3, 50, x + 3, 56), (250, 230, 190, 255), 2 * S)
    save(img, "icon/vase")


def icon_map():
    img, d = canvas()
    cols = [(232, 214, 168, 255), (214, 194, 146, 255), (232, 214, 168, 255)]
    xs = [8, 34, 62, 88]
    for k in range(3):
        y0 = 14 if k % 2 == 0 else 22
        y1 = 22 if k % 2 == 0 else 14
        ink_poly(d, P((xs[k], y0), (xs[k + 1], y1), (xs[k + 1], y1 + 60), (xs[k], y0 + 60)), cols[k])
    d.line(P((18, 60), (30, 44), (48, 54), (66, 36)), fill=(190, 60, 44, 255), width=4 * S)
    stroke(d, P((70, 30), (80, 40)), (190, 60, 44, 255), 4 * S)
    stroke(d, P((80, 30), (70, 40)), (190, 60, 44, 255), 4 * S)
    save(img, "icon/map")


def icon_sparkle():
    img, d = canvas()
    def star(cx, cy, r, col):
        k = 0.28
        ink_poly(d, P((cx, cy - r), (cx + r * k, cy - r * k), (cx + r, cy), (cx + r * k, cy + r * k), (cx, cy + r),
                      (cx - r * k, cy + r * k), (cx - r, cy), (cx - r * k, cy - r * k)), col)
    star(42, 50, 36, (255, 214, 80, 255))
    star(76, 20, 14, (255, 240, 170, 255))
    save(img, "icon/sparkle")


ICONS = [icon_drop, icon_flame, icon_book, icon_house, icon_jump, icon_lock, icon_check, icon_tv, icon_noads,
         icon_dryer, icon_restore, icon_shield, icon_page, icon_note, icon_bell, icon_mute, icon_speaker,
         icon_penguin, icon_clock, icon_cube, icon_vase, icon_map, icon_sparkle]


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    wood_sign()
    paper()
    button(False)
    button(True)
    tag()
    bar()
    disc()
    rule()
    for f in ICONS:
        f()
