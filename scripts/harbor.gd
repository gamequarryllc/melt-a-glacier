class_name HarborTown
extends Node3D
## Frozen Harbor's town and waterfront, built in code from MeshKit pieces:
## fishing cabins (rorbuer) under the ice in the cove, a signal mast tall
## enough to poke out of it, the quay's bollards and rope, the pier out over
## the bay, racks of drying fish, lamps, barrels and buoys, the lighthouse on
## the western head with its turning beam, and icebergs out at sea.
## Everything solid is one mesh; lamps and lit windows are a second, unshaded
## one, so they glow in the dusk. The world carves `carve` out of the first
## glacier and collides with `solids`.

const RED := Color(0.68, 0.15, 0.12)
const DARK_RED := Color(0.5, 0.12, 0.11)
const OCHRE := Color(0.86, 0.62, 0.22)
const WHITE := Color(0.93, 0.92, 0.87)
const SEA_BLUE := Color(0.27, 0.42, 0.55)
const SLATE := Color(0.2, 0.22, 0.26)
const STONE := Color(0.5, 0.5, 0.52)
const TIMBER := Color(0.45, 0.33, 0.23)
const TIMBER_DARK := Color(0.27, 0.21, 0.17)
const IRON := Color(0.15, 0.17, 0.2)
const ROPE := Color(0.76, 0.66, 0.46)
const FISH := Color(0.72, 0.69, 0.62)
const LIT := Color(1.0, 0.82, 0.4)
const BUOY := Color(0.9, 0.3, 0.12)

# The cabins: x, z of the footprint's corner, width (x), depth (z), paint,
# trim, and whether it's a boathouse (big doors). Their gables face the sea.
const CABINS := [
	[-44, 4, 4, 4, RED, WHITE, false],
	[-39, 5, 4, 5, OCHRE, WHITE, false],
	[-33, 6, 4, 5, RED, WHITE, false],
	[-27, 6, 4, 5, WHITE, DARK_RED, false],
	[-27, -16, 3, 4, DARK_RED, WHITE, false],
	[-42, -8, 4, 5, SEA_BLUE, WHITE, false],
	[-35, -11, 5, 4, RED, WHITE, true],
	[-29, -9, 4, 4, OCHRE, WHITE, false],
	[-39, -22, 4, 5, RED, WHITE, false],
]
const WALL_H := 2.5
const FLOOR_Y := 0.3
const MAST := Vector3(-30.5, 0.0, -2.5)    # the signal mast in the square
const MAST_TOP := 17.5
const SQUARE := Vector3(-31.5, 0.0, 1.5)   # lobster pots here
const RAIL_BACK := 0.35                    # the bollards stand this far back from the quay's edge
const PIER_HALF := 1.3
# The lighthouse model: where the tower stands from its origin (x, z), its radius and the lamp's height.
const LIGHTHOUSE := [2.0, 6.0, 1.3, 17.0]
# Icebergs out past the breakwater: x, z, how wide, how tall, turn.
const BERGS := [
	[-128.0, 74.0, 22.0, 13.0, 0.4], [-104.0, 138.0, 15.0, 10.0, 1.9], [-36.0, 176.0, 28.0, 17.0, 2.6],
	[38.0, 158.0, 17.0, 9.0, 0.9], [100.0, 142.0, 21.0, 15.0, 4.1], [112.0, 92.0, 12.0, 8.0, 5.2],
	[-162.0, 158.0, 32.0, 20.0, 3.3], [8.0, 236.0, 36.0, 22.0, 1.2], [168.0, 186.0, 30.0, 16.0, 2.2],
	[-70.0, 262.0, 30.0, 19.0, 0.2], [-182.0, 58.0, 18.0, 11.0, 4.6], [78.0, 268.0, 24.0, 14.0, 5.6],
]

var carve: Array = []              # boxes to hollow out of the harbour glacier
var solids: Array[AABB] = []
var villager_spots: Array = []     # where the fisherfolk celebrate

var _st: SurfaceTool               # everything solid
var _glow: SurfaceTool             # lamps and lit windows
var _beam: Node3D                  # the lighthouse's light, turning


func build(level: Dictionary) -> void:
	var v: Dictionary = level.valley
	_st = MeshKit.begin()
	_glow = MeshKit.begin()
	for c: Array in CABINS:
		_cabin(float(c[0]), float(c[1]), float(c[2]), float(c[3]), c[4], c[5], c[6])
	_signal_mast()
	_quay(v)
	_pier(v)
	_racks()
	_clutter()
	var solid := MeshInstance3D.new()
	solid.name = "Town"
	solid.mesh = MeshKit.finish(_st)
	solid.material_override = MeshKit.material()
	add_child(solid)
	var lights := MeshInstance3D.new()
	lights.name = "Lights"
	lights.mesh = MeshKit.finish(_glow)
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.vertex_color_use_as_albedo = true
	lm.vertex_color_is_srgb = true
	lights.material_override = lm
	lights.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lights)
	_st = null
	_glow = null

	# Lobster pots in the square, and a skiff pulled up on the quay.
	var pots := Models.baked_instance(Models.baked("harbor", "Pots"))
	pots.position = SQUARE
	add_child(pots)
	solids.append(AABB(SQUARE - Vector3(0.7, 0.0, 0.7), Vector3(1.4, 1.0, 1.4)))
	var skiff := Models.baked_instance(Models.baked("harbor", "Skiff"))
	skiff.position = Vector3(13.5, 0.0, 18.3)
	skiff.rotation = Vector3(0.0, PI * 0.5, 0.12)
	add_child(skiff)
	solids.append(AABB(Vector3(9.5, 0.0, 16.9), Vector3(8.0, 1.0, 2.8)))
	villager_spots = [Vector3(-34.5, 0.0, -1.0), Vector3(-32.2, 0.0, -3.2), Vector3(-28.4, 0.0, 0.2),
		Vector3(-36.0, 0.0, 3.2), Vector3(-27.6, 0.0, 3.6), Vector3(-33.6, 0.0, 5.2),
		Vector3(-29.6, 0.0, 5.6), Vector3(-37.6, 0.0, -3.4)]
	_lighthouse(v)
	_icebergs()


func _process(delta: float) -> void:
	if _beam != null:
		_beam.rotation.y += delta * 0.5


# =====================================================================================
# Cabins
# =====================================================================================
func _cabin(x: float, z: float, w: float, d: float, paint: Color, trim: Color, boathouse: bool) -> void:
	## A fishing cabin on a stone footing: board walls, a slate roof with its
	## gable to the sea (+Z), a door and lit windows.
	var cx := x + w * 0.5
	var cz := z + d * 0.5
	var ww := w - 0.4
	var dd := d - 0.5
	var top := FLOOR_Y + WALL_H
	var rise := ww * 0.44
	MeshKit.box(_st, Vector3(cx, FLOOR_Y * 0.5, cz), Vector3(ww + 0.16, FLOOR_Y, dd + 0.16), STONE)
	MeshKit.box(_st, Vector3(cx, FLOOR_Y + WALL_H * 0.5, cz), Vector3(ww, WALL_H, dd), paint)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			MeshKit.box(_st, Vector3(cx + sx * ww * 0.5, FLOOR_Y + WALL_H * 0.5, cz + sz * dd * 0.5),
					Vector3(0.14, WALL_H, 0.14), trim)
	# The roof: two slopes meeting in a ridge that runs front to back.
	var angle := atan2(rise, ww * 0.5)
	var half := ww * 0.5 + 0.28
	var slope_len := half / cos(angle)
	for side: float in [-1.0, 1.0]:
		var mid := Vector3(cx + side * half * 0.5, top + rise - half * 0.5 * tan(angle) + 0.07, cz)
		MeshKit.box(_st, mid, Vector3(slope_len, 0.13, dd + 0.5), SLATE, Basis(Vector3.BACK, -side * angle))
	MeshKit.box(_st, Vector3(cx, top + rise + 0.1, cz), Vector3(0.2, 0.12, dd + 0.54), SLATE.darkened(0.2))
	for sz: float in [-1.0, 1.0]:
		var gz := cz + sz * dd * 0.5
		MeshKit.triangle(_st, Vector3(cx - ww * 0.5, top, gz), Vector3(cx + ww * 0.5, top, gz),
				Vector3(cx, top + rise, gz), Vector3(0, 0, sz), paint)
	MeshKit.box(_st, Vector3(cx + ww * 0.24, top + rise * 0.62 + 0.3, cz - dd * 0.22), Vector3(0.36, 0.7, 0.36), STONE.darkened(0.15))
	# The front, facing the sea.
	var front := cz + dd * 0.5
	if boathouse:
		MeshKit.box(_st, Vector3(cx, FLOOR_Y + 1.1, front + 0.02), Vector3(2.7, 2.3, 0.06), trim)
		for side: float in [-1.0, 1.0]:
			MeshKit.box(_st, Vector3(cx + side * 0.63, FLOOR_Y + 1.07, front + 0.04), Vector3(1.2, 2.1, 0.07), TIMBER)
			MeshKit.box(_st, Vector3(cx + side * 0.63, FLOOR_Y + 1.07, front + 0.085), Vector3(1.1, 0.1, 0.02), TIMBER_DARK,
					Basis(Vector3.BACK, side * 1.05))
	else:
		var door_x := cx - ww * 0.22
		MeshKit.box(_st, Vector3(door_x, FLOOR_Y + 1.0, front + 0.02), Vector3(0.94, 2.06, 0.06), trim)
		MeshKit.box(_st, Vector3(door_x, FLOOR_Y + 0.97, front + 0.04), Vector3(0.74, 1.9, 0.07), TIMBER_DARK)
		MeshKit.box(_st, Vector3(door_x, FLOOR_Y * 0.5, front + 0.3), Vector3(1.0, FLOOR_Y, 0.5), STONE.lightened(0.1))
		_window(Vector3(cx + ww * 0.24, FLOOR_Y + 1.45, front), Vector3.BACK, 0.8, trim)
	_window(Vector3(cx, top + rise * 0.42, front), Vector3.BACK, 0.5, trim)
	_window(Vector3(cx + ww * 0.5, FLOOR_Y + 1.45, cz - dd * 0.12), Vector3.RIGHT, 0.8, trim)
	_window(Vector3(cx - ww * 0.5, FLOOR_Y + 1.45, cz + dd * 0.12), Vector3.LEFT, 0.8, trim)
	var box := AABB(Vector3(x, 0.0, z), Vector3(w, top + rise + 0.3, d))
	carve.append(box)
	solids.append(AABB(Vector3(cx - ww * 0.5, 0.0, cz - dd * 0.5), Vector3(ww, top + rise, dd)))


func _window(at: Vector3, out: Vector3, size: float, trim: Color) -> void:
	## A window on a wall facing `out` (an axis): a frame, and a pane with the lamp on inside.
	var flat := Vector3(size, size, size) - out.abs() * (size - 0.06)
	MeshKit.box(_st, at + out * 0.02, flat + (Vector3.ONE - out.abs()) * 0.16, trim)
	MeshKit.box(_glow, at + out * 0.045, flat + out.abs() * 0.02, LIT)
	# Glazing bars.
	var bar := Vector3(0.05, size, 0.05) + out.abs() * 0.04
	MeshKit.box(_st, at + out * 0.06, bar, trim)
	var across := Vector3(size, 0.05, size) - out.abs() * (size - 0.09)
	MeshKit.box(_st, at + out * 0.06, across, trim)


func _signal_mast() -> void:
	## The harbour's signal mast, in the square: taller than the ice is deep,
	## so its top and its pennants show where the town is.
	var top := MAST + Vector3(0, MAST_TOP, 0)
	MeshKit.cylinder(_st, MAST, top, 0.17, 0.08, WHITE, 8)
	MeshKit.box(_st, MAST + Vector3(0, 0.25, 0), Vector3(0.9, 0.5, 0.9), STONE)
	MeshKit.ellipsoid(_st, top + Vector3(0, 0.12, 0), Vector3(0.16, 0.16, 0.16), OCHRE, Basis.IDENTITY, 5, 8)
	var yard := MAST + Vector3(0, MAST_TOP - 1.9, 0)
	MeshKit.cylinder(_st, yard + Vector3(-1.5, 0, 0), yard + Vector3(1.5, 0, 0), 0.05, 0.05, WHITE, 6)
	# Pennants along the yard and a long one at the top.
	var colours := [RED, OCHRE, SEA_BLUE, WHITE, RED]
	for i in colours.size():
		var px := -1.2 + 0.6 * i
		MeshKit.triangle(_st, yard + Vector3(px - 0.22, -0.03, 0), yard + Vector3(px + 0.22, -0.03, 0),
				yard + Vector3(px, -0.62, 0), Vector3.BACK, colours[i])
		MeshKit.triangle(_st, yard + Vector3(px - 0.22, -0.03, 0), yard + Vector3(px + 0.22, -0.03, 0),
				yard + Vector3(px, -0.62, 0), Vector3.FORWARD, colours[i])
	for n: Vector3 in [Vector3.BACK, Vector3.FORWARD]:
		MeshKit.triangle(_st, top + Vector3(0.1, -0.15, 0), top + Vector3(0.1, -0.85, 0), top + Vector3(1.9, -0.5, 0), n, RED)
	solids.append(AABB(MAST - Vector3(0.45, 0.0, 0.45), Vector3(0.9, 0.5, 0.9)))
	solids.append(AABB(MAST - Vector3(0.2, 0.0, 0.2), Vector3(0.4, MAST_TOP, 0.4)))


# =====================================================================================
# The quay and the pier
# =====================================================================================
func _bollard(at: Vector3) -> void:
	MeshKit.cylinder(_st, at, at + Vector3(0, 0.72, 0), 0.17, 0.14, IRON, 8)
	MeshKit.cylinder(_st, at + Vector3(0, 0.72, 0), at + Vector3(0, 0.82, 0), 0.22, 0.2, OCHRE, 8)


func _rope(a: Vector3, b: Vector3, sag: float) -> void:
	## A rope slung between two points.
	var steps := 4
	var last := a
	for i in range(1, steps + 1):
		var t := float(i) / steps
		var p := a.lerp(b, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0)
		MeshKit.cylinder(_st, last, p, 0.035, 0.035, ROPE, 5, false)
		last = p


func _quay(v: Dictionary) -> void:
	## The quay's edge: a timber kerb, and bollards with rope slung between
	## them all the way along, except where the pier leaves it.
	var quay: Array = v.land[0]
	var x0 := float(quay[0]) - float(quay[2]) - 0.5
	var x1 := float(quay[0]) + float(quay[2])
	var edge: float = v.shore_z
	var gate: Vector2 = v.gate
	MeshKit.box(_st, Vector3((x0 + x1) * 0.5, 0.05, edge - 0.05), Vector3(x1 - x0, 0.14, 0.34), TIMBER_DARK)
	var z := edge - RAIL_BACK
	# The gate's sign stands in a gap in the rope, just east of the pier.
	var runs := [[x0 + 0.6, gate.x - PIER_HALF - 0.3], [gate.x + PIER_HALF + 2.9, x1 - 0.4]]
	for run: Array in runs:
		var n := int(ceil((float(run[1]) - float(run[0])) / 3.3))
		var last := Vector3.INF
		for i in n + 1:
			var p := Vector3(lerpf(run[0], run[1], float(i) / n), 0.0, z)
			_bollard(p)
			if last.is_finite():
				_rope(last + Vector3(0, 0.62, 0), p + Vector3(0, 0.62, 0), 0.2)
			last = p
		solids.append(AABB(Vector3(run[0] - 0.2, 0.0, z - 0.2), Vector3(float(run[1]) - float(run[0]) + 0.4, 1.0, 0.4)))
	# Lamp posts along the waterfront.
	for lx: float in [6.5, -9.5, 19.0, -47.0]:
		_lamp(Vector3(lx, 0.0, z - 0.55), Vector3.BACK)


func _lamp(at: Vector3, toward: Vector3) -> void:
	## An iron lamp post with a lantern hung out on an arm.
	var head := at + Vector3(0, 3.3, 0)
	MeshKit.cylinder(_st, at, head, 0.08, 0.055, IRON, 6)
	MeshKit.cylinder(_st, at, at + Vector3(0, 0.5, 0), 0.14, 0.1, IRON, 6)
	var tip := head + toward * 0.7 + Vector3(0, 0.12, 0)
	MeshKit.cylinder(_st, head, tip, 0.035, 0.035, IRON, 5)
	var lantern := tip - Vector3(0, 0.34, 0)
	MeshKit.box(_st, lantern + Vector3(0, 0.2, 0), Vector3(0.3, 0.05, 0.3), IRON)
	MeshKit.box(_st, lantern - Vector3(0, 0.2, 0), Vector3(0.22, 0.04, 0.22), IRON)
	MeshKit.box(_glow, lantern, Vector3(0.2, 0.36, 0.2), LIT)
	solids.append(AABB(at - Vector3(0.12, 0.0, 0.12), Vector3(0.24, 3.3, 0.24)))


func _pier(v: Dictionary) -> void:
	## A plank pier from the quay out over the bay, with posts and rope down
	## both sides. The gate at its foot is the world's (it opens when the
	## harbour is free).
	var gate: Vector2 = v.gate
	var length: float = v.pier
	var z0 := gate.y
	var z1 := gate.y + length
	var planks := int(length / 0.34)
	for i in planks:
		var z := z0 + 0.2 + 0.34 * i
		var shade := TIMBER.lerp(TIMBER_DARK, 0.25 * float((i * 7) % 4) / 3.0)
		MeshKit.box(_st, Vector3(gate.x, 0.04, z), Vector3(PIER_HALF * 2.0 + 0.3, 0.07, 0.3), shade)
	for side: float in [-1.0, 1.0]:
		var x := gate.x + side * PIER_HALF
		MeshKit.box(_st, Vector3(x, 0.09, (z0 + z1) * 0.5), Vector3(0.16, 0.16, length), TIMBER_DARK)
		var last := Vector3.INF
		var posts := 4
		for i in posts:
			var p := Vector3(x, 0.0, lerpf(z0 + 1.9, z1, float(i) / (posts - 1)))
			MeshKit.cylinder(_st, p - Vector3(0, 0.6, 0), p + Vector3(0, 1.05, 0), 0.11, 0.1, TIMBER, 7)
			MeshKit.cylinder(_st, p + Vector3(0, 1.05, 0), p + Vector3(0, 1.12, 0), 0.13, 0.12, WHITE, 7)
			if last.is_finite():
				_rope(last + Vector3(0, 0.9, 0), p + Vector3(0, 0.9, 0), 0.16)
			last = p
		# Gate posts at the quay's edge (the leaf hangs on the left one).
		var gp := Vector3(x, 0.0, z0)
		MeshKit.box(_st, gp + Vector3(0, 0.95, 0), Vector3(0.26, 1.9, 0.26), TIMBER_DARK)
		MeshKit.box(_st, gp + Vector3(0, 1.94, 0), Vector3(0.34, 0.08, 0.34), WHITE)
		_rope(gp + Vector3(0, 0.9, 0), Vector3(x, 0.9, z0 + 1.9), 0.12)
		solids.append(AABB(Vector3(x - 0.15, 0.0, z0), Vector3(0.3, 1.0, length + 0.1)))
	_lamp(Vector3(gate.x - PIER_HALF - 0.05, 0.0, z1 + 0.05), Vector3.RIGHT)


# =====================================================================================
# Fish racks, barrels, buoys
# =====================================================================================
func _rack(at: Vector3, length: float, yaw: float) -> void:
	## A rack of stockfish: two A-frames and three poles, hung with drying cod.
	var b := Basis(Vector3.UP, yaw)
	var apex := 2.5
	var poles := [Vector3(0, apex, 0), Vector3(-0.42, 1.75, 0), Vector3(0.42, 1.75, 0)]
	for end: float in [-0.5, 0.5]:
		var o := at + b * Vector3(0, 0, end * length)
		for side: float in [-1.0, 1.0]:
			MeshKit.cylinder(_st, o + b * Vector3(side * 0.95, 0, 0), o + b * Vector3(-side * 0.08, apex + 0.15, 0), 0.055, 0.045, TIMBER, 6)
	for p: Vector3 in poles:
		MeshKit.cylinder(_st, at + b * (p + Vector3(0, 0, -length * 0.5 - 0.3)), at + b * (p + Vector3(0, 0, length * 0.5 + 0.3)),
				0.04, 0.04, TIMBER_DARK, 5)
		var n := int(length / 0.3)
		for i in n:
			var z := -length * 0.5 + 0.2 + (length - 0.4) * float(i) / maxf(n - 1, 1)
			var drop := 0.32 + 0.07 * float((i * 5) % 3)
			MeshKit.box(_st, at + b * (p + Vector3(0, -drop * 0.5 - 0.03, z)), Vector3(0.11, drop, 0.06),
					FISH.darkened(0.12 * float((i * 3) % 3)), b)
	var half := Vector3(1.0, 0.0, length * 0.5 + 0.3)
	var lo := at + b * -half
	var hi := at + b * half
	solids.append(AABB(Vector3(minf(lo.x, hi.x), 0.0, minf(lo.z, hi.z)), Vector3(absf(hi.x - lo.x), 2.6, absf(hi.z - lo.z))).grow(-0.1).abs())


func _racks() -> void:
	_rack(Vector3(-8.0, 0.0, 4.5), 5.0, PI * 0.5)
	_rack(Vector3(-7.0, 0.0, 9.0), 4.0, PI * 0.5)
	_rack(Vector3(3.5, 0.0, 1.2), 5.5, PI * 0.5)
	_rack(Vector3(-37.0, 0.0, 0.5), 4.0, 0.0)      # under the ice, in the square


func _barrel(at: Vector3, c: Color) -> void:
	MeshKit.cylinder(_st, at, at + Vector3(0, 0.45, 0), 0.3, 0.36, c, 10)
	MeshKit.cylinder(_st, at + Vector3(0, 0.45, 0), at + Vector3(0, 0.9, 0), 0.36, 0.3, c, 10)
	for y: float in [0.16, 0.74]:
		MeshKit.cylinder(_st, at + Vector3(0, y, 0), at + Vector3(0, y + 0.06, 0), 0.345, 0.345, IRON, 10, false)


func _crate(at: Vector3, size: float, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	MeshKit.box(_st, at + Vector3(0, size * 0.5, 0), Vector3(size, size, size), TIMBER.lightened(0.12), b)
	for y: float in [0.12, 0.88]:
		MeshKit.box(_st, at + Vector3(0, size * y, 0), Vector3(size + 0.04, size * 0.12, size + 0.04), TIMBER_DARK, b)


func _buoy(at: Vector3, c: Color) -> void:
	MeshKit.ellipsoid(_st, at + Vector3(0, 0.22, 0), Vector3(0.22, 0.24, 0.22), c, Basis.IDENTITY, 6, 9)
	MeshKit.cylinder(_st, at + Vector3(0, 0.42, 0), at + Vector3(0, 0.54, 0), 0.06, 0.045, WHITE, 6)


func _clutter() -> void:
	## Barrels, fish crates and net buoys along the quay.
	_barrel(Vector3(1.2, 0.0, 19.2), TIMBER)
	_barrel(Vector3(2.0, 0.0, 19.5), TIMBER.darkened(0.15))
	_barrel(Vector3(1.6, 0.0, 18.5), SEA_BLUE)
	solids.append(AABB(Vector3(0.8, 0.0, 18.1), Vector3(1.6, 0.9, 1.8)))
	_crate(Vector3(-12.5, 0.0, 19.3), 0.8, 0.2)
	_crate(Vector3(-13.5, 0.0, 19.4), 0.7, -0.3)
	_crate(Vector3(-12.9, 0.8, 19.35), 0.6, 0.5)
	solids.append(AABB(Vector3(-14.0, 0.0, 18.9), Vector3(2.0, 1.4, 0.9)))
	for i in 5:
		_buoy(Vector3(-11.0 + 0.55 * (i % 3), 0.0, 19.1 + 0.5 * (i / 3)), BUOY if i % 2 == 0 else OCHRE)
	_buoy(Vector3(5.6, 0.0, 19.6), BUOY)
	_buoy(Vector3(-5.4, 0.0, 19.7), WHITE)
	_crate(Vector3(18.5, 0.0, 6.0), 0.9, 0.1)
	_barrel(Vector3(19.6, 0.0, 6.6), TIMBER)
	solids.append(AABB(Vector3(18.0, 0.0, 5.5), Vector3(2.0, 0.9, 1.5)))
	# The slipway the trawler was hauled up: two rails down to the water.
	for side: float in [-1.0, 1.0]:
		MeshKit.box(_st, Vector3(-21.3 + side * 1.1, 0.04, 13.0), Vector3(0.14, 0.1, 16.0), IRON)
	for i in 9:
		MeshKit.box(_st, Vector3(-21.3, 0.02, 5.6 + 1.9 * i), Vector3(2.8, 0.07, 0.24), TIMBER_DARK)


# =====================================================================================
# The lighthouse and the icebergs
# =====================================================================================
func _lighthouse(v: Dictionary) -> void:
	## On the western head, where the whole bay can see it. (The model's
	## origin is the corner of the keeper's cottage; the tower stands at
	## LIGHTHOUSE from it.)
	if not v.has("lighthouse"):
		return
	var at: Vector2 = v.lighthouse
	var y := Scenery.height_at(at.x, at.y) - 0.5
	for dx: float in [-2.5, 2.5]:
		for dz: float in [-4.0, 1.5]:
			y = minf(y, Scenery.height_at(at.x + dx, at.y + dz) - 0.3)
	var lh := Models.baked_instance(Models.baked("harbor", "Lighthouse"))
	lh.position = Vector3(at.x - LIGHTHOUSE[0], y, at.y - LIGHTHOUSE[1])
	add_child(lh)
	# The light: two faint beams sweeping round, and the lamp itself.
	var lamp := Vector3(at.x, y + float(LIGHTHOUSE[3]) + 1.3, at.y)
	_beam = Node3D.new()
	_beam.position = lamp
	add_child(_beam)
	var st := MeshKit.begin()
	for dir: Vector3 in [Vector3.RIGHT, Vector3.LEFT]:
		MeshKit.cylinder(st, dir * 1.0, dir * 150.0, 0.5, 12.0, Color(1.0, 0.93, 0.7), 10, false)
	var cone := MeshInstance3D.new()
	cone.mesh = MeshKit.finish(st)
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	bm.albedo_color = Color(1.0, 0.92, 0.66, 0.045)
	bm.disable_fog = true
	cone.material_override = bm
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.add_child(cone)
	var bulb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.7
	sphere.height = 1.4
	bulb.mesh = sphere
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.albedo_color = Color(1.0, 0.95, 0.75)
	bulb.material_override = gm
	bulb.position = lamp
	add_child(bulb)


func _icebergs() -> void:
	## Bergs adrift out past the breakwater: big faceted lumps of pale blue.
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.9, 0.98)
	mat.roughness = 0.35
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.36, 0.5)
	mat.emission_energy_multiplier = 0.35
	for i in BERGS.size():
		var b: Array = BERGS[i]
		var berg := MeshInstance3D.new()
		berg.mesh = Scenery.boulder_mesh(i % 4)
		berg.material_override = mat
		berg.position = Vector3(b[0], -0.6, b[1])
		berg.scale = Vector3(float(b[2]), float(b[3]) / 0.5, float(b[2]) * 0.8)
		berg.rotation.y = b[4]
		berg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(berg)
