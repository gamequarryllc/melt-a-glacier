"""house_0, second pass: built while looking at it through Blender MCP.

Same footprint, colours and door position as build_village.house(0), but with
the things that made the first pass read as "generated": one-slab plinth,
ruler-straight boards, a door canopy stuck into the balcony, a bare roof.

Changes:
  * the stone plinth is laid as separate, slightly uneven stones
  * the wooden upper floor is stacked logs with crossed corners (Blockbau)
  * cut-out balcony boards on two carved brackets; the balcony is the door canopy
  * purlin ends under deep gable eaves, staggered shingles, snow on the roof
    with a soft lip, a few icicles, a stone chimney with a snow cap
  * small fixed-seed jitter on boards and stones so nothing is perfectly straight

    python art/blender/build_house_v2.py        # writes models/house_0.glb
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
from kit import *  # noqa: E402,F403
from kit import _obj  # noqa: E402
from build_village import (HOUSES, WALL, ROOF, PLINTH, STONE, STONE_DARK, WOOD, WOOD_DARK, TRIM,  # noqa: E402
                           window)

SNOW = (0.93, 0.96, 1.0)
SNOW_SHADE = (0.8, 0.86, 0.95)
ICE = (0.75, 0.88, 0.97)
STONES = [(0.62, 0.6, 0.57), (0.55, 0.54, 0.52), (0.68, 0.66, 0.62), (0.5, 0.49, 0.48)]
MORTAR = (0.4, 0.39, 0.38)
WOOD_ALT = (0.55, 0.37, 0.23)


def j(r, amt):
    return r.uniform(-amt, amt)


def plinth(objs, r, hw, hd):
    """Two courses of rough stones round a dark mortar core."""
    objs.append(boxlh((-hw + 0.02, 0, -hd + 0.02), (hw - 0.02, PLINTH, hd - 0.02), mat("mortar", MORTAR, 1.0), 0.0))
    courses = [(0.0, 0.26), (0.26, PLINTH)]
    # Each wall: (start corner, direction along wall, outward normal, length)
    walls = [((-hw, hd), (1, 0), (0, 1), 2 * hw), ((hw, -hd), (-1, 0), (0, -1), 2 * hw),
             ((hw, hd), (0, -1), (1, 0), 2 * hd), ((-hw, -hd), (0, 1), (-1, 0), 2 * hd)]
    for (sx, sz), (ux, uz), (nx, nz), length in walls:
        for ci, (y0, y1) in enumerate(courses):
            t = -0.06 if ci % 2 == 0 else 0.1
            while t < length + 0.06:
                L = r.uniform(0.32, 0.58)
                L = min(L, length + 0.08 - t)
                if L < 0.12:
                    break
                cx = sx + ux * (t + L * 0.5) + nx * 0.0
                cz = sz + uz * (t + L * 0.5) + nz * 0.0
                h = (y1 - y0) - 0.025
                out = 0.06 + j(r, 0.015)
                basis = rot_y(j(r, 0.04)) @ rot_z(j(r, 0.03) if ux else 0.0) @ rot_x(j(r, 0.03) if uz else 0.0)
                size = (L - 0.03, h, 0.2) if ux else (0.2, h, L - 0.03)
                c = (cx + nx * (out - 0.04), y0 + (y1 - y0) * 0.5 + j(r, 0.01), cz + nz * (out - 0.04))
                m = mat("stone%d" % (r.randrange(len(STONES))), r.choice(STONES), 0.95)
                objs.append(box(c, size, m, basis, 0.045, 1))
                t += L


def log_walls(objs, r, hw, hd, y0, y1):
    """Stacked logs with crossed corners: front/back logs run long on even rows, side logs on odd rows."""
    wood = mat("wood", WOOD, 0.85)
    alt = mat("wood_alt", WOOD_ALT, 0.85)
    # A dark core so gaps between logs read as shadow, not plaster.
    objs.append(boxlh((-hw + 0.03, y0, -hd + 0.03), (hw - 0.03, y1, hd - 0.03), mat("wood_dark", WOOD_DARK, 0.85), 0.0))
    n = 7
    lh = (y1 - y0) / n
    for k in range(n):
        y = y0 + lh * (k + 0.5)
        long_fb = k % 2 == 0
        for zz in (hd, -hd):
            ext = 0.16 if long_fb else -0.06
            m = alt if r.random() < 0.3 else wood
            objs.append(box((j(r, 0.02), y, zz + (0.03 if zz > 0 else -0.03)), (2 * hw + 2 * ext, lh - 0.012, 0.13),
                            m, rot_x(j(r, 0.012)), 0.035, 1))
        for xx in (hw, -hw):
            ext = 0.16 if not long_fb else -0.06
            m = alt if r.random() < 0.3 else wood
            objs.append(box((xx + (0.03 if xx > 0 else -0.03), y, j(r, 0.02)), (0.13, lh - 0.012, 2 * hd + 2 * ext),
                            m, rot_z(j(r, 0.012)), 0.035, 1))


def baluster(cx, y0, z, material):
    """One flat cut-out board; neighbours together make the classic chalet pattern."""
    p = [(-0.07, 0.0), (0.07, 0.0), (0.07, 0.12), (0.035, 0.2), (0.035, 0.3), (0.07, 0.38), (0.07, 0.58),
         (-0.07, 0.58), (-0.07, 0.38), (-0.035, 0.3), (-0.035, 0.2), (-0.07, 0.12)]
    return extrude([(cx + x, y0 + y) for x, y in p], z - 0.015, z + 0.015, material, 0.0)


def balcony(objs, r, w, hd, y):
    wood = mat("wood", WOOD, 0.85)
    wood_dark = mat("wood_dark", WOOD_DARK, 0.85)
    hw = w * 0.5
    depth = 0.55
    zf = hd + depth
    # Floor boards and joist ends.
    objs.append(box((0, y - 0.04, hd + depth * 0.5), (w + 0.24, 0.08, depth), wood_dark, None, 0.02))
    for k in range(5):
        x = -hw + w * (k + 0.5) / 5
        objs.append(box((x, y - 0.13, hd + depth * 0.5 - 0.02), (0.1, 0.12, depth + 0.04), wood_dark, None, 0.02))
    # Carved brackets: a quarter-round knee under each end.
    for sx in (-1, 1):
        # Knee brace: flat top and back, concave curve between (arc round the outer-bottom corner).
        e = depth - 0.04
        rad = e - 0.04
        pts = [(0.0, 0.0), (e, 0.0), (e, -0.08)]
        for k in range(1, 8):
            ang = math.pi * 0.5 * (1 + k / 8)
            pts.append((e + rad * math.cos(ang), -0.08 - rad + rad * math.sin(ang)))
        pts.append((0.0, -0.08 - rad))
        # pts are (z offset from wall, y offset from floor underside); axis="x" wants (z, y)
        prof = [(hd + pz, y - 0.17 + py) for pz, py in pts]
        objs.append(extrude(prof, sx * (hw - 0.05) - 0.05, sx * (hw - 0.05) + 0.05, wood_dark, 0.01, axis="x"))
    # Cut-out boards, rails and corner posts.
    n = int(round(w / 0.14))
    for k in range(n):
        x = -hw - 0.05 + (w + 0.1) * (k + 0.5) / n
        objs.append(baluster(x, y, zf - 0.04, wood))
    for sx in (-1, 1):
        for k in range(3):
            zz = hd + 0.1 + (depth - 0.18) * (k + 0.5) / 3
            objs.append(transform(baluster(0, y, 0, wood), rot_y(math.pi / 2), (sx * (hw + 0.07), 0, zz)))
        objs.append(box((sx * (hw + 0.07), y + 0.33, zf - 0.04), (0.09, 0.72, 0.09), wood_dark, None, 0.02))
    objs.append(box((0, y + 0.62, zf - 0.04), (w + 0.26, 0.06, 0.11), wood_dark, None, 0.02))
    for sx in (-1, 1):
        objs.append(box((sx * (hw + 0.07), y + 0.62, hd + depth * 0.5), (0.11, 0.06, depth), wood_dark, None, 0.02))


class Slope:
    """Frame on one roof slope: t runs down the slope from the ridge, h out of it."""

    def __init__(self, s, a, peak):
        self.s = s
        self.basis = rot_z(-s * a)
        self.down = self.basis @ Vector((s, 0, 0))
        self.up = self.basis @ Vector((0, 1, 0))
        self.top = Vector((0, peak, 0))

    def at(self, t, h, z):
        return self.top + self.down * t + self.up * h + Vector((0, 0, z))

    def box(self, t0, t1, h0, h1, z0, z1, material, bevel=0.02, extra=None, segs=2):
        b = self.basis @ extra if extra is not None else self.basis
        return box(self.at((t0 + t1) * 0.5, (h0 + h1) * 0.5, (z0 + z1) * 0.5), (t1 - t0, h1 - h0, z1 - z0),
                   material, b, bevel, segs)


def snow_sheet(sl, r, length, hz, thick, material):
    """One continuous blanket of snow on a slope: a wavy lower edge, rounded edges, gentle lumps."""
    ph = [r.uniform(0, math.tau) for _ in range(4)]
    z0 = -hz + 0.04 + r.uniform(0.0, 0.06)
    z1 = hz - 0.04 - r.uniform(0.0, 0.06)
    nz, nt = 28, 14
    base = thick + 0.03

    def t_end(z):
        return length - 0.38 + 0.08 * math.sin(z * 2.3 + ph[0]) + 0.04 * math.sin(z * 6.1 + ph[1])

    def round_off(x, a):   # 1 in the middle, falls to 0 at the edge like a quarter circle
        if x <= a:
            return 1.0
        k = (x - a) / (1.0 - a)
        return math.sqrt(max(0.0, 1.0 - k * k))

    bm = bmesh.new()
    top, bot = [], []
    for iz in range(nz + 1):
        v = iz / nz
        z = z0 + (z1 - z0) * v
        te = t_end(z)
        rt, rb = [], []
        for it in range(nt + 1):
            u = it / nt
            t = -0.16 + (te + 0.16) * u
            depth = 0.17 + 0.025 * math.sin(z * 3.7 + ph[2]) * math.sin(t * 4.1 + ph[3])
            h = depth * round_off(u, 0.8) * round_off(abs(v - 0.5) * 2, 0.88)
            h = max(h, 0.004)
            # The rounded edge curls a little down past the slab, like snow that has started to slide.
            curl = 0.03 * max(0.0, (u - 0.8) / 0.2) ** 2
            rt.append(bm.verts.new(to_b(sl.at(t + curl * 0.6, base + h - curl, z))))
            rb.append(bm.verts.new(to_b(sl.at(t + curl * 0.6, base - curl, z))))
        top.append(rt)
        bot.append(rb)
    for iz in range(nz):
        for it in range(nt):
            bm.faces.new([top[iz][it], top[iz][it + 1], top[iz + 1][it + 1], top[iz + 1][it]])
            bm.faces.new([bot[iz][it], bot[iz + 1][it], bot[iz + 1][it + 1], bot[iz][it + 1]])
    for iz in range(nz):   # top (ridge) and bottom (eave) rims
        for it in (0, nt):
            bm.faces.new([top[iz][it], top[iz + 1][it], bot[iz + 1][it], bot[iz][it]])
    for iz in (0, nz):      # gable-end rims
        for it in range(nt):
            bm.faces.new([top[iz][it], bot[iz][it], bot[iz][it + 1], top[iz][it + 1]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _obj("snow", bm, material, 0.0, smooth=True)


def roof(objs, r, w, d, peak, roof_col, i):
    rise = peak - WALL
    hw = w * 0.5
    a = math.atan2(rise, hw)
    side_over = 0.38
    gable_over = 0.5
    length = (hw + side_over) / math.cos(a)
    depth = d + 2 * gable_over
    hz = depth * 0.5
    thick = 0.14
    rm = mat("roof%d" % i, roof_col, 0.75)
    rd = mat("roof_dark%d" % i, tuple(c * 0.72 for c in roof_col), 0.75)
    rl = mat("roof_light%d" % i, tuple(min(1, c * 1.12) for c in roof_col), 0.75)
    wood_dark = mat("wood_dark", WOOD_DARK, 0.85)
    snow = mat("snow", SNOW, 0.6)
    ice = mat("ice", ICE, 0.15)
    for s in (-1, 1):
        sl = Slope(s, a, peak)
        # Deck.
        objs.append(sl.box(-0.02, length + 0.02, 0, thick, -hz, hz, wood_dark, 0.02))
        # Purlins: run the length of the house and stick out under the gable eaves with chamfered ends.
        for t in (0.25, length * 0.5, length - 0.32):
            objs.append(sl.box(t - 0.07, t + 0.07, -0.2, 0.0, -hz + 0.06, hz - 0.06, wood_dark, 0.03))
        # Shingles: staggered boards in rows, each a touch proud of the one above.
        rows = 6
        cl = length / rows
        for row in range(rows):
            t0 = cl * row
            z = -hz - 0.02 + (0.0 if row % 2 == 0 else -0.16)
            while z < hz + 0.02:
                bw = r.uniform(0.26, 0.42)
                z1 = min(z + bw, hz + 0.02)
                z0 = max(z, -hz - 0.02)
                if z1 - z0 > 0.06:
                    m = r.choice((rm, rm, rm, rl))
                    tilt = rot_z(s * (0.07 + j(r, 0.02))) @ rot_x(j(r, 0.015))
                    objs.append(sl.box(t0, t0 + cl + 0.07, thick + 0.01 + j(r, 0.006), thick + 0.06,
                                       z0 + 0.008, z1 - 0.008, m, 0.012, tilt))
                z += bw
        # Bargeboards.
        for zz in (-hz - 0.03, hz + 0.03):
            objs.append(sl.box(-0.05, length + 0.03, -0.12, thick + 0.06, zz - 0.035, zz + 0.035, wood_dark, 0.015))
        # Snow: a soft slab over the top of the slope, stopping short of the eave so a row of shingles shows,
        # then a rounded lip hanging a little over the edge where the snow has slid.
        objs.append(snow_sheet(sl, r, length, hz, thick, snow))
        # Icicles along the eave, in clumps with gaps, one long one in each clump.
        z = -hz + r.uniform(0.1, 0.4)
        while z < hz - 0.15:
            clump = r.randint(2, 4)
            longest = r.randrange(clump)
            for c_i in range(clump):
                L = r.uniform(0.25, 0.45) if c_i == longest else r.uniform(0.06, 0.18)
                p = sl.at(length - 0.03, -0.03, z)
                objs.append(cyl(p, p - Vector((j(r, 0.02), L, 0)), 0.022 + L * 0.05, 0.0, ice, 6))
                z += r.uniform(0.07, 0.12)
            z += r.uniform(0.35, 0.9)
    # Ridge cap; the two snow sheets overlap over it.
    objs.append(box((0, peak + thick + 0.05, 0), (0.2, 0.2, depth + 0.04), rd, rot_z(math.pi / 4), 0.02))
    return a, length


def chimney(objs, r, x, z, base, top):
    stone_m = [mat("stone%d" % k, c, 0.95) for k, c in enumerate(STONES)]
    objs.append(box((x, (base + top) * 0.5, z), (0.4, top - base, 0.4), mat("mortar", MORTAR, 1.0), None, 0.0))
    y = base
    k = 0
    while y < top - 0.05:
        h = r.uniform(0.14, 0.2)
        h = min(h, top - y)
        for side in range(4):
            rot = rot_y(side * math.pi / 2 + j(r, 0.03))
            off = 0.05 if (side + k) % 2 else -0.05
            c = Vector((x, y + h * 0.5, z)) + rot @ Vector((off, 0, 0.19))
            objs.append(box(c, (0.36, h - 0.02, 0.1), r.choice(stone_m), rot, 0.03))
        y += h
        k += 1
    objs.append(box((x, top + 0.04, z), (0.56, 0.08, 0.56), mat("stone_dark", STONE_DARK, 0.95), rot_y(0.03), 0.025))
    objs.append(box((x, top + 0.16, z), (0.22, 0.16, 0.22), mat("stone_dark", STONE_DARK, 0.95), None, 0.015))
    objs.append(sphere((x + 0.02, top + 0.1, z - 0.01), (0.3, 0.08, 0.29), mat("snow", SNOW, 0.6), 12, 6))


def door(objs, r, fz):
    wood = mat("wood", WOOD, 0.85)
    alt = mat("wood_alt", WOOD_ALT, 0.85)
    wood_dark = mat("wood_dark", WOOD_DARK, 0.85)
    objs.append(box((0, 0.95, fz + 0.01), (0.9, 1.9, 0.05), wood_dark, None, 0.015))
    for k in range(5):
        x = -0.29 + k * 0.145
        objs.append(box((x, 0.93 + j(r, 0.005), fz + 0.05), (0.135, 1.78, 0.05), alt if k in (1, 4) else wood, None,
                        0.012))
    # Z-brace.
    for y in (0.35, 1.5):
        objs.append(box((0, y, fz + 0.085), (0.66, 0.1, 0.03), wood_dark, None, 0.01))
    objs.append(box((0, 0.93, fz + 0.085), (0.1, 1.3, 0.03), wood_dark, rot_z(-0.68), 0.01))
    objs.append(sphere((0.26, 0.98, fz + 0.12), (0.035, 0.035, 0.035), mat("brass", (0.86, 0.68, 0.3), 0.35, 0.8), 6, 4))
    # Two worn steps.
    stone = mat("stone1", STONES[1], 0.95)
    objs.append(box((0, 0.07, fz + 0.3), (1.15, 0.14, 0.5), stone, rot_y(0.02), 0.04))
    objs.append(box((0.02, 0.2, fz + 0.18), (0.98, 0.12, 0.26), mat("stone2", STONES[2], 0.95), rot_y(-0.03), 0.035))
    objs.append(box((0, 0.26, fz + 0.2), (0.9, 0.03, 0.2), mat("snow", SNOW, 0.6), None, 0.012))


def house_v2(i=0, live=False):
    if not live:
        reset()
    r = random.Random(1234 + i)
    w, d, wall_col, roof_col, shutter_col, wooden = HOUSES[i]
    objs = []
    hw, hd = w * 0.5, d * 0.5
    plaster = mat("plaster%d" % i, wall_col, 0.95)
    wood = mat("wood", WOOD, 0.85)
    wood_dark = mat("wood_dark", WOOD_DARK, 0.85)
    plinth(objs, r, hw, hd)
    upper = 1.95
    objs.append(boxlh((-hw, PLINTH, -hd), (hw, upper, hd), plaster, 0.03))
    peak = WALL + ROOF - 0.18
    log_walls(objs, r, hw, hd, upper, WALL)
    balcony(objs, r, w, hd, upper + 0.02)
    # Gable: dark backing, vertical boards with uneven bottoms.
    objs.append(extrude([(-hw, WALL), (hw, WALL), (0, peak)], -hd + 0.02, hd - 0.02, wood_dark, 0.0))
    k = -hw + 0.07
    while k < hw - 0.05:
        hgt = (peak - WALL) * (1 - abs(k) / hw) - 0.04
        if hgt > 0.08:
            for zz in (hd + 0.01, -hd - 0.01):
                m = mat("wood_alt", WOOD_ALT, 0.85) if r.random() < 0.3 else wood
                objs.append(box((k, WALL - 0.06 + j(r, 0.02) + (hgt + 0.06) * 0.5, zz), (0.13, hgt + 0.06, 0.04), m,
                                None, 0.01))
        k += 0.145
    roof(objs, r, w, d, peak, roof_col, i)
    chimney(objs, r, hw * 0.45, -hd * 0.35, WALL + 0.5, peak + 0.6)
    fz = hd
    door(objs, r, fz)
    win_y0, win_y1 = 1.0, 1.65
    for sx in (-1, 1):
        window(objs, sx * (hw - 0.5), win_y0, win_y1, 0.46, fz + 0.01, 1, None, flowers=True, tag="%d%d" % (i, sx))
    window(objs, 0, WALL + 0.12, WALL + 0.62, 0.42, fz + 0.06, 1, shutter_col, tag=str(i))
    for side in ("x+", "x-"):
        window(objs, 0, win_y0 + 0.05, win_y1 + 0.1, 0.55, hw + 0.01, side, shutter_col, tag=str(i))
    window(objs, 0, win_y0, win_y1, 0.55, hd + 0.01, -1, shutter_col, tag=str(i))
    ob = join(objs, "House%d" % i)
    if not live:
        export("house_%d" % i, [ob])
    return ob


if __name__ == "__main__":
    house_v2(0)
