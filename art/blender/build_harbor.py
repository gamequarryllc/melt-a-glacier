"""Frozen Harbor's buildings and boats. Writes models/harbor.glb with:

    Lighthouse   the keeper's cottage (on the valley church's 4 x 5 m footprint,
                 origin at its corner) and a striped tower in front of it whose
                 lamp room pokes out of the top of the harbour glacier
    Pots         a stack of lobster pots, crates and a coil of rope for the square
    Trawler      a fishing trawler: wheelhouse aft, a mast and boom with a net
    Skiff        a little open fishing boat with a cuddy cabin

Boats: the bow points to -Z, y = 0 is the waterline and the origin is the middle
of the hull (like the pirate ships, see scripts/pirates.gd HULLS).
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
from kit import *  # noqa: E402,F403
from build_pirates import loft, hull_stations, outline, prism_y, wall  # noqa: E402

INK = (0.12, 0.08, 0.07)
WHITE = (0.96, 0.95, 0.91)
RED = (0.78, 0.16, 0.13)


def m(name, rgb, rough=0.8, metal=0.0, emit=None):
    return mat(name, rgb, rough, metal, emit)


# Must match LIGHTHOUSE / CHURCH in scripts/world.gd.
NAVE_W, NAVE_D, WALL, ROOF = 4.0, 5.0, 3.5, 1.6
TOWER_X, TOWER_Z, TOWER_R, GALLERY = 2.0, 6.0, 1.3, 17.0


def lighthouse():
    o = []
    white = m("lh_white", WHITE, 0.9)
    red = m("lh_red", RED, 0.85)
    dark = m("lh_dark", (0.18, 0.2, 0.24), 0.6, 0.3)
    stone = m("stone", (0.55, 0.54, 0.52), 0.95)
    glass = m("lamp_glass", (1.0, 0.92, 0.6), 0.2, emit=(1.0, 0.85, 0.45))
    wood = m("wood_dark", (0.3, 0.2, 0.13), 0.85)
    slate = m("slate", (0.27, 0.29, 0.34), 0.7)
    yellow = m("cottage_yellow", (0.9, 0.72, 0.32), 0.9)
    # The keeper's cottage: low walls, a steep slate roof, a door and windows.
    o.append(box((NAVE_W / 2, 0.15, NAVE_D / 2), (NAVE_W + 0.1, 0.3, NAVE_D + 0.1), stone, None, 0.03))
    o.append(box((NAVE_W / 2, 0.3 + (WALL - 0.3) / 2, NAVE_D / 2), (NAVE_W - 0.1, WALL - 0.3, NAVE_D - 0.1), yellow, None, 0.03))
    peak = WALL + ROOF
    for s in (-1, 1):
        ang = math.atan2(ROOF, NAVE_W / 2)
        length = math.hypot(ROOF, NAVE_W / 2) + 0.3
        cx = NAVE_W / 2 + s * NAVE_W / 4
        o.append(box((cx, WALL + ROOF / 2, NAVE_D / 2), (length, 0.14, NAVE_D + 0.5), slate, rot_z(-s * ang), 0.02))
    # Gable ends.
    for z in (0.05, NAVE_D - 0.05):
        o.append(extrude([(0.05, WALL), (NAVE_W - 0.05, WALL), (NAVE_W / 2, peak - 0.1)], z - 0.04, z + 0.04, yellow, 0.0))
    for z, nz in ((0.0, -1), (NAVE_D, 1)):
        for x in (1.0, 3.0):
            o.append(box((x, 1.9, z + 0.02 * nz), (0.7, 0.9, 0.06), m("glass", (0.25, 0.32, 0.45), 0.15), None, 0.0))
            o.append(box((x, 1.9, z + 0.03 * nz), (0.84, 1.04, 0.04), white, None, 0.01))
    o.append(box((NAVE_W / 2, 1.0, NAVE_D + 0.04), (0.9, 1.9, 0.06), m("door", (0.2, 0.36, 0.5), 0.7), None, 0.01))
    o.append(box((3.0, peak + 0.2, 1.4), (0.45, 1.2, 0.45), stone, None, 0.02))   # chimney
    # The tower: a tapering cylinder in red and white bands.
    base_r, top_r = TOWER_R, TOWER_R * 0.78
    bands = 6
    o.append(cyl((TOWER_X, 0.0, TOWER_Z), (TOWER_X, 0.6, TOWER_Z), base_r + 0.2, base_r + 0.15, stone, 20))
    for k in range(bands):
        y0 = 0.6 + (GALLERY - 0.6) * k / bands
        y1 = 0.6 + (GALLERY - 0.6) * (k + 1) / bands
        r0 = base_r + (top_r - base_r) * (y0 / GALLERY)
        r1 = base_r + (top_r - base_r) * (y1 / GALLERY)
        o.append(cyl((TOWER_X, y0, TOWER_Z), (TOWER_X, y1, TOWER_Z), r0, r1, red if k % 2 == 0 else white, 20))
    # Little windows up the tower, on the side facing you.
    for k in range(4):
        y = 3.5 + k * 3.2
        r = base_r + (top_r - base_r) * (y / GALLERY)
        o.append(box((TOWER_X, y, TOWER_Z + r - 0.02), (0.28, 0.5, 0.08), dark, None, 0.01))
    o.append(box((TOWER_X, 1.0, TOWER_Z + base_r - 0.02), (0.7, 1.7, 0.12), m("door", (0.2, 0.36, 0.5), 0.7), None, 0.01))
    # The gallery: a round balcony with railings.
    o.append(cyl((TOWER_X, GALLERY, TOWER_Z), (TOWER_X, GALLERY + 0.2, TOWER_Z), top_r + 0.6, top_r + 0.6, dark, 24))
    for k in range(16):
        t = math.tau * k / 16
        x, z = TOWER_X + math.cos(t) * (top_r + 0.5), TOWER_Z + math.sin(t) * (top_r + 0.5)
        o.append(cyl((x, GALLERY + 0.2, z), (x, GALLERY + 0.95, z), 0.03, 0.03, dark, 5))
    o.append(torus((TOWER_X, GALLERY + 0.95, TOWER_Z), top_r + 0.5, 0.04, dark, 24, 5))
    # The lamp room: glass all round, a red cap and a weathervane.
    lr = top_r * 0.8
    o.append(cyl((TOWER_X, GALLERY + 0.2, TOWER_Z), (TOWER_X, GALLERY + 0.5, TOWER_Z), lr, lr, red, 16))
    o.append(cyl((TOWER_X, GALLERY + 0.5, TOWER_Z), (TOWER_X, GALLERY + 1.7, TOWER_Z), lr - 0.05, lr - 0.05, glass, 16, smooth=False))
    for k in range(8):
        t = math.tau * k / 8
        x, z = TOWER_X + math.cos(t) * (lr - 0.02), TOWER_Z + math.sin(t) * (lr - 0.02)
        o.append(cyl((x, GALLERY + 0.5, z), (x, GALLERY + 1.7, z), 0.04, 0.04, dark, 4))
    o.append(lathe(smooth_profile([(0.0, 0.0), (lr + 0.15, 0.0), (lr * 0.7, 0.5), (0.15, 0.95), (0.0, 1.0)], 2), red, 16,
                   center=(TOWER_X, GALLERY + 1.7, TOWER_Z)))
    o.append(sphere((TOWER_X, GALLERY + 2.75, TOWER_Z), (0.12, 0.12, 0.12), dark, 8, 5))
    o.append(cyl((TOWER_X, GALLERY + 2.8, TOWER_Z), (TOWER_X, GALLERY + 3.4, TOWER_Z), 0.025, 0.025, dark, 4))
    o.append(extrude([(-0.05, 0.0), (0.5, 0.08), (0.5, 0.2), (-0.05, 0.15)], -0.015, 0.015, dark, 0.0))
    transform(o[-1], None, (TOWER_X, GALLERY + 3.2, TOWER_Z))
    # A path of planks from the cottage door.
    for k in range(3):
        o.append(box((NAVE_W / 2, 0.04, NAVE_D + 0.5 + k * 0.45), (0.8, 0.06, 0.35), wood, None, 0.01))
    return o


def pots():
    """Lobster pots, a crate of fish and a coil of rope, about 1.4 m across."""
    o = []
    net = m("pot_net", (0.32, 0.5, 0.5), 0.8)
    wood = m("crate_wood", (0.62, 0.44, 0.26), 0.85)
    rope = m("rope", (0.75, 0.62, 0.4), 0.9)
    fish = m("fish_silver", (0.7, 0.75, 0.8), 0.4, 0.3)
    buoy = m("buoy_orange", (0.95, 0.45, 0.15), 0.6)
    for (x, y, z, rot) in ((-0.32, 0.0, -0.2, 0.2), (0.33, 0.0, -0.15, -0.3), (0.0, 0.42, -0.18, 0.5)):
        pot = cyl((0, 0, -0.3), (0, 0, 0.3), 0.21, 0.21, net, 10)
        deform(pot, lambda p: Vector((p.x, max(p.y, 0.0) * 1.0 + min(p.y, 0.0) * 0.0, p.z)))
        transform(pot, rot_y(rot), (x, y + 0.02, z))
        o.append(pot)
        o.append(box((x, y + 0.02, z), (0.44, 0.04, 0.62), wood, rot_y(rot), 0.01))
    o.append(box((0.1, 0.18, 0.42), (0.6, 0.36, 0.4), wood, rot_y(0.1), 0.02))
    rng = random.Random(4)
    for k in range(6):
        x, z = rng.uniform(-0.18, 0.35), rng.uniform(0.3, 0.52)
        o.append(sphere((x, 0.38, z), (0.12, 0.04, 0.04), fish, 8, 4, basis=rot_y(rng.uniform(-0.6, 0.6))))
    o.append(torus((-0.45, 0.06, 0.4), 0.2, 0.05, rope, 16, 6))
    o.append(torus((-0.45, 0.14, 0.4), 0.17, 0.05, rope, 16, 6))
    o.append(sphere((0.55, 0.15, 0.35), (0.15, 0.15, 0.15), buoy, 12, 8))
    return o


def boat(length, beam, deck, cabin, cabin_z, mast_z, mast_h, seed, big):
    rng = random.Random(seed)
    hull_paint = m("boat_hull_red" if big else "boat_hull_blue", RED if big else (0.2, 0.42, 0.66), 0.75)
    bottom = m("boat_bottom", (0.14, 0.15, 0.17), 0.8)
    stripe = m("boat_stripe", WHITE, 0.7)
    plank = m("deck_plank", (0.6, 0.47, 0.32), 0.85)
    cabin_m = m("cabin_white", WHITE, 0.85)
    roof_m = m("cabin_roof_big" if big else "cabin_roof_small", (0.2, 0.36, 0.5) if big else RED, 0.7)
    glass = m("glass", (0.25, 0.32, 0.45), 0.15)
    dark = m("boat_dark", (0.16, 0.16, 0.18), 0.6, 0.3)
    net = m("net_green", (0.3, 0.52, 0.42), 0.9)
    buoy = m("buoy_orange", (0.95, 0.45, 0.15), 0.6)
    tyre = m("tyre", (0.1, 0.1, 0.11), 0.9)
    o = []
    st = hull_stations(length, beam, -1.2 if big else -0.8, deck, transom=0.85, rake=1.0)
    hull = loft(st, hull_paint, "hull", 14)
    paint(hull, lambda p: bottom if p.y < 0.15 else (stripe if p.y > deck - 0.3 else None))
    o.append(hull)
    o.append(prism_y(outline(st, 0.14), deck - 0.05, deck + 0.02, plank, "deck"))
    # Bulwark rail with a white cap.
    edge = outline(st, 0.06)
    o += wall(edge, deck, deck + 0.4, 0.1, hull_paint)
    o += wall(edge, deck + 0.4, deck + 0.46, 0.14, stripe)
    # Wheelhouse / cabin aft.
    half_l = length * 0.5
    cw = beam * 0.62
    cl = half_l - cabin_z - (1.2 if big else 0.6)
    cz = cabin_z + cl / 2
    o.append(box((0, deck + cabin / 2, cz), (cw, cabin, cl), cabin_m, None, 0.04))
    o.append(box((0, deck + cabin + 0.08, cz), (cw + 0.3, 0.16, cl + 0.3), roof_m, None, 0.03))
    for x in (-0.3 * cw, 0.0, 0.3 * cw) if big else (-0.2 * cw, 0.2 * cw):
        o.append(box((x, deck + cabin * 0.68, cabin_z - 0.01), (cw * 0.22, cabin * 0.32, 0.06), glass, None, 0.0))
    for s in (-1, 1):
        o.append(box((s * cw / 2, deck + cabin * 0.68, cz), (0.06, cabin * 0.3, cl * 0.5), glass, None, 0.0))
    # Mast with a boom and a lamp, and a net hanging off the boom.
    o.append(cyl((0, deck, mast_z), (0, deck + mast_h, mast_z), 0.12, 0.08, dark, 8))
    o.append(cyl((0, deck + mast_h * 0.55, mast_z), (0, deck + 1.2, mast_z - (length * 0.3)), 0.06, 0.05, dark, 6))
    o.append(sphere((0, deck + mast_h + 0.1, mast_z), (0.14, 0.14, 0.14), m("mast_lamp", (1.0, 0.85, 0.4), 0.3, emit=(1.0, 0.7, 0.3)), 8, 5))
    if big:
        # A heap of net on deck at the bow and one hanging from the boom.
        o.append(sphere((0.3, deck + 0.25, -half_l * 0.55), (0.9, 0.35, 0.7), net, 12, 6))
        hang = cyl((0, deck + 2.4, mast_z - length * 0.28), (0, deck + 0.5, mast_z - length * 0.28), 0.15, 0.55, net, 10)
        o.append(hang)
        for s in (-1, 1):
            o.append(cyl((s * beam * 0.36, deck, half_l - 1.0), (s * beam * 0.36, deck + 2.6, half_l - 1.0), 0.07, 0.07, dark, 6))
        o.append(cyl((-beam * 0.36, deck + 2.6, half_l - 1.0), (beam * 0.36, deck + 2.6, half_l - 1.0), 0.07, 0.07, dark, 6))
        o.append(cyl((0, deck + cabin + 0.16, cz), (0, deck + cabin + 1.0, cz), 0.06, 0.04, dark, 6))   # aerial
        o.append(box((0, deck + cabin + 0.5, cz + 0.4), (0.9, 0.08, 0.08), dark, None, 0.0))           # radar bar
    else:
        # Lobster pots and an oar.
        for x, z in ((0.5, -1.4), (-0.4, -1.8)):
            o.append(cyl((x, deck + 0.05, z - 0.25), (x, deck + 0.05, z + 0.25), 0.2, 0.2, net, 8))
        o.append(cyl((-0.9, deck + 0.35, -2.2), (0.9, deck + 0.35, 0.2), 0.035, 0.035, plank, 5))
    # Buoys and tyres along the sides.
    for s in (-1, 1):
        for k in range(3 if big else 2):
            z = -half_l * 0.4 + k * (2.6 if big else 1.6)
            w = 0
            for zz, ww, _, _ in st:
                if abs(zz - z) < length / 14:
                    w = ww
            t = torus((0, 0, 0), 0.22, 0.08, tyre, 12, 6)
            transform(t, rot_z(math.pi / 2), (s * (w + 0.05), deck - 0.35, z))
            o.append(t)
        o.append(sphere((s * beam * 0.36, deck + 0.5, -half_l * 0.2), (0.14, 0.2, 0.14), buoy, 10, 6))
    return o


def trawler():
    return boat(15.0, 5.0, 1.8, 2.3, 2.2, -4.2, 7.0, 3, True)


def skiff():
    return boat(8.0, 3.0, 1.0, 1.5, 1.0, -1.6, 4.2, 5, False)


def main():
    reset()
    objs = [join(lighthouse(), "Lighthouse"), join(pots(), "Pots"), join(trawler(), "Trawler"), join(skiff(), "Skiff")]
    export("harbor", objs)


if __name__ == "__main__":
    main()
